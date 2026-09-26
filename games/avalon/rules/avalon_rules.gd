class_name AvalonRules
extends RefCounted
## Regras do Avalon como máquina de estados pura (docs/PLANO_AVALON.md §3).
##
## Não conhece tela nem rede. O host é o único que roda esta classe.
## Ator de uma ação: {"id": String, "host": bool, "board": bool, "now": int (ms, só pro cronômetro)}.

const MIN_PLAYERS := 5
const MAX_PLAYERS := 10
const MAX_REJECTS := 5
const TIMER_RANGE := Vector2i(0, 5) # minutos; 0 = desligado

## jogadores -> [maus, tamanhos das 5 missões]
const TABLE := {
	5: [2, [2, 3, 2, 3, 3]],
	6: [2, [2, 3, 4, 3, 4]],
	7: [3, [2, 3, 3, 4, 4]],
	8: [3, [3, 4, 4, 5, 5]],
	9: [3, [3, 4, 4, 5, 5]],
	10: [4, [3, 4, 4, 5, 5]],
}
const EVIL := ["assassino", "morgana", "mordred", "oberon", "lacaio"]
## Personagens que o host liga ou desliga (os outros lugares viram servo ou lacaio).
const SPECIALS := ["merlin", "assassino", "percival", "morgana", "mordred", "oberon"]
const EVIL_SPECIALS := ["assassino", "morgana", "mordred", "oberon"]

const PHASE_LOBBY := "lobby"
const PHASE_REVEAL := "reveal" # cada um vê o seu papel
const PHASE_TEAM := "team" # líder monta o time
const PHASE_VOTE := "vote"
const PHASE_VOTE_RESULT := "vote_result"
const PHASE_QUEST := "quest"
const PHASE_QUEST_RESULT := "quest_result"
const PHASE_LADY := "lady"
const PHASE_ASSASSIN := "assassin"
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected}, na ordem da mesa.
var players: Array = []
var config := {"roles": ["merlin", "assassino"], "lady": false, "timer_min": 0}
var roles := {} # id -> papel
var leader := 0 # índice em players
var quest := 0 # 0..4
var results: Array = [] # "ok" / "fail" por missão jogada
var quest_fails: Array = [] # falhas de cada missão jogada
var rejects := 0
var team: Array = [] # ids
var votes := {} # id -> bool (true = aprovar)
var cards := {} # id -> bool (true = sucesso)
var ready := {} # id -> true (já viu o papel)
var last_votes := {}
var last_quest := {} # {fails, cards: Array[bool] embaralhadas, ok}
var lady := "" # quem está com a Dama
var lady_used: Array = [] # quem já teve a Dama (não pode ser examinado)
var lady_seen := {} # dono -> [{id, evil}] o que cada um já viu com a Dama
var lady_pending := {} # {holder, target, evil} esperando o dono continuar
var history: Array = [] # [{quest, leader, team, votes, approved}]
var team_since := 0 # ms do host em que o líder começou a montar o time
var winner := "" # "bem" / "mal"
var win_reason := ""
var assassin_target := ""
var rng := RandomNumberGenerator.new()

var _next_local_id := 1
var _next_color := 0


func _init(seed_value := -1) -> void:
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


func is_evil(id: String) -> bool:
	return roles.get(id, "") in EVIL


func evil_count() -> int:
	return int(TABLE.get(players.size(), [0, []])[0])


func quest_sizes() -> Array:
	return TABLE.get(players.size(), [0, [0, 0, 0, 0, 0]])[1]


func fails_needed(q: int) -> int:
	return 2 if q == 3 and players.size() >= 7 else 1


func leader_id() -> String:
	return players[leader].id if leader < players.size() else ""


func lady_on() -> bool:
	return config.lady and players.size() >= 7


func can_start() -> String:
	## Retorna "" se dá pra começar, senão o motivo.
	var n := players.size()
	if n < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	var evil_specials: Array = config.roles.filter(func(r): return r in EVIL_SPECIALS)
	if evil_specials.size() > evil_count():
		return "Com %d jogadores só existem %d do mal: tire algum personagem do mal." % [n, evil_count()]
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


