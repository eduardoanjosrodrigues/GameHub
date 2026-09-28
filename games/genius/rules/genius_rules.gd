class_name GeniusRules
extends RefCounted
## Regras do Genius como máquina de estados pura (docs/PLANO_GENIUS.md). Serve os dois modos com
## mais de uma pessoa, no mesmo contrato dos jogos de tema (PartyHost/PartyLocal):
##   Passa o aparelho (local_mode): um jogador por vez repete a sequência; acertou, ela ganha uma
##     cor pro próximo; errou, sai e o próximo recebe a mesma sequência (§4).
##   Corrida (rede): todos repetem a mesma sequência na mesma rodada; quem erra sai; se todos os que
##     restam erram, a rodada se repete (§5).
## O solo usa só as funções estáticas (sequência e velocidade).
## Ator de uma ação: {"id", "host", "board", "now"}.

const COLORS := 4 # 0 verde, 1 vermelho, 2 amarelo, 3 azul
const COLOR_NAMES := ["verde", "vermelho", "amarelo", "azul"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 12
## Velocidade do original (§2.1): quanto cada cor fica acesa, pelo tamanho da sequência.
const GAP_MS := 50
## Contagem antes de a sequência tocar na Corrida (3-2-1 na primeira, 2-1 nas outras).
const FIRST_COUNTDOWN_MS := 3000
const COUNTDOWN_MS := 2000
## Fim de rodada na Corrida: a lista de quem passou fica na tela esse tempo.
const ROUND_END_MS := 2600
## Quem caiu da rede e ainda não terminou a rodada: os outros esperam por esse tempo (§5, 12).
const DROP_GRACE_MS := 15000

const PHASE_LOBBY := "lobby"
const PHASE_TURN := "turn" # Passa o aparelho: a vez de alguém
const PHASE_ROUND := "round" # Corrida: todos repetindo
const PHASE_ROUND_END := "round_end"
const PHASE_GAME_OVER := "game_over"

var local_mode := false
var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, out_round (-1 = ainda está), best}.
var players: Array = []
var seq: Array = []
var round_no := 0
var round_at := 0 # Corrida: hora do host em que a sequência começa a tocar
var turn := "" # Passa o aparelho: de quem é a vez
var progress := {} # id -> quantas cores já acertou nesta rodada/vez
var done := {} # Corrida: id -> "ok" | "fail" | "forfeit"
var last := {} # fim de rodada: {round, len, passed, failed, forfeit, repeat}
var winners: Array = []
var out_order: Array = [] # Passa o aparelho: ids na ordem em que saíram
var round_end_until := 0
var off_since := {} # Corrida: id -> hora em que o pendente caiu
var rng := RandomNumberGenerator.new()

var _next_color := 0
var _next_local_id := 1


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# --- Sequência e velocidade (servem o solo também) -------------------------

## Quanto cada cor fica acesa ao tocar uma sequência de `length` cores (Simon original).
static func light_ms(length: int) -> int:
	if length <= 5:
		return 420
	if length <= 13:
		return 320
	return 220


## Duração de tocar a sequência inteira.
static func playback_ms(length: int) -> int:
	return length * (light_ms(length) + GAP_MS)


static func random_color(r: RandomNumberGenerator) -> int:
	return r.randi_range(0, COLORS - 1)


# --- Consultas -------------------------------------------------------------

