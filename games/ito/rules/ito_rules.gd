class_name ItoRules
extends RefCounted
## Regras do Ito como máquina de estados pura (docs/PLANO_SINTONIA_ITO.md §4).
##
## Cada um recebe números secretos de 1 a 100; o grupo escolhe um tema, cada um dá um exemplo
## do tema que represente o seu número, e todos montam juntos uma fila em ordem crescente.
## Na revelação, da esquerda pra direita, cada número menor que algum anterior é um erro.
## Ator de uma ação: {"id", "host", "board", "local", "now"}. No modo de um celular só
## ("local"), o aparelho age por qualquer um.

const MIN_PLAYERS := 2
const MAX_PLAYERS := 10
const LIVES := 3
const MAX_NUMBER := 100
const TIMER_RANGE := Vector2i(0, 5) # minutos; 0 = desligado
const CARDS_RANGE := Vector2i(1, 3) # cartas por pessoa na Rodada solta
const WORD_MAX := 24
const THEME_MAX := 80

const MODE_DESAFIO := "desafio"
const MODE_SOLTA := "solta"

const PHASE_LOBBY := "lobby"
const PHASE_THEME := "theme" # números já na mão; o grupo escolhe o tema
const PHASE_PLAY := "play" # dicas e fila
const PHASE_REVEAL := "reveal" # números à mostra, erros contados
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected}, na ordem da mesa.
var players: Array = []
var config := {"mode": MODE_DESAFIO, "cards": 1, "timer_min": 0}
## Um celular só: sem modo extremo; o Desafio termina com todos com 2 cartas (§5).
var local_mode := false
var themes: ThemeBank
var theme_options: Array = []
var theme := ""
var extra := {} # Desafio: id -> cartas a mais que a pessoa recebe
var extra_turn := 0 # índice na mesa de quem ganha a próxima carta
var lives := LIVES
var best := 0 # maior nível vencido nesta sequência
var round_no := 0
var cards := {} # id da carta -> {id, owner, n, word}
var row: Array = [] # ids das cartas na fila, da menor pra maior
var result := {} # na revelação: {errors: [ids], lost, ok, next: "round" | "game_over", won}
var rounds: Array = [] # {level, theme, cards: [{owner, n, word}], errors}
var round_since := 0
var end_reason := "" # "lives" | "won" | "finished"
var rng := RandomNumberGenerator.new()

var _next_local_id := 1
var _next_color := 0


func _init(theme_list: Array = [], seed_value := -1) -> void:
	themes = ThemeBank.new(theme_list)
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


func cards_of(id: String) -> int:
	if config.mode == MODE_SOLTA:
		return int(config.cards)
	return 1 + int(extra.get(id, 0))


func total_cards() -> int:
	var t := 0
	for p in players:
		t += cards_of(p.id)
	return t


## Nível do Desafio: 1 com uma carta cada, +1 a cada carta a mais.
func level() -> int:
	return total_cards() - players.size() + 1 if config.mode == MODE_DESAFIO else 1


## Modo extremo (oficial): depois de todos terem 2 cartas, a fila não mostra de quem é cada uma.
func extreme() -> bool:
	if config.mode != MODE_DESAFIO or local_mode:
		return false
	for p in players:
		if cards_of(p.id) >= 3:
			return true
	return false


func all_placed() -> bool:
	return not cards.is_empty() and row.size() == cards.size()


func can_start() -> String:
	var n := players.size()
	if n < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	return ""


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
	players.append({"id": id, "name": n, "color": _next_color, "connected": true})
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


