class_name HalliRules
extends RefCounted
## Regras do Halli Galli como máquina de estados pura (docs/PLANO_HALLI_GALLI.md §3).
##
## Não conhece tela nem rede. Todo instante (t, now) está em milissegundos no relógio do host
## (no modo mesa, o relógio do próprio aparelho). O sino é julgado pela mesa no instante do toque,
## não na hora em que a mensagem chegou (§5).
##
## Ator de uma ação: {"id": String, "host": bool}. No modo mesa o ator é sempre o host e a ação
## diz qual jogador agiu ("player").
##
## Carta: int = fruta * 10 + quantidade (fruta 0..3, quantidade 1..5).

const FRUITS := ["banana", "morango", "limao", "ameixa"]
## Quantas cartas de cada quantidade existem por fruta num baralho (56 cartas).
const PER_FRUIT := {1: 5, 2: 3, 3: 3, 4: 2, 5: 1}
const FLIP_COOLDOWN_MS := 500
const BELL_LOCK_MS := 1000
## Numa partida que começou com 2 jogadores, sino errado custa 3 cartas em vez de 1.
const PENALTY_1V1 := 3
const MIN_PLAYERS := 2
const MAX_PLAYERS_WIFI := 20
const MAX_PLAYERS_TABLE := 6
const DECKS_RANGE := Vector2i(1, 6)
const PLAYERS_PER_DECK := 6

const PHASE_LOBBY := "lobby"
const PHASE_PLAYING := "playing"
const PHASE_GAME_OVER := "game_over"

var mode := "wifi" # "wifi" ou "table" (aparelho na mesa)
var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, out, down: Array[int] (0 = carta de cima),
## up: Array[{c, t}] (último = carta de cima), ok, wrong}
var players: Array = []
var config := {"decks": 1, "decks_auto": true}
var turn := "" # id do jogador da vez
var last_flip_t := -100000
var lock_until := 0
## Sinos com horário anterior a isto já foram resolvidos (pertencem a um momento que passou).
var resolved_until := -100000
var paused := false
var winner := ""
var out_order: Array = [] # ids na ordem em que saíram
var start_count := 0 # quantos começaram a partida
## Último sino resolvido, pra tela mostrar: {player, ok, fruit, cards, margin_ms, t}
var last_bell := {}
var seq := 0 # versão do estado; sobe a cada mudança
var rng := RandomNumberGenerator.new()

var _next_local_id := 1
var _next_color := 0


func _init(p_mode := "wifi", seed_value := -1) -> void:
	mode = p_mode
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# --- Consultas -------------------------------------------------------------

