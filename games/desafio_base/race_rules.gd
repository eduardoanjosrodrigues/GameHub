class_name RaceRules
extends RefCounted
## Corrida pelo Wi-Fi do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md §5) como máquina de estados
## pura. Todos tentam o mesmo segredo, que só o host conhece: quem joga manda o palpite, o host confere
## e devolve as cores. Os outros veem só as cores (nunca as letras) até a rodada acabar.
## Cada jogo estende e define o segredo, a conferência do palpite e as cores (os métodos _jogo_*).
## Os palpites vão pela janela do relógio justo (PartyClockHost): a hora de cada um é a do host.
## Ator de uma ação: {"id", "host", "board", "now"}.

const MIN_PLAYERS := 2
const MAX_PLAYERS := 12
const COUNTDOWN_MS := 3000
const TIME_OPTIONS := [0, 2, 3, 5] # minutos; 0 = sem limite
const ROUND_OPTIONS := [3, 5, 10]
const CRITERIA := {
	"tentativas": "Menos tentativas",
	"primeiro": "Primeiro a acertar",
	"pontos": "Pontos em rodadas",
}
const ARRIVAL_BONUS := [3, 2, 1]
## Desempate por tempo no placar de rodadas: rodada sem acerto conta como 10 minutos.
const MISS_MS := 600000

const PHASE_LOBBY := "lobby"
const PHASE_COUNTDOWN := "countdown"
const PHASE_PLAY := "play"
const PHASE_ROUND_END := "round_end"
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, score, time_ms}, na ordem da sala.
var players: Array = []
var config := {"criterio": "tentativas", "tempo_min": 0, "rodadas": 5}
var local_mode := false
var round_no := 0
var start_at := 0 # hora do host em que a rodada começa (fim da contagem)
var deadline := -1
## id -> {guesses: [{g, w, c, ms}], solved, solved_ms, done}
var boards := {}
var results: Array = [] # rodada que acabou: [{id, solved, tries, ms, points, pos}]
var rounds: Array = [] # {secret, results}
var ended_by_time := false
var rng := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# --- O que cada jogo define ------------------------------------------------

## Sorteia o segredo da rodada.
func _jogo_new_secret() -> void:
	pass


## Confere o palpite da ação. {"error": texto} ou {"g": chave, "w": como aparece}.
func _jogo_check(_board: Dictionary, _a: Dictionary) -> Dictionary:
	return {"error": "Palpite inválido."}


func _jogo_colors(_g) -> Array:
	return []


func _jogo_solved(_c: Array) -> bool:
	return false


func _jogo_quality(_c: Array) -> int:
	return 0


func _jogo_max_tries() -> int:
	return 6


## O segredo do jeito que aparece no fim.
func _jogo_secret_view():
	return ""


func _jogo_config(_a: Dictionary) -> void:
	pass


func _jogo_view(_v: Dictionary, _viewer: Dictionary) -> void:
	pass


# --- Consultas -------------------------------------------------------------

