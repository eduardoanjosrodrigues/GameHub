class_name SintoniaRules
extends RefCounted
## Regras da Sintonia (tipo Wavelength) como máquina de estados pura (docs/PLANO_SINTONIA_ITO.md §3).
##
## Quem dá a dica vê o alvo num meio disco de 0 a 100 e escolhe um de dois temas (dois extremos).
## Fala uma dica; o time gira a agulha e trava. No modo times, o outro time aposta se o alvo
## está à esquerda ou à direita da agulha. Pontos pelo quão perto a agulha ficou do alvo.
## Ator de uma ação: {"id", "host", "board", "local", "now"}. No modo de um celular só
## ("local"), o aparelho age por qualquer um.

const MIN_TEAMS_PLAYERS := 4
const MIN_TEAM := 2
const MIN_COOP := 2
const MAX_PLAYERS := 12
const WIN_AT := 10
const COOP_ROUNDS := 7
const TIMER_RANGE := Vector2i(0, 5) # minutos; 0 = desligado
const TARGET_RANGE := Vector2(10.0, 90.0) # o alvo cabe inteiro no disco
const STEP := 0.5
## Distância máxima do centro do alvo -> pontos (§3.1). Na linha, vale a faixa melhor.
const ZONES := [[2.0, 4], [6.0, 3], [10.0, 2]]
const SIDE_MAX := 40

const MODE_TIMES := "times"
const MODE_COOP := "coop"
const TEAMS := ["azul", "vermelho"]

const PHASE_LOBBY := "lobby"
const PHASE_PICK := "pick" # quem dá a dica vê o alvo e escolhe o tema
const PHASE_DIAL := "dial" # o time gira a agulha
const PHASE_GUESS := "guess" # o outro time aposta esquerda ou direita (só no modo times)
const PHASE_REVEAL := "reveal"
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, team}, na ordem da mesa.
var players: Array = []
var config := {"mode": MODE_TIMES, "timer_min": 0}
var local_mode := false
var themes: ThemeBank
var scores := {"azul": 0, "vermelho": 0}
var coop_score := 0
var cards_left := 0 # cooperativo: rodadas que faltam, contando a atual
var turn_team := "" # modo times: time da vez
var psychic := "" # quem dá a dica
var options: Array = [] # [[esquerda, direita], [esquerda, direita]]
var theme: Array = [] # [esquerda, direita]
var target := 50.0
var dial := 50.0
var dial_by := ""
var side := "" # aposta do outro time: "left" | "right"
var side_by := ""
var last := {} # resultado da rodada: {points, side_points, bonus, catch_up, dist}
var rounds: Array = [] # {team, psychic, theme, target, dial, points, side, side_points}
var sudden := false # empate em 10+: morte súbita
var sudden_rounds := 0
var winner := "" # "azul" | "vermelho" (times) ou "coop"
var round_since := 0
var rng := RandomNumberGenerator.new()

var _next_psy := {"azul": 0, "vermelho": 0, "coop": 0}
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


func team_members(team: String) -> Array:
	return players.filter(func(p): return p.team == team)


static func other(team: String) -> String:
	return "vermelho" if team == "azul" else "azul"


static func points_for(dist: float) -> int:
	for z in ZONES:
		if dist <= z[0] + 0.0001:
			return z[1]
	return 0


func can_start() -> String:
	var n := players.size()
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	if config.mode == MODE_COOP:
		return "" if n >= MIN_COOP else "São precisos pelo menos %d jogadores." % MIN_COOP
	if n < MIN_TEAMS_PLAYERS:
		return "Com times, são precisos pelo menos %d jogadores." % MIN_TEAMS_PLAYERS
	for t in TEAMS:
		if team_members(t).size() < MIN_TEAM:
			return "Cada time precisa de pelo menos %d pessoas." % MIN_TEAM
	return ""


## Quem pode girar a agulha agora (o time da vez, menos quem deu a dica).
func can_turn(actor: Dictionary) -> bool:
	if actor.get("local", false) or actor.get("board", false):
		return true
	var p := player(actor.get("id", ""))
	if p.is_empty() or p.id == psychic:
		return false
	return config.mode == MODE_COOP or p.team == turn_team


## Quem aposta o lado agora (o outro time).
func can_bet(actor: Dictionary) -> bool:
	if actor.get("local", false) or actor.get("board", false):
		return true
	var p := player(actor.get("id", ""))
	return not p.is_empty() and p.team == other(turn_team)


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
	# Entra no time com menos gente.
	var team := "vermelho" if team_members("azul").size() > team_members("vermelho").size() else "azul"
	players.append({"id": id, "name": n, "color": _next_color, "connected": true, "team": team})
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