func player(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


func max_players() -> int:
	return MAX_PLAYERS_TABLE if mode == "table" else MAX_PLAYERS_WIFI


func alive() -> Array:
	return players.filter(func(p): return not p.out)


func can_start() -> String:
	## Retorna "" se dá pra começar, senão o motivo.
	if players.size() < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if players.size() > max_players():
		return "O máximo é %d jogadores." % max_players()
	return ""


static func card_fruit(c: int) -> int:
	return c / 10


static func card_count(c: int) -> int:
	return c % 10


static func make_card(fruit: int, count: int) -> int:
	return fruit * 10 + count


static func build_deck(decks: int) -> Array:
	var out: Array = []
	for d in decks:
		for f in FRUITS.size():
			for n in PER_FRUIT:
				for i in PER_FRUIT[n]:
					out.append(make_card(f, n))
	return out


## Carta de cima de cada jogador no instante t (-1 = pilha vazia naquele instante).
func table_at(t: int) -> Dictionary:
	var out := {}
	for p in players:
		var top := -1
		for i in range(p.up.size() - 1, -1, -1):
			if int(p.up[i].t) <= t:
				top = int(p.up[i].c)
				break
		out[p.id] = top
	return out


## Soma das frutas visíveis na mesa: Array de 4 inteiros.
static func fruit_sums(table: Dictionary) -> Array:
	var sums := [0, 0, 0, 0]
	for id in table:
		var c: int = table[id]
		if c >= 0:
			sums[card_fruit(c)] += card_count(c)
	return sums


## Índice da fruta que soma exatamente 5, ou -1.
static func five_fruit(table: Dictionary) -> int:
	var sums := fruit_sums(table)
	for f in sums.size():
		if sums[f] == 5:
			return f
	return -1


func top_card(p: Dictionary) -> int:
	return int(p.up.back().c) if not p.up.is_empty() else -1


## Quando o jogador da vez pode virar (horário do host).
func next_flip_at() -> int:
	return maxi(last_flip_t + FLIP_COOLDOWN_MS, lock_until)


func total_cards(p: Dictionary) -> int:
	return p.down.size() + p.up.size()


## Ninguém no jogo tem monte: quem está com a vez desvira a mesa (§3.5).
func needs_recycle() -> bool:
	return phase == PHASE_PLAYING and alive().all(func(q): return q.down.is_empty())


# --- Ações -----------------------------------------------------------------

func apply(actor: Dictionary, action: Dictionary) -> Dictionary:
	var type: String = action.get("type", "")
	var fn := "_a_" + type
	if type == "" or not has_method(fn):
		return _err("Ação desconhecida.")
	var res: Dictionary = call(fn, actor, action)
	if res.ok:
		seq += 1
	return res


func _a_add_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host adiciona jogadores.")
	if players.size() >= max_players():
		return _err("A sala está cheia (máximo %d)." % max_players())
	var n := TextNorm.clean(str(a.get("name", "")))
	if n == "":
		return _err("Digite um nome.")
	n = n.left(20)
	var id: String = a.get("id", "")
	if id == "":
		id = "p%d" % _next_local_id
		_next_local_id += 1
	if not player(id).is_empty():
		return _err("Jogador já está na sala.")
	players.append({"id": id, "name": n, "color": _next_color, "connected": true, "out": false, "down": [], "up": [], "ok": 0, "wrong": 0})
	_next_color += 1
	_auto_decks()
	return _ok([{"type": "player_joined", "id": id, "name": n}])


func _a_remove_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if not actor.get("host", false):
		return _err("Só o host remove jogadores.")
	var id: String = a.get("id", "")
	var p := player(id)
	if p.is_empty():
		return _err("Jogador não encontrado.")
	if phase != PHASE_PLAYING:
		players.erase(p)
		_auto_decks()
		return _ok([{"type": "player_left", "id": id, "name": p.name}])
	# No meio da partida: as cartas dele vão pros outros, uma por vez, na ordem da mesa.
	var was_turn := turn == id
	var idx := players.find(p)
	var cards: Array = p.down.duplicate()
	for e in p.up:
		cards.append(int(e.c))
	players.erase(p)
	out_order.erase(id)
	var receivers := _alive_from(idx)
	var events: Array = [{"type": "player_left", "id": id, "name": p.name}]
	if not receivers.is_empty():
		for i in cards.size():
			receivers[i % receivers.size()].down.append(cards[i])
	if players.all(func(q): return q.connected):
		paused = false
	if was_turn:
		turn = ""
		events.append_array(_advance_turn(idx - 1))
	events.append_array(_check_game_over())
	return _ok(events)


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
	if i == j:
		return _ok()
	players.remove_at(i)
	players.insert(j, p)
	return _ok([{"type": "order"}])


func _a_set_config(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host configura a partida.")
	if a.has("decks"):
		config.decks = clampi(int(a.decks), DECKS_RANGE.x, DECKS_RANGE.y)
		config.decks_auto = false
	return _ok()


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	return _deal(int(actor.get("now", 0)))


func _a_rematch(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host começa outra partida.")
	# Quem saiu da rede no meio fica de fora.
	players = players.filter(func(p): return p.connected)
	var why := can_start()
	if why != "":
		phase = PHASE_LOBBY
		return _ok([{"type": "phase", "phase": phase}])
	return _deal(int(actor.get("now", 0)))


## O jogador da vez vira a carta de cima do monte. a = {t, player (só no modo mesa)}.
func _a_flip(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PLAYING:
		return _err("A partida não está rolando.")
	if paused:
		return _err("A partida está pausada.")
	var id: String = a.get("player", "") if actor.get("host", false) and a.has("player") else actor.get("id", "")
	if id != turn:
		return _err("Não é a sua vez.")
	var p := player(id)
	var t := int(a.get("t", 0))
	if t < next_flip_at():
		return _err("Espere a mesa.")
	var events: Array = []
	if p.down.is_empty():
		if not needs_recycle():
			return _err("Sem cartas pra virar.")
		events.append_array(_recycle(t))
		if p.down.is_empty():
			events.append_array(_advance_turn(players.find(p)))
			return _ok(events)
	var c: int = p.down.pop_front()
	p.up.append({"c": c, "t": t})
	last_flip_t = t
	events.append({"type": "flip", "player": id, "card": c})
	events.append_array(_advance_turn(players.find(p)))
	events.append_array(_check_game_over())
	return _ok(events)


## Resolve os sinos de um momento. bells = [{player, t}], now = agora no relógio do host.
## Vale só o primeiro sino (menor horário): certo, leva a mesa; errado, a mesa volta pros donos e
## quem bateu paga 1 carta pra cada um, ou 3 numa partida de 2 (§3.4). Os sinos seguintes do mesmo momento não contam.
## Na trava logo depois de um sino (BELL_LOCK_MS), um sino errado não conta nem pune: é a mão que
## chegou atrasada no sino que outro já bateu. Retorna {ok, events}.
func ring(bells: Array, now: int) -> Dictionary:
	if phase != PHASE_PLAYING or paused:
		return _ok()
	var list: Array = []
	var seen := {}
	for b in bells:
		var p := player(str(b.get("player", "")))
		var t := int(b.get("t", 0))
		if p.is_empty() or p.out or seen.has(p.id) or t < resolved_until:
			continue
		seen[p.id] = true
		list.append({"player": p.id, "t": t})
	if list.is_empty():
		return _ok()
	list.sort_custom(func(x, y): return x.t < y.t)
	var events: Array = []
	for i in list.size():
		var b: Dictionary = list[i]
		var fruit := five_fruit(table_at(b.t))
		if fruit < 0 and b.t < lock_until:
			continue
		if fruit >= 0:
			var margin := -1
			if i + 1 < list.size():
				margin = int(list[i + 1].t) - int(b.t)
			events.append_array(_collect(b.player, b.t, fruit, margin))
		else:
			events.append_array(_return_table())
			events.append_array(_penalty(b.player, b.t))
		break
	if events.is_empty():
		return _ok()
	resolved_until = now
	lock_until = maxi(lock_until, now + BELL_LOCK_MS)
	events.append_array(_eliminate_empty())
	events.append_array(_check_game_over())
	seq += 1
	return _ok(events)


## Marca a conexão de um jogador. Na partida, qualquer um fora da rede pausa tudo (§9).
func set_connected(id: String, connected: bool, now := 0) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	seq += 1
	var events: Array = [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]
	if phase != PHASE_PLAYING:
		return events
	var all_in: bool = players.all(func(q): return q.connected)
	if not connected and not paused:
		paused = true
		events.append({"type": "paused"})
	elif connected and paused and all_in:
		paused = false
		# Ninguém vira nem bate de susto logo na volta.
		lock_until = maxi(lock_until, now + BELL_LOCK_MS)
		resolved_until = maxi(resolved_until, now)
		events.append({"type": "resumed"})
	return events


# --- Visão (o que cada aparelho pode ver) ---------------------------------

## viewer: {"id": String, "role": "table" | "player"}.
## No Wi-Fi, cada um só recebe a própria carta e a próxima do próprio monte (§4.1, §5.2).
func view_for(viewer: Dictionary) -> Dictionary:
	var you: String = viewer.get("id", "")
	var full: bool = viewer.get("role", "") == "table"
	var list: Array = []
	for p in players:
		var e := {
			"id": p.id, "name": p.name, "color": p.color, "connected": p.connected, "out": p.out,
			"down": p.down.size(), "up": p.up.size(), "ok": p.ok, "wrong": p.wrong,
		}
		if full:
			e.top = top_card(p)
		list.append(e)
	var v := {
		"phase": phase,
		"mode": mode,
		"you": you,
		"players": list,
		"config": config.duplicate(),
		"can_start": can_start(),
		"turn": turn,
		"next_flip_at": next_flip_at(),
		"lock_until": lock_until,
		"paused": paused,
		"winner": winner,
		"out_order": out_order.duplicate(),
		"last_bell": last_bell.duplicate(),
		"seq": seq,
		"recycle": needs_recycle(),
		"penalty": PENALTY_1V1 if start_count == 2 else 1,
		"top": -1,
		"next": -1,
	}
	var me := player(you)
	if not me.is_empty():
		v.top = top_card(me)
		v.next = int(me.down[0]) if not me.down.is_empty() else -1
	return v


# --- Internos --------------------------------------------------------------

func _deal(now: int) -> Dictionary:
	var deck := build_deck(int(config.decks))
	_shuffle(deck)
	for p in players:
		p.down = []
		p.up = []
		p.out = false
		p.ok = 0
		p.wrong = 0
	for i in deck.size():
		players[i % players.size()].down.append(deck[i])
	phase = PHASE_PLAYING
	start_count = players.size()
	winner = ""
	out_order = []
	last_bell = {}
	paused = not players.all(func(q): return q.connected)
	turn = players[rng.randi_range(0, players.size() - 1)].id
	last_flip_t = -100000
	lock_until = now + BELL_LOCK_MS
	resolved_until = now
	return _ok([{"type": "phase", "phase": phase}, {"type": "turn", "player": turn}])


func _collect(id: String, t: int, fruit: int, margin: int) -> Array:
	var p := player(id)
	var events: Array = []
	# Viradas feitas depois do sino vencedor são desfeitas: a carta volta pro monte do dono.
	for q in players:
		while not q.up.is_empty() and int(q.up.back().t) > t:
			var e: Dictionary = q.up.pop_back()
			q.down.push_front(int(e.c))
			events.append({"type": "undo_flip", "player": q.id})
	var won: Array = []
	for q in players:
		for e in q.up:
			won.append(int(e.c))
		q.up = []
	_shuffle(won)
	p.down.append_array(won)
	p.ok += 1
	turn = id
	last_bell = {"player": id, "ok": true, "fruit": fruit, "cards": won.size(), "margin_ms": margin, "t": t}
	events.append({"type": "bell", "player": id, "ok": true, "fruit": fruit, "cards": won.size(), "margin_ms": margin})
	return events


## Sino errado: cada carta aberta volta pro fundo do monte do dono. Quem já tinha saído e tinha
## carta na mesa volta pro jogo com elas.
func _return_table() -> Array:
	var events: Array = []
	for q in players:
		if q.up.is_empty():
			continue
		for e in q.up:
			q.down.append(int(e.c))
		q.up = []
		if q.out:
			q.out = false
			out_order.erase(q.id)
			events.append({"type": "back_in", "player": q.id, "name": q.name})
	return events


func _penalty(id: String, t: int) -> Array:
	var p := player(id)
	var idx := players.find(p)
	var each := PENALTY_1V1 if start_count == 2 else 1
	var paid: Array = []
	var got := {}
	var total := 0
	for q in _alive_from(idx):
		if q.id == id:
			continue
		for i in each:
			if p.down.is_empty():
				break
			q.down.append(p.down.pop_front())
			got[q.id] = int(got.get(q.id, 0)) + 1
			total += 1
		if got.has(q.id):
			paid.append(q.id)
	p.wrong += 1
	last_bell = {"player": id, "ok": false, "fruit": -1, "cards": total, "margin_ms": -1, "t": t}
	return [{"type": "bell", "player": id, "ok": false, "cards": total, "to": paid, "got": got}]


## Jogadores vivos a partir do próximo depois de idx, dando a volta (inclui o próprio no fim).
func _alive_from(idx: int) -> Array:
	var out: Array = []
	for k in players.size():
		var q: Dictionary = players[(idx + 1 + k) % players.size()]
		if not q.out:
			out.append(q)
	return out


## Passa a vez pro próximo depois de idx que tem monte. Quem está sem monte é pulado, mas
## continua no jogo enquanto tiver carta na mesa (§3.5). Se ninguém tiver monte, a vez fica com o
## próximo da ordem, que desvira a mesa.
func _advance_turn(idx: int) -> Array:
	var events: Array = []
	var fallback := {}
	for k in players.size():
		var q: Dictionary = players[(idx + 1 + k) % players.size()]
		if q.out:
			continue
		if q.down.is_empty():
			if fallback.is_empty():
				fallback = q
			continue
		turn = q.id
		events.append({"type": "turn", "player": turn})
		return events
	turn = fallback.get("id", "")
	if turn != "":
		events.append({"type": "turn", "player": turn})
	return events


## Cada um pega a própria pilha aberta, embaralha e vira de novo como monte. Sinos de antes disso
## não contam mais: a mesa em que foram batidos não existe.
func _recycle(t: int) -> Array:
	for q in players:
		if q.up.is_empty():
			continue
		var cards: Array = q.up.map(func(e): return int(e.c))
		_shuffle(cards)
		q.down.append_array(cards)
		q.up = []
	resolved_until = maxi(resolved_until, t)
	return [{"type": "recycle"}]


## Depois de um sino: quem não tem mais carta nenhuma (nem na mesa) sai; e se o jogador da vez
## saiu ou ficou sem monte, a vez passa.
func _eliminate_empty() -> Array:
	var events: Array = []
	for q in players:
		if not q.out and total_cards(q) == 0 and alive().size() > 1:
			_set_out(q, events)
	var tp := player(turn)
	if tp.is_empty() or tp.out or tp.down.is_empty():
		var idx := players.find(tp) if not tp.is_empty() else -1
		events.append_array(_advance_turn(idx))
	return events


func _set_out(q: Dictionary, events: Array) -> void:
	q.out = true
	out_order.append(q.id)
	events.append({"type": "out", "player": q.id, "name": q.name})


func _check_game_over() -> Array:
	if phase != PHASE_PLAYING:
		return []
	var left := alive()
	if left.size() > 1:
		return []
	phase = PHASE_GAME_OVER
	winner = left[0].id if not left.is_empty() else ""
	turn = ""
	return [{"type": "game_over", "winner": winner}]


func _auto_decks() -> void:
	if config.decks_auto:
		config.decks = clampi(ceili(players.size() / float(PLAYERS_PER_DECK)), DECKS_RANGE.x, DECKS_RANGE.y)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