## a.roles: lista de personagens ligados; a.lady: bool; a.timer_min: int.
## Dependências (§3.2): Assassino anda junto com Merlin; Percival precisa de Merlin; Morgana precisa de Percival.
func _a_set_config(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host configura a partida.")
	if a.has("toggle"):
		var r: String = a.toggle
		if r not in SPECIALS:
			return _err("Personagem inválido.")
		var list: Array = config.roles.duplicate()
		if r in list:
			list.erase(r)
			match r:
				"merlin", "assassino":
					for x in ["merlin", "assassino", "percival", "morgana"]:
						list.erase(x)
				"percival":
					list.erase("morgana")
		else:
			list.append(r)
			match r:
				"merlin", "assassino":
					for x in ["merlin", "assassino"]:
						if x not in list:
							list.append(x)
				"percival":
					for x in ["merlin", "assassino"]:
						if x not in list:
							list.append(x)
				"morgana":
					for x in ["merlin", "assassino", "percival"]:
						if x not in list:
							list.append(x)
		config.roles = SPECIALS.filter(func(x): return x in list)
	if a.has("lady"):
		config.lady = bool(a.lady)
	if a.has("timer_min"):
		config.timer_min = clampi(int(a.timer_min), TIMER_RANGE.x, TIMER_RANGE.y)
	return _ok()


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LOBBY and phase != PHASE_GAME_OVER:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	_deal()
	return _ok([{"type": "phase", "phase": phase}])


func _a_rematch(actor: Dictionary, a: Dictionary) -> Dictionary:
	return _a_start(actor, a)


func _a_ready(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_REVEAL:
		return _err("Não é hora disso.")
	var id: String = actor.get("id", "")
	if player(id).is_empty():
		return _err("Jogador não encontrado.")
	ready[id] = true
	if ready.size() >= players.size():
		_begin_team(int(actor.get("now", 0)))
		return _ok([{"type": "phase", "phase": phase}])
	return _ok([{"type": "ready", "id": id}])


## O líder marca e desmarca gente (todo mundo vê ao vivo). a.ids = lista completa.
func _a_select_team(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_TEAM:
		return _err("Não é hora de montar o time.")
	if actor.get("id", "") != leader_id():
		return _err("Só o líder monta o time.")
	var ids: Array = []
	for id in a.get("ids", []):
		if not player(str(id)).is_empty() and str(id) not in ids:
			ids.append(str(id))
	if ids.size() > quest_sizes()[quest]:
		return _err("Essa missão leva %d pessoas." % quest_sizes()[quest])
	team = ids
	return _ok()


func _a_propose(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_TEAM:
		return _err("Não é hora de montar o time.")
	if actor.get("id", "") != leader_id():
		return _err("Só o líder envia o time.")
	var need: int = quest_sizes()[quest]
	if team.size() != need:
		return _err("Escolha %d pessoas pra missão." % need)
	phase = PHASE_VOTE
	votes = {}
	return _ok([{"type": "phase", "phase": phase}])


func _a_vote(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_VOTE:
		return _err("Não é hora de votar.")
	var id: String = actor.get("id", "")
	if player(id).is_empty():
		return _err("Só quem joga vota.")
	votes[id] = bool(a.get("approve", false))
	if votes.size() < players.size():
		return _ok([{"type": "voted", "id": id}])
	var yes := votes.values().filter(func(x): return x).size()
	var approved := yes * 2 > players.size()
	last_votes = votes.duplicate()
	history.append({"quest": quest, "leader": leader_id(), "team": team.duplicate(), "votes": last_votes.duplicate(), "approved": approved})
	if not approved:
		rejects += 1
	phase = PHASE_VOTE_RESULT
	return _ok([{"type": "vote_result", "approved": approved, "yes": yes}])


func _a_quest_card(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_QUEST:
		return _err("Não é hora da missão.")
	var id: String = actor.get("id", "")
	if id not in team:
		return _err("Você não está no time da missão.")
	if cards.has(id):
		return _err("Você já jogou sua carta.")
	var success := bool(a.get("success", true))
	if not success and not is_evil(id):
		return _err("Os servos leais de Arthur só podem jogar Sucesso.")
	cards[id] = success
	if cards.size() < team.size():
		return _ok([{"type": "played", "id": id}])
	var list: Array = cards.values()
	_shuffle(list)
	var fails := list.filter(func(x): return not x).size()
	var ok := fails < fails_needed(quest)
	results.append("ok" if ok else "fail")
	quest_fails.append(fails)
	last_quest = {"fails": fails, "cards": list, "ok": ok, "quest": quest}
	phase = PHASE_QUEST_RESULT
	return _ok([{"type": "quest_result", "ok": ok, "fails": fails}])


## Depois de um resultado (voto, missão ou Dama): segue o jogo.
func _a_continue(actor: Dictionary, _a: Dictionary) -> Dictionary:
	var now := int(actor.get("now", 0))
	var allowed: bool = actor.get("host", false) or actor.get("board", false) or actor.get("id", "") == leader_id()
	match phase:
		PHASE_VOTE_RESULT:
			if not allowed:
				return _err("Quem segue é o líder, o host ou o tabuleiro.")
			var approved: bool = history.back().approved
			if approved:
				rejects = 0
				phase = PHASE_QUEST
				cards = {}
				return _ok([{"type": "phase", "phase": phase}])
			if rejects >= MAX_REJECTS:
				return _finish("mal", "rejects")
			_next_leader()
			_begin_team(now)
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_QUEST_RESULT:
			if not allowed:
				return _err("Quem segue é o líder, o host ou o tabuleiro.")
			var ok_count := results.filter(func(r): return r == "ok").size()
			var fail_count := results.size() - ok_count
			if fail_count >= 3:
				return _finish("mal", "quests")
			if ok_count >= 3:
				if "merlin" in roles.values():
					phase = PHASE_ASSASSIN
					return _ok([{"type": "phase", "phase": phase}])
				return _finish("bem", "quests")
			if lady_on() and quest in [1, 2, 3]:
				phase = PHASE_LADY
				lady_pending = {}
				return _ok([{"type": "phase", "phase": phase}])
			_next_quest(now)
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_LADY:
			if lady_pending.is_empty():
				return _err("Quem está com a Dama ainda não escolheu.")
			if actor.get("id", "") != lady and not actor.get("host", false) and not actor.get("board", false):
				return _err("Quem segue é quem está com a Dama.")
			lady = lady_pending.target
			lady_used.append(lady)
			lady_pending = {}
			_next_quest(now)
			return _ok([{"type": "phase", "phase": phase}])
	return _err("Nada pra seguir agora.")


func _a_lady_examine(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LADY or not lady_pending.is_empty():
		return _err("Não é hora da Dama do Lago.")
	if actor.get("id", "") != lady:
		return _err("Só quem está com a Dama examina.")
	var target: String = a.get("id", "")
	if player(target).is_empty() or target == lady or target in lady_used:
		return _err("Escolha alguém que ainda não teve a Dama.")
	var seen: Array = lady_seen.get(lady, [])
	seen.append({"id": target, "evil": is_evil(target)})
	lady_seen[lady] = seen
	lady_pending = {"holder": lady, "target": target}
	return _ok([{"type": "lady_examined", "holder": lady, "target": target}])


func _a_assassinate(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_ASSASSIN:
		return _err("Não é hora do assassinato.")
	if roles.get(actor.get("id", ""), "") != "assassino":
		return _err("Só o Assassino escolhe.")
	var target: String = a.get("id", "")
	if player(target).is_empty() or is_evil(target):
		return _err("Escolha alguém do bem.")
	assassin_target = target
	if roles[target] == "merlin":
		return _finish("mal", "assassin_hit")
	return _finish("bem", "assassin_miss")


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	return [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]


# --- Visão (o que cada aparelho pode ver) ---------------------------------

## viewer: {"id": String, "role": "player" | "board"}. now: ms do host, pro cronômetro.
func view_for(viewer: Dictionary, now := 0) -> Dictionary:
	var you: String = viewer.get("id", "")
	var over := phase == PHASE_GAME_OVER
	var v := {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": players.duplicate(true),
		"config": config.duplicate(true),
		"can_start": can_start(),
		"evil_count": evil_count(),
		"quest_sizes": quest_sizes(),
		"two_fails": players.size() >= 7,
		"quest": quest,
		"results": results.duplicate(),
		"quest_fails": quest_fails.duplicate(),
		"rejects": rejects,
		"leader": leader_id(),
		"team": team.duplicate(),
		"voted": votes.keys() if phase == PHASE_VOTE else [],
		"played": cards.keys() if phase == PHASE_QUEST else [],
		"ready": ready.keys(),
		"last_votes": last_votes.duplicate(),
		"last_quest": last_quest.duplicate(true),
		"history": history.duplicate(true),
		"lady_on": lady_on(),
		"lady": lady,
		"lady_used": lady_used.duplicate(),
		"lady_target": lady_pending.get("target", ""),
		"timer_left_ms": maxi(0, int(config.timer_min) * 60000 - (now - team_since)) if phase == PHASE_TEAM and int(config.timer_min) > 0 else -1,
		"winner": winner,
		"win_reason": win_reason,
		"assassin_target": assassin_target,
		"role": "",
		"evil": false,
		"knows": [],
		"my_vote": null,
		"my_card": null,
		"lady_seen": [],
		"all_roles": roles.duplicate() if over else {},
		"evil_team": [],
	}
	if roles.has(you):
		var r: String = roles[you]
		v.role = r
		v.evil = r in EVIL
		v.knows = _knowledge(you)
		if votes.has(you):
			v.my_vote = votes[you]
		if cards.has(you):
			v.my_card = cards[you]
		v.lady_seen = lady_seen.get(you, []).duplicate(true)
		# No assassinato os maus se revelam entre si, inclusive Oberon.
		if phase == PHASE_ASSASSIN and v.evil:
			v.evil_team = players.filter(func(p): return is_evil(p.id)).map(func(p): return {"id": p.id, "role": roles[p.id]})
	return v


## O que cada papel sabe no começo (§3.2): [{id, tag}], tag "mal" ou "merlin?".
func _knowledge(id: String) -> Array:
	var r: String = roles.get(id, "")
	var out: Array = []
	for p in players:
		if p.id == id:
			continue
		var other: String = roles.get(p.id, "")
		match r:
			"merlin":
				if other in EVIL and other != "mordred":
					out.append({"id": p.id, "tag": "mal"})
			"percival":
				if other in ["merlin", "morgana"]:
					out.append({"id": p.id, "tag": "merlin?"})
			"assassino", "morgana", "mordred", "lacaio":
				if other in EVIL and other != "oberon":
					out.append({"id": p.id, "tag": "mal"})
	return out


# --- Internos --------------------------------------------------------------

func _deal() -> void:
	var n := players.size()
	var evil := evil_count()
	var specials: Array = config.roles.duplicate()
	var good_roles: Array = specials.filter(func(r): return r not in EVIL_SPECIALS)
	var evil_roles: Array = specials.filter(func(r): return r in EVIL_SPECIALS)
	while evil_roles.size() < evil:
		evil_roles.append("lacaio")
	while good_roles.size() < n - evil:
		good_roles.append("servo")
	var deck: Array = good_roles + evil_roles
	_shuffle(deck)
	roles = {}
	for i in n:
		roles[players[i].id] = deck[i]
	phase = PHASE_REVEAL
	ready = {}
	quest = 0
	results = []
	quest_fails = []
	rejects = 0
	team = []
	votes = {}
	cards = {}
	last_votes = {}
	last_quest = {}
	history = []
	winner = ""
	win_reason = ""
	assassin_target = ""
	lady_used = []
	lady_seen = {}
	lady_pending = {}
	leader = rng.randi_range(0, n - 1)
	lady = ""
	if lady_on():
		# A Dama começa com quem está à direita do primeiro líder (o anterior na ordem).
		lady = players[(leader - 1 + n) % n].id
		lady_used = [lady]


func _begin_team(now: int) -> void:
	phase = PHASE_TEAM
	team = []
	votes = {}
	team_since = now


func _next_leader() -> void:
	leader = (leader + 1) % players.size()


func _next_quest(now: int) -> void:
	quest += 1
	_next_leader()
	_begin_team(now)


func _finish(side: String, reason: String) -> Dictionary:
	winner = side
	win_reason = reason
	phase = PHASE_GAME_OVER
	return _ok([{"type": "game_over", "winner": side, "reason": reason}])


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