func _a_set_team(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host monta os times.")
	var p := player(a.get("id", ""))
	if p.is_empty():
		return _err("Jogador não encontrado.")
	if a.get("team", "") not in TEAMS:
		return _err("Time inválido.")
	p.team = a.team
	return _ok([{"type": "teams"}])


func _a_shuffle_teams(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host sorteia os times.")
	var idx: Array = range(players.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var first: String = TEAMS[rng.randi_range(0, 1)]
	for k in idx.size():
		players[idx[k]].team = first if k % 2 == 0 else other(first)
	return _ok([{"type": "teams"}])


func _a_set_config(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host muda a partida.")
	if a.has("mode"):
		if a.mode not in [MODE_TIMES, MODE_COOP]:
			return _err("Modo desconhecido.")
		config.mode = a.mode
	if a.has("timer_min"):
		config.timer_min = clampi(int(a.timer_min), TIMER_RANGE.x, TIMER_RANGE.y)
	return _ok([{"type": "config"}])


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase not in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	scores = {"azul": 0, "vermelho": 0}
	coop_score = 0
	rounds = []
	sudden = false
	sudden_rounds = 0
	winner = ""
	last = {}
	if config.mode == MODE_TIMES:
		turn_team = TEAMS[rng.randi_range(0, 1)]
		# O time que joga depois começa com 1 ponto (oficial).
		scores[other(turn_team)] = 1
		_next_psy = {"azul": rng.randi_range(0, 99), "vermelho": rng.randi_range(0, 99), "coop": 0}
	else:
		turn_team = ""
		cards_left = COOP_ROUNDS
		_next_psy = {"azul": 0, "vermelho": 0, "coop": rng.randi_range(0, players.size() - 1)}
	return _ok(_begin_round([{"type": "started"}]))


## Revanche: mesmos times e mesmo modo.
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


func _a_pick_theme(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PICK:
		return _err("Não é hora de escolher o tema.")
	if not _is_psychic(actor):
		return _err("Só quem dá a dica escolhe o tema.")
	var i := int(a.get("index", -1))
	if i < 0 or i >= options.size():
		return _err("Tema inválido.")
	return _set_theme(options[i], actor)


func _a_custom_theme(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PICK:
		return _err("Não é hora de escolher o tema.")
	if not _is_psychic(actor):
		return _err("Só quem dá a dica escolhe o tema.")
	var l := TextNorm.clean(str(a.get("left", ""))).left(SIDE_MAX)
	var r := TextNorm.clean(str(a.get("right", ""))).left(SIDE_MAX)
	if l == "" or r == "":
		return _err("Escreva os dois extremos.")
	return _set_theme([l, r], actor)


## A agulha mudou (arrasto ao vivo): vale a última posição.
func _a_dial(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_DIAL:
		return _err("A agulha está travada.")
	if not can_turn(actor):
		return _err("Só o time da vez gira a agulha.")
	dial = _snap(float(a.get("pos", dial)))
	dial_by = actor.get("id", "")
	return _ok([{"type": "dial", "pos": dial, "by": dial_by}])


func _a_lock(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_DIAL:
		return _err("Não é hora de travar.")
	if not can_turn(actor):
		return _err("Só o time da vez trava a agulha.")
	if config.mode == MODE_COOP:
		return _ok(_reveal([{"type": "locked"}]))
	side = ""
	side_by = ""
	phase = PHASE_GUESS
	return _ok([{"type": "locked"}, {"type": "phase", "phase": phase}])


func _a_side(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_GUESS:
		return _err("Não é hora de apostar.")
	if not can_bet(actor):
		return _err("Só o outro time aposta.")
	if a.get("side", "") not in ["left", "right"]:
		return _err("Escolha esquerda ou direita.")
	side = a.side
	side_by = actor.get("id", "")
	return _ok([{"type": "side", "side": side, "by": side_by}])


func _a_lock_side(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_GUESS:
		return _err("Não é hora de travar a aposta.")
	if not can_bet(actor):
		return _err("Só o outro time trava a aposta.")
	if side == "":
		return _err("Escolha esquerda ou direita.")
	return _ok(_reveal([{"type": "side_locked"}]))


func _a_continue(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_REVEAL:
		return _err("Nada pra continuar.")
	if not (_is_member(actor) or actor.get("board", false)):
		return _err("Só quem está na partida continua.")
	if winner != "":
		phase = PHASE_GAME_OVER
		return _ok([{"type": "game_over", "winner": winner}])
	return _ok(_begin_round([]))


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
	var is_psy := you != "" and you == psychic
	var me := player(you)
	return {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": players.duplicate(true),
		"config": config.duplicate(true),
		"local": local_mode,
		"can_start": can_start(),
		"my_team": me.get("team", "") if config.mode == MODE_TIMES else "",
		"scores": scores.duplicate(),
		"win_at": WIN_AT,
		"coop_score": coop_score,
		"cards_left": cards_left,
		"coop_rounds": COOP_ROUNDS,
		"turn_team": turn_team,
		"psychic": psychic,
		"options": options.duplicate(true) if is_psy and phase == PHASE_PICK else [],
		"theme": theme.duplicate(),
		"target": target if open or (is_psy and phase in [PHASE_PICK, PHASE_DIAL, PHASE_GUESS]) else -1.0,
		"dial": dial,
		"dial_by": dial_by,
		"side": side,
		"side_by": side_by,
		"last": last.duplicate() if open else {},
		"rounds": rounds.duplicate(true),
		"sudden": sudden,
		"winner": winner,
		"zones": ZONES.duplicate(true),
		"timer_left_ms": maxi(0, int(config.timer_min) * 60000 - (now - round_since)) if phase == PHASE_DIAL and int(config.timer_min) > 0 else -1,
	}


# --- Internos --------------------------------------------------------------

func _is_member(actor: Dictionary) -> bool:
	return actor.get("local", false) or not player(actor.get("id", "")).is_empty()


func _is_psychic(actor: Dictionary) -> bool:
	return actor.get("local", false) or (psychic != "" and actor.get("id", "") == psychic)


func _snap(x: float) -> float:
	return clampf(snappedf(x, STEP), 0.0, 100.0)


## Próxima pessoa a dar a dica: rodando dentro do time (ou pela mesa, no cooperativo).
func _pick_psychic() -> String:
	var key := turn_team if config.mode == MODE_TIMES else "coop"
	var list: Array = team_members(turn_team) if config.mode == MODE_TIMES else players
	var i: int = _next_psy[key] % list.size()
	_next_psy[key] = i + 1
	return list[i].id


func _begin_round(events: Array) -> Array:
	psychic = _pick_psychic()
	options = []
	for k in 2:
		var line := themes.draw(rng)
		var parts := line.split("|")
		if parts.size() == 2:
			options.append([parts[0].strip_edges(), parts[1].strip_edges()])
	if options.size() == 2 and options[0] == options[1] and themes.size() > 1:
		options.pop_back()
	theme = []
	target = snappedf(rng.randf_range(TARGET_RANGE.x, TARGET_RANGE.y), STEP)
	dial = 50.0
	dial_by = ""
	side = ""
	side_by = ""
	last = {}
	phase = PHASE_PICK
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "round", "psychic": psychic, "team": turn_team})
	return events


func _set_theme(t: Array, actor: Dictionary) -> Dictionary:
	theme = [str(t[0]), str(t[1])]
	round_since = int(actor.get("now", 0))
	phase = PHASE_DIAL
	return _ok([{"type": "phase", "phase": phase}, {"type": "theme"}])


func _reveal(events: Array) -> Array:
	var dist := absf(dial - target)
	var pts := points_for(dist)
	last = {"points": pts, "side_points": 0, "bonus": false, "catch_up": false, "dist": dist}
	var entry := {"team": turn_team, "psychic": psychic, "theme": theme.duplicate(), "target": target, "dial": dial, "points": pts, "side": side, "side_points": 0}
	if config.mode == MODE_COOP:
		# Centro vale 3 e ganha uma rodada extra (oficial).
		if pts == 4:
			pts = 3
			last.bonus = true
			cards_left += 1
		last.points = pts
		entry.points = pts
		coop_score += pts
		cards_left -= 1
		if cards_left <= 0:
			winner = "coop"
	else:
		scores[turn_team] += pts
		# Aposta do outro time: 1 ponto se acertou o lado, menos quando a agulha caiu no centro.
		var right_side := (side == "left" and target < dial) or (side == "right" and target > dial)
		if pts < 4 and right_side:
			last.side_points = 1
			entry.side_points = 1
			scores[other(turn_team)] += 1
		_after_times_round()
	rounds.append(entry)
	phase = PHASE_REVEAL
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "revealed", "points": last.points, "side_points": last.side_points, "bonus": last.bonus})
	return events


## Fim da rodada no modo times: quem venceu, morte súbita e recuperação (§3.2).
func _after_times_round() -> void:
	var a: int = scores.azul
	var b: int = scores.vermelho
	if sudden:
		sudden_rounds += 1
		if sudden_rounds % 2 == 0 and a != b:
			winner = "azul" if a > b else "vermelho"
			return
	elif maxi(a, b) >= WIN_AT:
		if a != b:
			winner = "azul" if a > b else "vermelho"
			return
		sudden = true
		sudden_rounds = 0
	# Recuperação: fez 4 e continua perdendo, joga de novo (outra pessoa dá a dica).
	if not sudden and last.points == 4 and scores[turn_team] < scores[other(turn_team)]:
		last.catch_up = true
		return
	turn_team = other(turn_team)


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
