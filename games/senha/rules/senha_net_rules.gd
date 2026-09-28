class_name SenhaNetRules
extends RaceRules
## Senha pelo Wi-Fi (docs/PLANO_WORDLE_SENHA.md §4.4, §4.5). O host escolhe o nível, o retorno e a
## aparência (cores ou números) pra todos, e o modo:
##   corrida: todos tentam a mesma senha sorteada (a Corrida de RaceRules).
##   duelo:   1 contra 1, cada um cria a senha do outro. "alternado": um palpite por vez; se quem
##            começou quebrar, o outro ainda tem a última chance naquela rodada (os dois acertando,
##            empata). "tempo": os dois ao mesmo tempo, vence quem quebrar primeiro (relógio justo).
##            Ninguém quebrando em 10 tentativas, ou o tempo acabando, é empate.

const MODES := {"corrida": "Corrida", "duelo": "Duelo"}
const DUEL_TYPES := {"alternado": "Alternado", "tempo": "Modo tempo"}
const PHASE_CREATE := "create"

var secret: Array = []
var codes := {} # duelo: id -> senha criada por ele
var starter := "" # duelo alternado: quem começa
var turn := ""
var winner := "" # duelo: id, ou "" com empate


func _init(seed_value := -1) -> void:
	super(seed_value)
	config.nivel = "medio"
	config.retorno = "contagem"
	config.aparencia = "cores"
	config.modo = "corrida"
	config.duelo = "alternado"


func duel() -> bool:
	return config.modo == "duelo"


func other_of(id: String) -> String:
	for p in players:
		if p.id != id:
			return p.id
	return ""


func can_start() -> String:
	if duel():
		return "" if players.size() == 2 else "O duelo é de 2 jogadores."
	return super()


func total_rounds() -> int:
	return 1 if duel() else super()


# --- Regras do jogo --------------------------------------------------------

func _jogo_new_secret() -> void:
	secret = SenhaLogic.random_code(config.nivel, rng)


func _jogo_check(_board: Dictionary, a: Dictionary) -> Dictionary:
	var pins = a.get("pins", [])
	if not pins is Array:
		return {"error": "Palpite inválido."}
	var why := SenhaLogic.check(pins, config.nivel)
	if why != "":
		return {"error": why}
	var g := SenhaLogic.ints(pins)
	return {"g": g, "w": g}


func _jogo_colors(g) -> Array:
	return SenhaLogic.feedback(g, secret, config.retorno)


func _jogo_solved(c: Array) -> bool:
	return SenhaLogic.solved(c, config.retorno, int(SenhaLogic.level(config.nivel).pins))


func _jogo_quality(c: Array) -> int:
	return SenhaLogic.quality(c, config.retorno)


func _jogo_max_tries() -> int:
	return SenhaLogic.TRIES


func _jogo_secret_view():
	return secret.duplicate()


func _jogo_config(a: Dictionary) -> void:
	if a.has("nivel") and SenhaLogic.LEVELS.has(str(a.nivel)):
		config.nivel = str(a.nivel)
	if a.has("retorno") and SenhaLogic.FEEDBACKS.has(str(a.retorno)):
		config.retorno = str(a.retorno)
	if a.has("aparencia") and SenhaLogic.LOOKS.has(str(a.aparencia)):
		config.aparencia = str(a.aparencia)
	if a.has("modo") and MODES.has(str(a.modo)):
		config.modo = str(a.modo)
	if a.has("duelo") and DUEL_TYPES.has(str(a.duelo)):
		config.duelo = str(a.duelo)


func _jogo_view(v: Dictionary, viewer: Dictionary) -> void:
	var lv := SenhaLogic.level(config.nivel)
	v.pins = lv.pins
	v.symbols = lv.symbols
	v.repeat = lv.repeat
	if not duel():
		return
	var you: String = viewer.get("id", "")
	var opp := other_of(you)
	var open := phase == PHASE_GAME_OVER
	v.duel = true
	v.opponent = opp
	v.turn = turn
	v.starter = starter
	v.winner = winner
	v.my_code = codes.get(you, []).duplicate()
	v.codes_ready = {}
	for p in players:
		v.codes_ready[p.id] = codes.has(p.id)
	# O duelo mostra tudo dos dois lados: os meus ataques e os ataques do outro contra a minha senha.
	v.opp_board = _board_view(boards[opp]) if boards.has(opp) else {}
	v.codes = codes.duplicate(true) if open else {}
	# Nada de mini-grades nem "segredo" único no duelo.
	v.others = []
	v.secret = null


