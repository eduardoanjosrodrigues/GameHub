class_name ChapeuRules
extends RefCounted
## Regras do Chapéu como máquina de estados pura (docs/PLANO_FASE_1.md §3).
##
## Não conhece tela nem rede. Quem usa manda ações com apply() e avança o tempo com tick().
## O host é o único que roda esta classe no modo Wi-Fi.
##
## Ator de uma ação: {"id": String, "host": bool}. No passa-e-joga o ator é sempre o host.

const TURN_MS := 60000
const MIN_CARRY_MS := 1000
const MIN_PLAYERS := 4
const MAX_PLAYERS := 12
const MIN_PER_TEAM := 2
const MAX_WORD_LEN := 40
const TEAMS := ["azul", "vermelho"]
const ROUNDS := ["descrever", "uma_palavra", "mimica"]
const SOURCES := ["jogadores", "lista", "mistura"]
const WORDS_PER_PLAYER_RANGE := Vector2i(1, 10)
const LIST_COUNT_RANGE := Vector2i(10, 100)

const PHASE_LOBBY := "lobby"
const PHASE_WRITING := "writing"
const PHASE_ROUND_INTRO := "round_intro"
const PHASE_TURN_READY := "turn_ready"
const PHASE_TURN := "turn"
const PHASE_TURN_SUMMARY := "turn_summary"
const PHASE_ROUND_END := "round_end"
const PHASE_GAME_OVER := "game_over"

var mode := "local" # "local" (passa-e-joga) ou "wifi"
var phase := PHASE_LOBBY
## Cada jogador: {id, name, team, connected, explained}
var players: Array = []
var config := {
	"source": "jogadores",
	"words_per_player": 4,
	"list_count": 30,
	"themes": [],
	"opponent_sees_word": false,
}
## id do jogador -> Array[String] das palavras escritas
var submitted := {}
var words: Array = [] # todas as palavras da partida
var hat: Array = [] # índices em `words` que ainda estão no chapéu
var round_idx := 0
var team_turn := 0 # índice em TEAMS do time da vez
var explainer := ""
var carry := {} # {"player": id, "ms": int} quando o chapéu esvaziou no meio da vez
var time_ms := TURN_MS
var paused := false
var pause_reason := "" # "user" ou "disconnect"
var current := -1 # índice da palavra na tela
var last_skipped := -1
var turn_hits: Array = []
var turn_skips := 0
var turn_round_over := false
## scores[rodada][time] = acertos − pulos
var scores: Array = []
var result := {}
var word_lists := {} # id do tema -> {"nome": String, "palavras": Array}
var rng := RandomNumberGenerator.new()

var _next_local_id := 1


func _init(p_mode := "local", p_word_lists := {}, seed_value := -1) -> void:
	mode = p_mode
	word_lists = p_word_lists
	config.themes = word_lists.keys()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_reset_scores()


# --- Consultas -------------------------------------------------------------