func _a_set_config(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host muda a partida.")
	if a.has("mode"):
		if a.mode not in [MODE_DESAFIO, MODE_SOLTA]:
			return _err("Modo desconhecido.")
		config.mode = a.mode
	if a.has("cards"):
		config.cards = clampi(int(a.cards), CARDS_RANGE.x, CARDS_RANGE.y)
	if a.has("timer_min"):
		config.timer_min = clampi(int(a.timer_min), TIMER_RANGE.x, TIMER_RANGE.y)
	return _ok([{"type": "config"}])


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	_reset_run()
	return _ok(_deal([{"type": "started"}]))


func _a_rematch(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host começa outra.")
	if can_start() != "":
		return _err(can_start())
	_reset_run()
	return _ok(_deal([{"type": "started"}]))


## Voltar pra sala depois do fim (trocar o modo, entrar mais gente).
func _a_to_lobby(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host volta pra sala.")
	phase = PHASE_LOBBY
	cards = {}
	row = []
	return _ok([{"type": "phase", "phase": phase}])


## Qualquer um escolhe um dos dois temas sorteados.
func _a_pick_theme(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_THEME:
		return _err("Não é hora de escolher o tema.")
	if not _is_member(actor):
		return _err("Só quem está jogando escolhe o tema.")
	var i := int(a.get("index", -1))
	if i < 0 or i >= theme_options.size():
		return _err("Tema inválido.")
	return _set_theme(str(theme_options[i]), actor)


## Ou digita um tema na hora.
func _a_custom_theme(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_THEME:
		return _err("Não é hora de escolher o tema.")
	if not _is_member(actor):
		return _err("Só quem está jogando escolhe o tema.")
	var t := TextNorm.clean(str(a.get("text", ""))).left(THEME_MAX)
	if t.length() < 3:
		return _err("Escreva o tema.")
	return _set_theme(t, actor)


## Põe uma carta sua na fila, na posição `to` (0 = logo depois do zero).
func _a_place(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PLAY:
		return _err("Ainda não é hora de montar a fila.")
	var c: Dictionary = cards.get(str(a.get("card", "")), {})
	if c.is_empty():
		return _err("Carta não encontrada.")
	if not _owns(actor, c):
		return _err("Essa carta não é sua.")
	if c.id in row:
		return _err("Essa carta já está na fila.")
	row.insert(clampi(int(a.get("to", row.size())), 0, row.size()), c.id)
	return _ok([{"type": "row", "card": c.id, "by": actor.get("id", "")}])


## Muda uma carta de lugar na fila. Qualquer um pode, como mexer nas cartas da mesa.
func _a_move(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PLAY:
		return _err("Não é hora de mexer na fila.")
	if not _is_member(actor):
		return _err("Só quem está jogando mexe na fila.")
	var id := str(a.get("card", ""))
	var i := row.find(id)
	if i < 0:
		return _err("Essa carta não está na fila.")
	row.remove_at(i)
	row.insert(clampi(int(a.get("to", i)), 0, row.size()), id)
	return _ok([{"type": "row", "card": id, "by": actor.get("id", "")}])


## Tira a própria carta da fila (volta pra mão).
func _a_take_back(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PLAY:
		return _err("Não é hora de mexer na fila.")
	var c: Dictionary = cards.get(str(a.get("card", "")), {})
	if c.is_empty() or c.id not in row:
		return _err("Essa carta não está na fila.")
	if not _owns(actor, c):
		return _err("Essa carta não é sua.")
	row.erase(c.id)
	return _ok([{"type": "row", "card": c.id, "by": actor.get("id", "")}])


## Palavra-chave opcional da carta (aparece embaixo dela na fila).
func _a_word(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase not in [PHASE_THEME, PHASE_PLAY]:
		return _err("Não dá pra escrever agora.")
	var c: Dictionary = cards.get(str(a.get("card", "")), {})
	if c.is_empty():
		return _err("Carta não encontrada.")
	if not _owns(actor, c):
		return _err("Essa carta não é sua.")
	c.word = TextNorm.clean(str(a.get("text", ""))).left(WORD_MAX)
	return _ok([{"type": "word", "card": c.id}])


## Todas as cartas na fila e o grupo concorda: revela.
func _a_reveal(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_PLAY:
		return _err("Não é hora de revelar.")
	if not _is_member(actor):
		return _err("Só quem está jogando revela.")
	if not all_placed():
		return _err("Ainda tem carta fora da fila.")
	var errors: Array = []
	var top := 0
	for id in row:
		var n: int = cards[id].n
		if n < top:
			errors.append(id)
		top = maxi(top, n)
	var lvl := level()
	rounds.append({"level": lvl, "theme": theme, "cards": row.map(func(id): return {"owner": cards[id].owner, "n": cards[id].n, "word": cards[id].word}), "errors": errors.size()})
	result = {"errors": errors, "lost": 0, "ok": errors.is_empty(), "next": "round", "won": false}
	if config.mode == MODE_DESAFIO:
		if errors.is_empty():
			best = maxi(best, lvl)
			if not _level_up():
				result.next = "game_over"
				result.won = true
		else:
			result.lost = mini(errors.size(), lives)
			lives -= result.lost
			if lives <= 0:
				result.next = "game_over"
	phase = PHASE_REVEAL
	return _ok([{"type": "phase", "phase": phase}, {"type": "revealed", "errors": errors.size(), "ok": errors.is_empty()}])


func _a_continue(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_REVEAL:
		return _err("Nada pra continuar.")
	if not (_is_member(actor) or actor.get("board", false)):
		return _err("Só quem está na partida continua.")
	if result.next == "game_over":
		end_reason = "won" if result.won else "lives"
		phase = PHASE_GAME_OVER
		return _ok([{"type": "game_over", "reason": end_reason}])
	return _ok(_deal([]))


## Rodada solta: encerra e mostra o resumo.
func _a_finish(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("Não há partida pra encerrar.")
	if not actor.get("host", false):
		return _err("Só o host encerra.")
	end_reason = "finished"
	phase = PHASE_GAME_OVER
	return _ok([{"type": "game_over", "reason": end_reason}])


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	return [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]


# --- Visão -----------------------------------------------------------------

## viewer: {"id", "role": "player" | "board" | "local"}. now: ms do host, pro cronômetro.
func view_for(viewer: Dictionary, now := 0) -> Dictionary:
	var you: String = viewer.get("id", "")
	var open := phase in [PHASE_REVEAL, PHASE_GAME_OVER]
	var hide_owner := extreme() and not open
	var out_row: Array = []
	for id in row:
		var c: Dictionary = cards[id]
		var mine: bool = you != "" and c.owner == you
		out_row.append({
			"card": id,
			"owner": "" if hide_owner and not mine else c.owner,
			"word": c.word,
			"n": c.n if open or mine else -1,
			"mine": mine,
		})
	var hand: Array = []
	var pending := {} # id -> cartas que ainda não foram pra fila
	for id in cards:
		var c: Dictionary = cards[id]
		if c.id not in row:
			pending[c.owner] = int(pending.get(c.owner, 0)) + 1
		if you != "" and c.owner == you:
			hand.append({"card": c.id, "n": c.n, "word": c.word, "placed": c.id in row})
	hand.sort_custom(func(x, y): return x.n < y.n)
	# Cartas fora da fila, sem o número: no celular só, o grupo põe por elas (§5).
	var loose: Array = []
	if viewer.get("role", "") == "local":
		for p in players:
			for id in cards:
				var c: Dictionary = cards[id]
				if c.owner == p.id and c.id not in row:
					loose.append({"card": c.id, "owner": c.owner, "word": c.word})
	var counts := {}
	for p in players:
		counts[p.id] = cards_of(p.id)
	return {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": players.duplicate(true),
		"config": config.duplicate(true),
		"local": local_mode,
		"can_start": can_start(),
		"level": level(),
		"lives": lives,
		"max_lives": LIVES,
		"best": best,
		"extreme": extreme(),
		"round_no": round_no,
		"theme": theme,
		"theme_options": theme_options.duplicate() if phase == PHASE_THEME else [],
		"counts": counts,
		"total_cards": cards.size(),
		"row": out_row,
		"hand": hand,
		"pending": pending if not extreme() or open else {},
		"pending_total": cards.size() - row.size(),
		"loose": loose,
		"all_placed": all_placed(),
		"result": result.duplicate(true) if open and phase == PHASE_REVEAL else {},
		"rounds": rounds.duplicate(true) if open else [],
		"end_reason": end_reason,
		"timer_left_ms": maxi(0, int(config.timer_min) * 60000 - (now - round_since)) if phase == PHASE_PLAY and int(config.timer_min) > 0 else -1,
	}


# --- Internos --------------------------------------------------------------

func _is_member(actor: Dictionary) -> bool:
	if actor.get("local", false):
		return true
	return not player(actor.get("id", "")).is_empty()


func _owns(actor: Dictionary, c: Dictionary) -> bool:
	return actor.get("local", false) or actor.get("id", "") == c.owner


func _reset_run() -> void:
	extra = {}
	lives = LIVES
	best = 0
	rounds = []
	round_no = 0
	end_reason = ""
	extra_turn = rng.randi_range(0, players.size() - 1)


## Desafio: uma pessoa ganha +1 carta, rodando pela mesa. Retorna false quando acabou
## (no celular só, ao vencer com todos em 2; senão, quando não cabem mais números).
func _level_up() -> bool:
	if local_mode:
		var all_two := true
		for p in players:
			if cards_of(p.id) < 2:
				all_two = false
		if all_two:
			return false
	if total_cards() + 1 > MAX_NUMBER:
		return false
	var p: Dictionary = players[extra_turn % players.size()]
	extra[p.id] = int(extra.get(p.id, 0)) + 1
	extra_turn = (extra_turn + 1) % players.size()
	return true


## Nova rodada: números novos, sem repetir, e dois temas sorteados.
func _deal(events: Array) -> Array:
	var pool: Array = range(1, MAX_NUMBER + 1)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	cards = {}
	row = []
	var k := 0
	for p in players:
		for i in cards_of(p.id):
			k += 1
			var id := "c%d" % k
			cards[id] = {"id": id, "owner": p.id, "n": pool.pop_back(), "word": ""}
	theme = ""
	theme_options = [themes.draw(rng), themes.draw(rng)]
	if theme_options[0] == theme_options[1] and themes.size() > 1:
		theme_options[1] = themes.draw(rng)
	theme_options = theme_options.filter(func(t): return t != "")
	result = {}
	round_no += 1
	phase = PHASE_THEME
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "dealt", "round": round_no})
	return events


func _set_theme(t: String, actor: Dictionary) -> Dictionary:
	theme = t
	round_since = int(actor.get("now", 0))
	phase = PHASE_PLAY
	return _ok([{"type": "phase", "phase": phase}, {"type": "theme", "theme": t}])


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