# --- Duelo -----------------------------------------------------------------

func _a_start(actor: Dictionary, a: Dictionary) -> Dictionary:
	if not duel():
		return super(actor, a)
	if phase not in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	codes = {}
	boards = {}
	results = []
	winner = ""
	turn = ""
	round_no = 1
	rounds = []
	ended_by_time = false
	phase = PHASE_CREATE
	return _ok([{"type": "started"}])


## Duelo: cada um cria a senha que o outro vai quebrar.
func _a_set_code(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_CREATE:
		return _err("Não é hora de criar a senha.")
	var id: String = actor.get("id", "")
	if player(id).is_empty():
		return _err("Você não está na partida.")
	var pins = a.get("pins", [])
	if not pins is Array:
		return _err("Senha inválida.")
	var why := SenhaLogic.check(pins, config.nivel)
	if why != "":
		return _err(why)
	codes[id] = SenhaLogic.ints(pins)
	var events: Array = [{"type": "code_set", "id": id}]
	if codes.size() == 2:
		for p in players:
			boards[p.id] = {"guesses": [], "solved": false, "solved_ms": -1, "done": false}
		starter = players[rng.randi_range(0, 1)].id
		turn = starter if config.duelo == "alternado" else ""
		start_at = int(actor.get("now", 0)) + COUNTDOWN_MS
		deadline = start_at + int(config.tempo_min) * 60000 if int(config.tempo_min) > 0 else -1
		phase = PHASE_COUNTDOWN
		events.append({"type": "round", "round": 1})
	return _ok(events)


func _guess(id: String, a: Dictionary, t: int) -> Array:
	if not duel():
		return super(id, a, t)
	if phase != PHASE_PLAY or not boards.has(id):
		return []
	var b: Dictionary = boards[id]
	if b.done:
		return []
	if config.duelo == "alternado" and id != turn:
		return [{"type": "rejected", "id": id, "msg": "Espere a sua vez."}]
	var chk := _jogo_check(b, a)
	if chk.has("error"):
		return [{"type": "rejected", "id": id, "msg": chk.error}]
	var opp := other_of(id)
	var c := SenhaLogic.feedback(chk.g, codes[opp], config.retorno)
	var ms := maxi(0, t - start_at)
	b.guesses.append({"g": chk.g, "w": chk.w, "c": c, "ms": ms})
	var events: Array = [{"type": "guess", "id": id}]
	if _jogo_solved(c):
		b.solved = true
		b.solved_ms = ms
		b.done = true
		events.append({"type": "solved", "id": id, "pos": 1})
	elif b.guesses.size() >= SenhaLogic.TRIES:
		b.done = true
		events.append({"type": "out", "id": id})
	var ob: Dictionary = boards[opp]
	if config.duelo == "tempo":
		if b.solved:
			return _end_duel(id, events)
		if b.done and ob.done:
			return _end_duel("", events)
		return events
	# Alternado: a rodada fecha quando os dois fizeram o mesmo número de palpites.
	var sb: Dictionary = boards[starter]
	var other_b: Dictionary = boards[other_of(starter)]
	if sb.guesses.size() == other_b.guesses.size():
		if sb.solved and other_b.solved:
			return _end_duel("", events)
		if sb.solved:
			return _end_duel(starter, events)
		if other_b.solved:
			return _end_duel(other_of(starter), events)
		if sb.guesses.size() >= SenhaLogic.TRIES:
			return _end_duel("", events)
		turn = starter
	else:
		turn = other_of(starter)
	events.append({"type": "turn", "id": turn})
	return events


func tick(now: int) -> Dictionary:
	if duel() and phase == PHASE_PLAY and deadline >= 0 and now >= deadline:
		ended_by_time = true
		return _ok(_end_duel("", [{"type": "time_up"}]))
	return super(now)


func set_connected(id: String, connected: bool) -> Array:
	if not duel():
		return super(id, connected)
	# No duelo a partida espera quem caiu (ele volta pro mesmo lugar).
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	return [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]


func _end_duel(win: String, events: Array) -> Array:
	winner = win
	turn = ""
	results = []
	for p in players:
		var b: Dictionary = boards.get(p.id, {})
		results.append({"id": p.id, "solved": b.get("solved", false), "tries": b.get("guesses", []).size(), "ms": b.get("solved_ms", -1), "points": 0,
			"pos": 1 if win == "" or win == p.id else 2})
	results.sort_custom(func(x, y): return x.pos < y.pos)
	phase = PHASE_GAME_OVER
	events.append({"type": "round_end"})
	events.append({"type": "game_over"})
	return events