func player(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


func can_start() -> String:
	var n := players.size()
	if n < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	return ""


func total_rounds() -> int:
	return int(config.rodadas) if config.criterio == "pontos" else 1


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
	if id == "" or not player(id).is_empty():
		return _err("Jogador já está na sala.")
	var used := players.map(func(p): return int(p.color))
	var c := 0
	while c in used:
		c += 1
	players.append({"id": id, "name": n, "color": c, "connected": true, "score": 0, "time_ms": 0})
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
	if a.has("criterio") and CRITERIA.has(str(a.criterio)):
		config.criterio = str(a.criterio)
	if a.has("tempo_min") and int(a.tempo_min) in TIME_OPTIONS:
		config.tempo_min = int(a.tempo_min)
	if a.has("rodadas") and int(a.rodadas) in ROUND_OPTIONS:
		config.rodadas = int(a.rodadas)
	_jogo_config(a)
	return _ok([{"type": "config"}])


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase not in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	for p in players:
		p.score = 0
		p.time_ms = 0
	round_no = 0
	rounds = []
	return _ok(_begin_round(int(actor.get("now", 0)), [{"type": "started"}]))


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


## Pontos em rodadas: o host chama a próxima.
func _a_next_round(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_ROUND_END:
		return _err("A rodada ainda não acabou.")
	if not actor.get("host", false):
		return _err("Só o host chama a próxima rodada.")
	return _ok(_begin_round(int(actor.get("now", 0)), []))


## Palpite sem a janela do relógio (a hora é a de chegada no host).
func _a_guess(actor: Dictionary, a: Dictionary) -> Dictionary:
	return _ok(_guess(str(actor.get("id", "")), a, int(actor.get("now", 0))))


## Palpites que chegaram na janela do relógio justo, cada um com a hora do host (a.t).
func resolve_timed(list: Array, _now: int) -> Dictionary:
	var sorted := list.duplicate()
	sorted.sort_custom(func(x, y): return int(x.t) < int(y.t))
	var events: Array = []
	for a in sorted:
		events.append_array(_guess(str(a.player), a, int(a.t)))
	return _ok(events)


## O host chama sempre: fim da contagem e do tempo.
func tick(now: int) -> Dictionary:
	if phase == PHASE_COUNTDOWN and now >= start_at:
		phase = PHASE_PLAY
		return _ok([{"type": "go"}])
	if phase == PHASE_PLAY and deadline >= 0 and now >= deadline:
		ended_by_time = true
		return _ok(_end_round([{"type": "time_up"}]))
	return _ok()


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	var events: Array = [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]
	# Quem caiu não segura a rodada dos outros.
	if phase == PHASE_PLAY and _all_done():
		events = _end_round(events)
	return events


# --- Visão -----------------------------------------------------------------

## viewer: {"id", "role"}. now: ms do host.
func view_for(viewer: Dictionary, now := 0) -> Dictionary:
	var you: String = viewer.get("id", "")
	var open := phase in [PHASE_ROUND_END, PHASE_GAME_OVER]
	var others: Array = []
	var full := {}
	for p in players:
		var b: Dictionary = boards.get(p.id, {})
		if b.is_empty():
			continue
		if p.id != you:
			others.append({"id": p.id, "c": b.guesses.map(func(g): return g.c), "solved": b.solved, "done": b.done})
		if open:
			full[p.id] = _board_view(b)
	var v := {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": players.duplicate(true),
		"config": config.duplicate(true),
		"local": local_mode,
		"can_start": can_start(),
		"round": round_no,
		"rounds_total": total_rounds(),
		"max_tries": _jogo_max_tries(),
		"countdown_ms": maxi(0, start_at - now) if phase == PHASE_COUNTDOWN else -1,
		"timer_left_ms": maxi(0, deadline - now) if phase == PHASE_PLAY and deadline >= 0 else -1,
		"me": _board_view(boards[you]) if boards.has(you) else {},
		"others": others,
		"boards": full,
		"secret": _jogo_secret_view() if open else null,
		"results": results.duplicate(true) if open else [],
		"standings": standings() if open else [],
		"time_up": ended_by_time and open,
		"rounds_played": rounds.size(),
	}
	_jogo_view(v, viewer)
	return v


func _board_view(b: Dictionary) -> Dictionary:
	return {
		"guesses": b.guesses.map(func(g): return {"w": g.w, "c": g.c}),
		"solved": b.solved,
		"done": b.done,
		"ms": b.solved_ms,
	}


## Placar geral: pontos (rodadas) e, empatando, a soma dos tempos.
func standings() -> Array:
	var out: Array = players.map(func(p): return {"id": p.id, "score": int(p.score), "time_ms": int(p.time_ms)})
	out.sort_custom(func(x, y): return x.score > y.score or (x.score == y.score and x.time_ms < y.time_ms))
	return out


# --- Internos --------------------------------------------------------------

func _begin_round(now: int, events: Array) -> Array:
	round_no += 1
	_jogo_new_secret()
	boards = {}
	for p in players:
		boards[p.id] = {"guesses": [], "solved": false, "solved_ms": -1, "done": false}
	results = []
	ended_by_time = false
	start_at = now + COUNTDOWN_MS
	deadline = start_at + int(config.tempo_min) * 60000 if int(config.tempo_min) > 0 else -1
	phase = PHASE_COUNTDOWN
	events.append({"type": "round", "round": round_no})
	return events


func _guess(id: String, a: Dictionary, t: int) -> Array:
	if phase != PHASE_PLAY or not boards.has(id):
		return []
	var b: Dictionary = boards[id]
	if b.done:
		return []
	var chk := _jogo_check(b, a)
	if chk.has("error"):
		return [{"type": "rejected", "id": id, "msg": chk.error}]
	var c := _jogo_colors(chk.g)
	var ms := maxi(0, t - start_at)
	b.guesses.append({"g": chk.g, "w": chk.w, "c": c, "ms": ms})
	var events: Array = [{"type": "guess", "id": id}]
	if _jogo_solved(c):
		b.solved = true
		b.solved_ms = ms
		b.done = true
		var pos := boards.values().filter(func(x): return x.solved).size()
		events.append({"type": "solved", "id": id, "pos": pos})
	elif b.guesses.size() >= _jogo_max_tries():
		b.done = true
		events.append({"type": "out", "id": id})
	if _all_done():
		events = _end_round(events)
	return events


func _all_done() -> bool:
	for p in players:
		if p.connected and boards.has(p.id) and not boards[p.id].done:
			return false
	return true


func _end_round(events: Array) -> Array:
	var list: Array = []
	for p in players:
		var b: Dictionary = boards.get(p.id, {})
		if b.is_empty():
			continue
		var best := 0
		for g in b.guesses:
			best = maxi(best, _jogo_quality(g.c))
		list.append({"id": p.id, "solved": b.solved, "tries": b.guesses.size(), "ms": b.solved_ms, "best": best, "points": 0})
	var by_time := func(x, y): return x.ms < y.ms
	var solved: Array = list.filter(func(r): return r.solved)
	solved.sort_custom(by_time)
	# Bônus de chegada (pontos): pela ordem em que acertaram.
	for i in solved.size():
		var r: Dictionary = solved[i]
		r.points = _jogo_max_tries() + 1 - int(r.tries) + (ARRIVAL_BONUS[i] if i < ARRIVAL_BONUS.size() else 0)
	if config.criterio == "tentativas":
		solved.sort_custom(func(x, y): return x.tries < y.tries or (x.tries == y.tries and x.ms < y.ms))
	var missed: Array = list.filter(func(r): return not r.solved)
	missed.sort_custom(func(x, y): return x.best > y.best or (x.best == y.best and x.tries < y.tries))
	results = solved + missed
	for i in results.size():
		results[i].pos = i + 1
	for r in results:
		var p := player(r.id)
		if config.criterio != "pontos":
			r.points = 0
		p.score = int(p.score) + int(r.points)
		p.time_ms = int(p.time_ms) + (int(r.ms) if r.solved else MISS_MS)
	rounds.append({"secret": _jogo_secret_view(), "results": results.duplicate(true)})
	phase = PHASE_ROUND_END if config.criterio == "pontos" and round_no < int(config.rodadas) else PHASE_GAME_OVER
	events.append({"type": "round_end"})
	if phase == PHASE_GAME_OVER:
		events.append({"type": "game_over"})
	return events


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