func player(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


func team_players(team: String) -> Array:
	return players.filter(func(p): return p.team == team)


func current_team() -> String:
	return TEAMS[team_turn]


func totals() -> Dictionary:
	var t := {"azul": 0, "vermelho": 0}
	for r in scores:
		t.azul += r[0]
		t.vermelho += r[1]
	return t


func can_start() -> String:
	## Retorna "" se dá pra começar, senão o motivo.
	if players.size() < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if players.size() > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	for team in TEAMS:
		if team_players(team).size() < MIN_PER_TEAM:
			return "Cada time precisa de pelo menos %d jogadores." % MIN_PER_TEAM
	if config.source != "jogadores" and config.themes.is_empty():
		return "Escolha pelo menos um tema de palavras."
	return ""


func needs_writing() -> bool:
	return config.source != "lista"


func pending_writers() -> Array:
	return players.filter(func(p): return not submitted.has(p.id))


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
	var team: String = a.get("team", "")
	if team not in TEAMS:
		team = _smaller_team()
	players.append({"id": id, "name": n, "team": team, "connected": true, "explained": 0})
	return _ok([{"type": "player_joined", "id": id, "name": n}])


func _a_remove_player(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host remove jogadores.")
	var id: String = a.get("id", "")
	var p := player(id)
	if p.is_empty():
		return _err("Jogador não encontrado.")
	players.erase(p)
	submitted.erase(id)
	return _ok([{"type": "player_left", "id": id, "name": p.name}])


func _a_set_team(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("Os times já estão fechados.")
	var id: String = a.get("id", actor.get("id", ""))
	if id != actor.get("id", "") and not actor.get("host", false):
		return _err("Você só pode escolher o seu time.")
	var team: String = a.get("team", "")
	if team not in TEAMS:
		return _err("Time inválido.")
	var p := player(id)
	if p.is_empty():
		return _err("Jogador não encontrado.")
	p.team = team
	return _ok()


func _a_set_config(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host muda a configuração.")
	if a.has("source"):
		if a.source not in SOURCES:
			return _err("Fonte de palavras inválida.")
		config.source = a.source
	if a.has("words_per_player"):
		config.words_per_player = clampi(int(a.words_per_player), WORDS_PER_PLAYER_RANGE.x, WORDS_PER_PLAYER_RANGE.y)
	if a.has("list_count"):
		config.list_count = clampi(int(a.list_count), LIST_COUNT_RANGE.x, LIST_COUNT_RANGE.y)
	if a.has("themes"):
		var th: Array = []
		for t in a.themes:
			if word_lists.has(t) and t not in th:
				th.append(t)
		config.themes = th
	if a.has("opponent_sees_word"):
		config.opponent_sees_word = bool(a.opponent_sees_word)
	return _ok()


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	submitted.clear()
	if needs_writing():
		phase = PHASE_WRITING
		return _ok([{"type": "phase", "phase": phase}])
	return _begin_game()


func _a_submit_words(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_WRITING:
		return _err("Não é hora de escrever palavras.")
	var id: String = a.get("id", actor.get("id", ""))
	if id != actor.get("id", "") and not actor.get("host", false):
		return _err("Você só pode enviar as suas palavras.")
	if player(id).is_empty():
		return _err("Jogador não encontrado.")
	if submitted.has(id):
		return _err("Você já enviou suas palavras.")
	var list: Array = []
	for w in a.get("words", []):
		var c := TextNorm.clean(str(w))
		if c == "":
			return _err("Preencha todas as palavras.")
		if c.length() > MAX_WORD_LEN:
			return _err("Cada palavra pode ter até %d letras." % MAX_WORD_LEN)
		list.append(c)
	if list.size() != int(config.words_per_player):
		return _err("Escreva %d palavras." % config.words_per_player)
	submitted[id] = list
	var events := [{"type": "words_submitted", "id": id}]
	if pending_writers().is_empty():
		var r := _begin_game()
		r.events = events + r.events
		return r
	return _ok(events)


func _a_next(actor: Dictionary, _a: Dictionary) -> Dictionary:
	var is_host: bool = actor.get("host", false)
	match phase:
		PHASE_ROUND_INTRO:
			if not is_host:
				return _err("Só o host avança.")
			phase = PHASE_TURN_READY
			explainer = ""
			if not carry.is_empty():
				explainer = carry.player
				time_ms = carry.ms
				team_turn = TEAMS.find(player(explainer).team)
			else:
				time_ms = TURN_MS
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_TURN_SUMMARY:
			if not is_host and actor.get("id", "") != explainer:
				return _err("Só quem explicou ou o host avança.")
			if turn_round_over:
				phase = PHASE_ROUND_END
				return _ok([{"type": "phase", "phase": phase}])
			team_turn = 1 - team_turn
			explainer = ""
			time_ms = TURN_MS
			phase = PHASE_TURN_READY
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_ROUND_END:
			if not is_host:
				return _err("Só o host avança.")
			if round_idx >= ROUNDS.size() - 1:
				result = _compute_result()
				phase = PHASE_GAME_OVER
				return _ok([{"type": "game_over", "result": result}])
			round_idx += 1
			hat = range(words.size())
			if carry.is_empty():
				team_turn = 1 - team_turn
			phase = PHASE_ROUND_INTRO
			return _ok([{"type": "phase", "phase": phase}])
	return _err("Nada pra avançar agora.")


func _a_choose_explainer(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN_READY:
		return _err("Não é hora de escolher quem explica.")
	if not carry.is_empty():
		if player(carry.player).get("connected", false):
			return _err("%s continua com o tempo que sobrou." % player(carry.player).get("name", ""))
		# Quem tinha o tempo guardado caiu: o time escolhe outra pessoa, com a vez inteira.
		carry = {}
		time_ms = TURN_MS
	var team := current_team()
	var me := player(actor.get("id", ""))
	if not actor.get("host", false) and (me.is_empty() or me.team != team):
		return _err("Só o time da vez escolhe quem explica.")
	var p := player(a.get("id", ""))
	if p.is_empty() or p.team != team:
		return _err("Escolha alguém do time da vez.")
	if not p.connected:
		return _err("%s está desconectado." % p.name)
	explainer = p.id
	return _ok([{"type": "explainer_chosen", "id": p.id}])


func _a_start_turn(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN_READY or explainer == "":
		return _err("Escolha quem vai explicar.")
	if not _is_explainer_or_local_host(actor):
		return _err("Só quem vai explicar começa a vez.")
	if carry.is_empty():
		player(explainer).explained += 1
	carry = {}
	phase = PHASE_TURN
	paused = false
	pause_reason = ""
	turn_hits = []
	turn_skips = 0
	turn_round_over = false
	last_skipped = -1
	_draw_word()
	return _ok([{"type": "turn_started"}, {"type": "new_word"}])


func _a_hit(actor: Dictionary, _a: Dictionary) -> Dictionary:
	var why := _check_turn_action(actor)
	if why != "":
		return _err(why)
	var r := round_idx
	scores[r][team_turn] += 1
	turn_hits.append(current)
	hat.erase(current)
	var events := [{"type": "hit", "team": current_team()}]
	if hat.is_empty():
		current = -1
		turn_round_over = true
		if round_idx < ROUNDS.size() - 1 and time_ms >= MIN_CARRY_MS:
			carry = {"player": explainer, "ms": time_ms}
		phase = PHASE_TURN_SUMMARY
		events.append({"type": "hat_empty"})
		return _ok(events)
	_draw_word()
	events.append({"type": "new_word"})
	return _ok(events)


func _a_skip(actor: Dictionary, _a: Dictionary) -> Dictionary:
	var why := _check_turn_action(actor)
	if why != "":
		return _err(why)
	scores[round_idx][team_turn] -= 1
	turn_skips += 1
	last_skipped = current
	_draw_word()
	return _ok([{"type": "skip", "team": current_team()}, {"type": "new_word"}])


func _a_pause(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN or paused:
		return _err("Não dá pra pausar agora.")
	if not _is_explainer_or_local_host(actor):
		return _err("Só quem está explicando pausa.")
	paused = true
	pause_reason = "user"
	return _ok([{"type": "paused"}])


func _a_resume(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN or not paused:
		return _err("O jogo não está pausado.")
	if not _is_explainer_or_local_host(actor):
		return _err("Só quem está explicando retoma.")
	if not player(explainer).get("connected", false):
		return _err("Esperando %s voltar." % player(explainer).get("name", ""))
	paused = false
	pause_reason = ""
	return _ok([{"type": "resumed"}])


## Host encerra a vez de um explicador que caiu (a vez termina como se o tempo acabasse).
func _a_end_turn(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN:
		return _err("Não há vez em andamento.")
	if not actor.get("host", false):
		return _err("Só o host encerra a vez.")
	return _finish_turn_by_time()


## Joga de novo com os mesmos jogadores, times e configuração.
func _a_rematch(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GAME_OVER:
		return _err("A partida ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host começa outra partida.")
	for p in players:
		p.explained = 0
	result = {}
	carry = {}
	round_idx = 0
	_reset_scores()
	phase = PHASE_LOBBY
	return _a_start(actor, {})


# --- Tempo e conexão -------------------------------------------------------

## Avança o cronômetro. Retorna eventos (contagem regressiva e fim do tempo).
func tick(ms: int) -> Array:
	if phase != PHASE_TURN or paused:
		return []
	time_ms -= ms
	if time_ms <= 0:
		time_ms = 0
		return _finish_turn_by_time().events
	return []


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	var events: Array = [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]
	if not connected and phase == PHASE_TURN and id == explainer and not paused:
		paused = true
		pause_reason = "disconnect"
		events.append({"type": "paused"})
	elif connected and paused and pause_reason == "disconnect" and id == explainer:
		pause_reason = "user"
	if not connected and phase == PHASE_TURN_READY and id == explainer and carry.is_empty():
		explainer = ""
	return events


# --- Visão (o que cada aparelho pode ver) ---------------------------------

## viewer: {"id": String, "role": "local" | "player" | "board"}
func view_for(viewer: Dictionary) -> Dictionary:
	var role: String = viewer.get("role", "local")
	var me := player(viewer.get("id", ""))
	var v := {
		"phase": phase,
		"mode": mode,
		"you": viewer.get("id", ""),
		"role": role,
		"players": players.duplicate(true),
		"config": config.duplicate(true),
		"themes": _theme_names(),
		"can_start": can_start(),
		"round": round_idx,
		"round_key": ROUNDS[round_idx],
		"team_turn": current_team(),
		"explainer": explainer,
		"carry_ms": int(carry.ms) if not carry.is_empty() else 0,
		"time_ms": time_ms,
		"turn_ms": TURN_MS,
		"paused": paused,
		"pause_reason": pause_reason,
		"scores": scores.duplicate(true),
		"totals": totals(),
		"hat_count": hat.size(),
		"word_count": words.size(),
		"submitted": submitted.keys(),
		"turn_hits": turn_hits.size(),
		"turn_skips": turn_skips,
		"turn_round_over": turn_round_over,
		"result": result.duplicate(true),
		"word": "",
		"hit_words": [],
	}
	if phase == PHASE_TURN_SUMMARY:
		v.hit_words = turn_hits.map(func(i): return words[i])
	if phase == PHASE_TURN and current >= 0 and not paused:
		var can_see := false
		match role:
			"local":
				can_see = true
			"player":
				if me.get("id", "") == explainer:
					can_see = true
				elif config.opponent_sees_word and not me.is_empty() and me.team != current_team():
					can_see = true
		if can_see:
			v.word = words[current]
	return v


# --- Internos --------------------------------------------------------------

func _begin_game() -> Dictionary:
	words = []
	for p in players:
		if submitted.has(p.id):
			words.append_array(submitted[p.id])
	if config.source != "jogadores":
		words.append_array(_pick_list_words(int(config.list_count), words))
	_reset_scores()
	round_idx = 0
	team_turn = 0 # o Time Azul sempre começa
	explainer = ""
	carry = {}
	time_ms = TURN_MS
	hat = range(words.size())
	phase = PHASE_ROUND_INTRO
	return _ok([{"type": "phase", "phase": phase}])


func _pick_list_words(count: int, existing: Array) -> Array:
	var taken := {}
	for w in existing:
		taken[TextNorm.normalize(w)] = true
	var pool: Array = []
	for t in config.themes:
		if not word_lists.has(t):
			continue
		for w in word_lists[t].palavras:
			var k := TextNorm.normalize(w)
			if not taken.has(k):
				taken[k] = true
				pool.append(w)
	_shuffle(pool)
	return pool.slice(0, min(count, pool.size()))


func _draw_word() -> void:
	var options := hat.duplicate()
	if options.size() > 1 and last_skipped in options:
		options.erase(last_skipped)
	if options.size() > 1 and current in options:
		options.erase(current)
	current = options[rng.randi() % options.size()]


func _finish_turn_by_time() -> Dictionary:
	current = -1
	paused = false
	pause_reason = ""
	turn_round_over = false
	phase = PHASE_TURN_SUMMARY
	return _ok([{"type": "time_up"}])


func _check_turn_action(actor: Dictionary) -> String:
	if phase != PHASE_TURN:
		return "Não é hora disso."
	if paused:
		return "O jogo está pausado."
	if not _is_explainer_or_local_host(actor):
		return "Só quem está explicando pode fazer isso."
	return ""


func _is_explainer_or_local_host(actor: Dictionary) -> bool:
	if actor.get("id", "") == explainer and explainer != "":
		return true
	return mode == "local" and actor.get("host", false)


func _compute_result() -> Dictionary:
	var t := totals()
	var rounds_won := [0, 0]
	for r in scores:
		if r[0] > r[1]:
			rounds_won[0] += 1
		elif r[1] > r[0]:
			rounds_won[1] += 1
	var mimica: Array = scores[ROUNDS.size() - 1]
	var winner := ""
	var criterion := "empate"
	if t.azul != t.vermelho:
		winner = "azul" if t.azul > t.vermelho else "vermelho"
		criterion = "pontos"
	elif rounds_won[0] != rounds_won[1]:
		winner = "azul" if rounds_won[0] > rounds_won[1] else "vermelho"
		criterion = "rodadas"
	elif mimica[0] != mimica[1]:
		winner = "azul" if mimica[0] > mimica[1] else "vermelho"
		criterion = "mimica"
	return {
		"winner": winner,
		"criterion": criterion,
		"totals": t,
		"rounds_won": {"azul": rounds_won[0], "vermelho": rounds_won[1]},
		"scores": scores.duplicate(true),
	}


func _smaller_team() -> String:
	var a := team_players("azul").size()
	var b := team_players("vermelho").size()
	return "vermelho" if b < a else "azul"


func _theme_names() -> Array:
	var out: Array = []
	for id in word_lists:
		out.append({"id": id, "nome": word_lists[id].nome, "count": word_lists[id].palavras.size()})
	return out


func _reset_scores() -> void:
	scores = []
	for i in ROUNDS.size():
		scores.append([0, 0])


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