func player(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


## Quem ainda está no jogo.
func alive() -> Array:
	return players.filter(func(p): return int(p.out_round) < 0).map(func(p): return p.id)


## Corrida: quem ainda está e não terminou esta rodada.
func pending() -> Array:
	return alive().filter(func(id): return not done.has(id))


func can_start() -> String:
	var n := players.size()
	if n < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	return ""


## Hora (do host) em que a vez de repetir começa na Corrida.
func input_at() -> int:
	return round_at + playback_ms(seq.size())


# --- Ações -----------------------------------------------------------------

func apply(actor: Dictionary, action: Dictionary) -> Dictionary:
	var type: String = action.get("type", "")
	var fn := "_a_" + type
	if type == "" or not has_method(fn):
		return _err("Ação desconhecida.")
	return call(fn, actor, action)


func _a_add_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host adiciona jogadores.")
	if players.size() >= MAX_PLAYERS:
		return _err("A sala está cheia (máximo %d)." % MAX_PLAYERS)
	var n := TextNorm.clean(str(a.get("name", ""))).left(20)
	if n == "":
		return _err("Digite um nome.")
	var id: String = a.get("id", "")
	if id == "":
		id = "p%d" % _next_local_id
		_next_local_id += 1
	if not player(id).is_empty():
		return _err("Jogador já está na sala.")
	for p in players:
		if local_mode and p.name.to_lower() == n.to_lower():
			return _err("Já tem alguém com esse nome.")
	players.append({"id": id, "name": n, "color": _next_color, "connected": true, "out_round": -1, "best": 0})
	_next_color += 1
	return _ok([{"type": "player_joined", "id": id, "name": n}])


func _a_remove_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("Só dá pra tirar alguém antes de começar.")
	if not actor.get("host", false):
		return _err("Só o host remove jogadores.")
	var p := player(a.get("id", ""))
	if p.is_empty():
		return _err("Jogador não encontrado.")
	players.erase(p)
	return _ok([{"type": "player_left", "id": p.id, "name": p.name}])


func _a_move_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host muda a ordem.")
	var p := player(a.get("id", ""))
	if p.is_empty():
		return _err("Jogador não encontrado.")
	var i := players.find(p)
	var j := clampi(i + int(a.get("dir", 0)), 0, players.size() - 1)
	players.remove_at(i)
	players.insert(j, p)
	return _ok([{"type": "order"}])


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase not in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	for p in players:
		p.out_round = -1
		p.best = 0
	seq = [random_color(rng)]
	round_no = 1
	winners = []
	out_order = []
	last = {}
	progress = {}
	done = {}
	off_since = {}
	var events: Array = [{"type": "started"}]
	if local_mode:
		# A ordem é a da mesa; quem começa é sorteado (§4).
		turn = players[rng.randi_range(0, players.size() - 1)].id
		phase = PHASE_TURN
		events.append({"type": "turn", "id": turn, "len": seq.size()})
	else:
		_begin_round(int(actor.get("now", 0)) + FIRST_COUNTDOWN_MS)
		events.append({"type": "round", "round": round_no, "len": seq.size(), "at": round_at})
	events.push_front({"type": "phase", "phase": phase})
	return _ok(events)


func _a_rematch(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	return _a_start(actor, a)


func _a_to_lobby(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host volta pra sala.")
	phase = PHASE_LOBBY
	return _ok([{"type": "phase", "phase": phase}])


## Um toque numa cor. `i` é a posição que o aparelho acha que está repetindo: um toque repetido
## (reenvio depois de reconectar) é ignorado sem erro.
func _a_press(actor: Dictionary, a: Dictionary) -> Dictionary:
	var id: String = turn if local_mode else str(actor.get("id", ""))
	var color := int(a.get("color", -1))
	if color < 0 or color >= COLORS:
		return _err("Cor inválida.")
	if local_mode:
		if phase != PHASE_TURN:
			return _err("Não é hora de tocar.")
	else:
		if phase != PHASE_ROUND:
			return _err("Não é hora de tocar.")
		if id not in alive():
			return _err("Você já saiu desta partida.")
		if done.has(id):
			return _ok()
	var at := int(progress.get(id, 0))
	if a.has("i") and int(a.i) != at:
		return _ok()
	if int(seq[at]) != color:
		return _ok(_failed(id, int(actor.get("now", 0))))
	at += 1
	progress[id] = at
	if at < seq.size():
		return _ok([{"type": "press", "id": id}])
	return _ok(_completed(id, int(actor.get("now", 0))))


## Corrida: o host desiste de esperar alguém que travou a rodada (§5, 12). Conta como se tivesse
## saído da partida.
func _a_drop_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if local_mode or phase != PHASE_ROUND:
		return _err("Não dá pra fazer isso agora.")
	if not actor.get("host", false):
		return _err("Só o host pode.")
	var id := str(a.get("id", ""))
	if id not in pending():
		return _err("Essa pessoa já terminou a rodada.")
	done[id] = "forfeit"
	return _ok(_check_round(int(actor.get("now", 0)), [{"type": "forfeit", "id": id, "name": player(id).name}]))


## O host chama sempre: passa do fim de rodada pra próxima e desiste de quem caiu há muito tempo.
func tick(now: int) -> Dictionary:
	if local_mode:
		return _ok()
	if phase == PHASE_ROUND_END and now >= round_end_until:
		var events: Array = []
		if not last.get("repeat", false):
			seq.append(random_color(rng))
			round_no += 1
		_begin_round(now + COUNTDOWN_MS)
		events.append({"type": "phase", "phase": phase})
		events.append({"type": "round", "round": round_no, "len": seq.size(), "at": round_at, "repeat": last.get("repeat", false)})
		return _ok(events)
	if phase == PHASE_ROUND:
		var waiting := pending()
		var connected_pending := waiting.filter(func(id): return player(id).connected)
		if not waiting.is_empty() and connected_pending.is_empty():
			var events: Array = []
			for id in waiting:
				if not off_since.has(id):
					off_since[id] = now
				elif now - int(off_since[id]) >= DROP_GRACE_MS:
					done[id] = "forfeit"
					events.append({"type": "forfeit", "id": id, "name": player(id).name})
			if not events.is_empty():
				return _ok(_check_round(now, events))
	return _ok()


## Sem ações com hora: a Corrida não é decidida por quem toca primeiro.
func resolve_timed(_list: Array, _now: int) -> Dictionary:
	return _ok()


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	if connected:
		off_since.erase(id)
	return [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]


# --- Visão -----------------------------------------------------------------

## viewer: {"id", "role": "player" | "board" | "local"}. now: ms do host.
func view_for(viewer: Dictionary, now := 0) -> Dictionary:
	var you: String = viewer.get("id", "")
	var out_players: Array = []
	for p in players:
		out_players.append(p.duplicate())
	var mine := ""
	if done.has(you):
		mine = str(done[you])
	return {
		"phase": phase,
		"you": you,
		"local": local_mode,
		"players": out_players,
		"can_start": can_start(),
		"seq": seq.duplicate(),
		"round_no": round_no,
		"round_at": round_at,
		"input_at": input_at(),
		"now": now,
		"turn": turn,
		"progress": int(progress.get(turn if local_mode else you, 0)),
		"alive": alive(),
		"mine": mine, # Corrida: "", "ok", "fail" ou "forfeit"
		"pending": pending().size() if phase == PHASE_ROUND else 0,
		"last": last.duplicate(true),
		"winners": winners.duplicate(),
		"ranking": ranking(),
	}


## Classificação: quem venceu primeiro; depois quem saiu mais tarde. Quem saiu na mesma rodada
## empata (mesma posição). [{id, pos, len}]
func ranking() -> Array:
	var out: Array = []
	if local_mode:
		var order: Array = alive()
		var gone := out_order.duplicate()
		gone.reverse()
		order.append_array(gone)
		for i in order.size():
			out.append({"id": order[i], "pos": i + 1, "best": int(player(order[i]).best)})
		return out
	var list: Array = players.duplicate()
	list.sort_custom(func(x, y): return _rank_key(x) > _rank_key(y))
	var pos := 0
	var prev := -999
	for i in list.size():
		var k := _rank_key(list[i])
		if k != prev:
			pos = i + 1
			prev = k
		out.append({"id": list[i].id, "pos": pos, "best": int(list[i].best)})
	return out


func _rank_key(p: Dictionary) -> int:
	return 1000000 if int(p.out_round) < 0 else int(p.out_round)


# --- Internos --------------------------------------------------------------

func _begin_round(at: int) -> void:
	round_at = at
	progress = {}
	done = {}
	off_since = {}
	phase = PHASE_ROUND


func _completed(id: String, now: int) -> Array:
	var p := player(id)
	p.best = maxi(int(p.best), seq.size())
	if local_mode:
		var events: Array = [{"type": "turn_ok", "id": id, "len": seq.size()}]
		seq.append(random_color(rng))
		return _next_turn(events)
	done[id] = "ok"
	return _check_round(now, [{"type": "you_ok", "id": id}])


func _failed(id: String, now: int) -> Array:
	var right := int(seq[int(progress.get(id, 0))])
	if local_mode:
		var p := player(id)
		p.out_round = round_no
		out_order.append(id)
		var events: Array = [{"type": "turn_fail", "id": id, "len": seq.size(), "right": right}]
		if alive().size() <= 1:
			return _game_over(events)
		# O próximo recebe a mesma sequência (§4).
		return _next_turn(events)
	done[id] = "fail"
	return _check_round(now, [{"type": "you_fail", "id": id, "right": right}])


## Passa o aparelho: a vez vai pro próximo que ainda está, na ordem da mesa.
func _next_turn(events: Array) -> Array:
	round_no += 1
	progress = {}
	var ids: Array = players.map(func(p): return p.id)
	var i := ids.find(turn)
	for k in range(1, ids.size() + 1):
		var nid: String = ids[(i + k) % ids.size()]
		if int(player(nid).out_round) < 0:
			turn = nid
			break
	events.append({"type": "turn", "id": turn, "len": seq.size()})
	return events


## Corrida: se todo mundo que ainda está já terminou, fecha a rodada.
func _check_round(now: int, events: Array) -> Array:
	var in_game := alive()
	var contenders: Array = in_game.filter(func(id): return done.get(id, "") != "forfeit")
	var forfeit: Array = in_game.filter(func(id): return done.get(id, "") == "forfeit")
	# Sobrou uma pessoa só (os outros desistiram ou caíram): ela vence sem jogar mais (§5, 11).
	if contenders.size() <= 1:
		for id in forfeit:
			player(id).out_round = round_no
		last = {"round": round_no, "len": seq.size(), "passed": contenders.filter(func(id): return done.get(id, "") == "ok"), "failed": contenders.filter(func(id): return done.get(id, "") == "fail"), "forfeit": forfeit, "repeat": false}
		return _game_over(events)
	if contenders.any(func(id): return not done.has(id)):
		return events
	var passed: Array = contenders.filter(func(id): return done[id] == "ok")
	var failed: Array = contenders.filter(func(id): return done[id] == "fail")
	var repeat := passed.is_empty()
	for id in forfeit:
		player(id).out_round = round_no
	if not repeat:
		for id in failed:
			player(id).out_round = round_no
	last = {"round": round_no, "len": seq.size(), "passed": passed, "failed": failed, "forfeit": forfeit, "repeat": repeat}
	events.append({"type": "round_result", "passed": passed, "failed": failed, "repeat": repeat})
	if not repeat and passed.size() == 1:
		return _game_over(events)
	phase = PHASE_ROUND_END
	round_end_until = now + ROUND_END_MS
	events.append({"type": "phase", "phase": phase})
	return events


func _game_over(events: Array) -> Array:
	winners = alive()
	phase = PHASE_GAME_OVER
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "game_over", "winners": winners.duplicate(), "len": seq.size()})
	return events


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
