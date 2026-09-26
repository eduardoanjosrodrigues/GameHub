class_name ShRules
extends RefCounted
## Regras do Secret Hitler como máquina de estados pura (docs/PLANO_SECRET_HITLER.md §3).
##
## Não conhece tela nem rede. O host é o único que roda esta classe.
## Ator de uma ação: {"id": String, "host": bool, "board": bool, "now": int (ms, só pro cronômetro)}.

const MIN_PLAYERS := 5
const MAX_PLAYERS := 10
const TIMER_RANGE := Vector2i(0, 5) # minutos; 0 = desligado
const LIBERAL_TO_WIN := 5
const FASCIST_TO_WIN := 6
const HITLER_ZONE := 3 # a partir de 3 leis fascistas, Hitler chanceler vence
const VETO_AT := 5
const CHAOS_AT := 3
const DECK := {"L": 6, "F": 11}

## jogadores -> fascistas sem contar o Hitler (§3.1)
const FASCISTS := {5: 1, 6: 1, 7: 2, 8: 2, 9: 3, 10: 3}
## Poderes por casa da lei fascista (§3.5): faixa de jogadores -> {casa: poder}
const POWERS_5_6 := {3: "peek", 4: "execution", 5: "execution"}
const POWERS_7_8 := {2: "investigate", 3: "special_election", 4: "execution", 5: "execution"}
const POWERS_9_10 := {1: "investigate", 2: "investigate", 3: "special_election", 4: "execution", 5: "execution"}

const PHASE_LOBBY := "lobby"
const PHASE_REVEAL := "reveal" # cada um vê o seu papel
const PHASE_NOMINATE := "nominate" # presidente indica o chanceler
const PHASE_VOTE := "vote"
const PHASE_VOTE_RESULT := "vote_result"
const PHASE_LEG_PRESIDENT := "leg_president" # presidente descarta 1 de 3
const PHASE_LEG_CHANCELLOR := "leg_chancellor" # chanceler aprova 1 de 2 (ou pede veto)
const PHASE_VETO := "veto" # presidente aceita ou recusa o veto
const PHASE_POLICY := "policy" # a lei aprovada (ou o veto, ou o caos) aparece pra todos
const PHASE_POWER := "power" # presidente usa o poder
const PHASE_POWER_RESULT := "power_result"
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, alive}, na ordem da mesa.
var players: Array = []
var config := {"timer_min": 0}
var roles := {} # id -> "liberal" | "fascista" | "hitler"
var ready := {}
var deck: Array = [] # "L" / "F", o topo é o fim do array
var discard: Array = []
var liberal := 0
var fascist := 0
var tracker := 0 # eleições fracassadas seguidas
var president := "" # candidato a presidente (ou presidente eleito) desta rodada
var chancellor := "" # indicado / eleito
var last_president := "" # últimos eleitos (limite de mandato)
var last_chancellor := ""
var votes := {} # id -> bool (true = Ja)
var last_votes := {}
var hand: Array = [] # leis na mão do governo
var veto_refused := false
var last_policy := {} # {policy, chaos, vetoed}
var power := "" # poder pendente desta rodada
var power_target := ""
var peek: Array = []
var investigated: Array = []
var investigations := {} # presidente -> [{id, party}]
var not_hitler: Array = [] # chanceleres eleitos com 3+ fascistas que não eram o Hitler
var special_next := "" # eleição especial: quem é o próximo candidato
var round_since := 0 # ms do host em que a indicação começou (cronômetro)
var history: Array = [] # rodadas: {president, chancellor, votes, elected, drawn, discarded_p, passed, policy, chaos, vetoed}
var winner := "" # "liberal" / "fascista"
var win_reason := ""
var rng := RandomNumberGenerator.new()

var _rot := -1 # índice do último presidente na ordem normal
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


func alive() -> Array:
	return players.filter(func(p): return p.alive)


func is_alive(id: String) -> bool:
	var p := player(id)
	return not p.is_empty() and p.alive


## Partido que aparece na investigação: o Hitler aparece como fascista.
func party(id: String) -> String:
	return "liberal" if roles.get(id, "") == "liberal" else "fascista"


func fascist_count() -> int:
	return int(FASCISTS.get(players.size(), 0))


func powers() -> Dictionary:
	var n := players.size()
	if n <= 6:
		return POWERS_5_6
	if n <= 8:
		return POWERS_7_8
	return POWERS_9_10


func veto_unlocked() -> bool:
	return fascist >= VETO_AT


## Quem o presidente pode indicar (§3.4 passo 2).
func eligible_chancellors() -> Array:
	var out: Array = []
	var few := alive().size() <= 5
	for p in alive():
		if p.id == president or p.id == last_chancellor:
			continue
		if p.id == last_president and not few:
			continue
		out.append(p.id)
	return out


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
	players.append({"id": id, "name": n, "color": _next_color, "connected": true, "alive": true})
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
		return _err("Só o host configura a partida.")
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
		_first_round(int(actor.get("now", 0)))
		return _ok([{"type": "phase", "phase": phase}])
	return _ok([{"type": "ready", "id": id}])


func _a_nominate(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_NOMINATE:
		return _err("Não é hora de indicar.")
	if actor.get("id", "") != president:
		return _err("Só o presidente indica o chanceler.")
	var id: String = a.get("id", "")
	if id not in eligible_chancellors():
		return _err("Essa pessoa não pode ser chanceler agora.")
	chancellor = id
	phase = PHASE_VOTE
	votes = {}
	return _ok([{"type": "phase", "phase": phase}, {"type": "nominated", "president": president, "chancellor": id}])


func _a_vote(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_VOTE:
		return _err("Não é hora de votar.")
	var id: String = actor.get("id", "")
	if not is_alive(id):
		return _err("Só quem está vivo vota.")
	votes[id] = bool(a.get("ja", false))
	var living := alive().size()
	if votes.size() < living:
		return _ok([{"type": "voted", "id": id}])
	var yes := votes.values().filter(func(x): return x).size()
	var elected := yes * 2 > living
	last_votes = votes.duplicate()
	history.append({"president": president, "chancellor": chancellor, "votes": last_votes.duplicate(), "elected": elected})
	var events: Array = [{"type": "vote_result", "elected": elected, "yes": yes}]
	if elected:
		last_president = president
		last_chancellor = chancellor
		if fascist >= HITLER_ZONE:
			if roles.get(chancellor, "") == "hitler":
				return _finish("fascista", "hitler_chancellor", events)
			if chancellor not in not_hitler:
				not_hitler.append(chancellor)
				events.append({"type": "not_hitler", "id": chancellor})
	else:
		tracker += 1
	phase = PHASE_VOTE_RESULT
	return _ok(events)


func _a_discard(actor: Dictionary, a: Dictionary) -> Dictionary:
	var i := int(a.get("index", -1))
	match phase:
		PHASE_LEG_PRESIDENT:
			if actor.get("id", "") != president:
				return _err("Só o presidente descarta agora.")
			if i < 0 or i >= hand.size():
				return _err("Escolha uma das leis.")
			var card: String = hand[i]
			hand.remove_at(i)
			discard.append(card)
			history.back().discarded_p = card
			history.back().passed = hand.duplicate()
			phase = PHASE_LEG_CHANCELLOR
			veto_refused = false
			return _ok([{"type": "phase", "phase": phase}])
	return _err("Não é hora de descartar.")


## O chanceler aprova a lei hand[index] (a outra vai pro descarte).
func _a_enact(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LEG_CHANCELLOR:
		return _err("Não é hora de aprovar lei.")
	if actor.get("id", "") != chancellor:
		return _err("Só o chanceler aprova a lei.")
	var i := int(a.get("index", -1))
	if i < 0 or i >= hand.size():
		return _err("Escolha uma das leis.")
	var card: String = hand[i]
	hand.remove_at(i)
	discard.append_array(hand)
	hand = []
	return _enact(card, false)


func _a_veto(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_LEG_CHANCELLOR:
		return _err("Não é hora de veto.")
	if actor.get("id", "") != chancellor:
		return _err("Só o chanceler pede veto.")
	if not veto_unlocked():
		return _err("O veto só vale depois de %d leis fascistas." % VETO_AT)
	if veto_refused:
		return _err("O presidente já recusou o veto.")
	phase = PHASE_VETO
	return _ok([{"type": "phase", "phase": phase}, {"type": "veto_asked"}])


func _a_veto_answer(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_VETO:
		return _err("Não é hora de veto.")
	if actor.get("id", "") != president:
		return _err("Só o presidente responde o veto.")
	if not bool(a.get("accept", false)):
		veto_refused = true
		phase = PHASE_LEG_CHANCELLOR
		return _ok([{"type": "phase", "phase": phase}, {"type": "veto_refused"}])
	discard.append_array(hand)
	hand = []
	history.back().vetoed = true
	tracker += 1
	last_policy = {"policy": "", "chaos": false, "vetoed": true}
	power = ""
	_ensure_deck()
	phase = PHASE_POLICY
	return _ok([{"type": "phase", "phase": phase}, {"type": "vetoed"}])


func _a_power(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_POWER:
		return _err("Não é hora de poder.")
	if actor.get("id", "") != president:
		return _err("Só o presidente usa o poder.")
	var target: String = a.get("id", "")
	var events: Array = []
	match power:
		"peek":
			target = ""
		"investigate":
			if not is_alive(target) or target == president or target in investigated:
				return _err("Escolha alguém vivo que ainda não foi investigado.")
			investigated.append(target)
			var seen: Array = investigations.get(president, [])
			seen.append({"id": target, "party": party(target)})
			investigations[president] = seen
		"special_election":
			if not is_alive(target) or target == president:
				return _err("Escolha outra pessoa viva.")
			special_next = target
		"execution":
			if not is_alive(target) or target == president:
				return _err("Escolha outra pessoa viva.")
			player(target).alive = false
			events.append({"type": "executed", "id": target})
			if roles.get(target, "") == "hitler":
				power_target = target
				return _finish("liberal", "hitler_executed", events)
		_:
			return _err("Nenhum poder agora.")
	power_target = target
	phase = PHASE_POWER_RESULT
	events.push_front({"type": "phase", "phase": phase})
	events.append({"type": "power_used", "power": power, "president": president, "target": target})
	return _ok(events)


## Depois de um resultado (voto, lei ou poder): segue o jogo.
func _a_continue(actor: Dictionary, _a: Dictionary) -> Dictionary:
	var now := int(actor.get("now", 0))
	if not (actor.get("host", false) or actor.get("board", false) or actor.get("id", "") == president):
		return _err("Quem segue é o presidente, o host ou o tabuleiro.")
	match phase:
		PHASE_VOTE_RESULT:
			if history.back().elected:
				_draw_hand()
				phase = PHASE_LEG_PRESIDENT
				return _ok([{"type": "phase", "phase": phase}])
			if tracker >= CHAOS_AT:
				return _chaos()
			_next_round(now)
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_POLICY:
			if power != "":
				phase = PHASE_POWER
				power_target = ""
				peek = deck.slice(maxi(0, deck.size() - 3)) if power == "peek" else []
				peek.reverse() # do topo pra baixo
				return _ok([{"type": "phase", "phase": phase}])
			if tracker >= CHAOS_AT:
				return _chaos()
			_next_round(now)
			return _ok([{"type": "phase", "phase": phase}])
		PHASE_POWER_RESULT:
			_next_round(now)
			return _ok([{"type": "phase", "phase": phase}])
	return _err("Nada pra seguir agora.")


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
		"fascist_count": fascist_count(),
		"liberal": liberal,
		"fascist": fascist,
		"tracker": tracker,
		"deck_count": deck.size(),
		"discard_count": discard.size(),
		"powers": powers(),
		"veto_unlocked": veto_unlocked(),
		"president": president,
		"chancellor": chancellor,
		"last_president": last_president,
		"last_chancellor": last_chancellor,
		"eligible": eligible_chancellors() if phase == PHASE_NOMINATE else [],
		"voted": votes.keys() if phase == PHASE_VOTE else [],
		"ready": ready.keys(),
		"last_votes": last_votes.duplicate(),
		"last_policy": last_policy.duplicate(),
		"power": power if phase in [PHASE_POLICY, PHASE_POWER, PHASE_POWER_RESULT, PHASE_GAME_OVER] else "",
		"power_target": power_target,
		"investigated": investigated.duplicate(),
		"not_hitler": not_hitler.duplicate(),
		"veto_refused": veto_refused,
		"timer_left_ms": maxi(0, int(config.timer_min) * 60000 - (now - round_since)) if phase == PHASE_NOMINATE and int(config.timer_min) > 0 else -1,
		"winner": winner,
		"win_reason": win_reason,
		"role": "",
		"party": "",
		"alive": true,
		"knows": [],
		"my_vote": null,
		"hand": [],
		"peek": [],
		"investigations": [],
		"all_roles": roles.duplicate() if over else {},
		# O que cada governo recebeu e descartou só aparece no fim (§3.7).
		"history": _public_history(over),
	}
	var me := player(you)
	if not me.is_empty():
		v.alive = me.alive
	if roles.has(you):
		v.role = roles[you]
		v.party = party(you)
		v.knows = _knowledge(you)
		if votes.has(you):
			v.my_vote = votes[you]
		if (phase == PHASE_LEG_PRESIDENT and you == president) or (phase in [PHASE_LEG_CHANCELLOR, PHASE_VETO] and you == chancellor):
			v.hand = hand.duplicate()
		if phase == PHASE_POWER and power == "peek" and you == president:
			v.peek = peek.duplicate()
		v.investigations = investigations.get(you, []).duplicate(true)
	return v


func _public_history(over: bool) -> Array:
	var out: Array = []
	for h in history:
		var e: Dictionary = h.duplicate(true)
		if not over:
			for k in ["drawn", "discarded_p", "passed"]:
				e.erase(k)
		out.append(e)
	return out


## O que cada papel sabe no começo (§3.2): [{id, tag}], tag "fascista" ou "hitler".
func _knowledge(id: String) -> Array:
	var r: String = roles.get(id, "")
	var out: Array = []
	if r == "liberal" or (r == "hitler" and players.size() > 6):
		return out
	for p in players:
		if p.id == id:
			continue
		var other: String = roles.get(p.id, "")
		if other == "fascista" or other == "hitler":
			out.append({"id": p.id, "tag": other})
	return out


# --- Internos --------------------------------------------------------------

func _deal() -> void:
	var n := players.size()
	var f := fascist_count()
	var list: Array = ["hitler"]
	for i in f:
		list.append("fascista")
	while list.size() < n:
		list.append("liberal")
	_shuffle(list)
	roles = {}
	for i in n:
		roles[players[i].id] = list[i]
		players[i].alive = true
	deck = []
	for k in DECK:
		for i in DECK[k]:
			deck.append(k)
	_shuffle(deck)
	discard = []
	liberal = 0
	fascist = 0
	tracker = 0
	president = ""
	chancellor = ""
	last_president = ""
	last_chancellor = ""
	votes = {}
	last_votes = {}
	hand = []
	veto_refused = false
	last_policy = {}
	power = ""
	power_target = ""
	peek = []
	investigated = []
	investigations = {}
	not_hitler = []
	special_next = ""
	history = []
	winner = ""
	win_reason = ""
	ready = {}
	phase = PHASE_REVEAL
	_rot = rng.randi_range(0, n - 1)


func _first_round(now: int) -> void:
	president = players[_rot].id
	_begin_nominate(now)


func _next_round(now: int) -> void:
	if special_next != "":
		president = special_next
		special_next = ""
	else:
		_rot = _next_alive(_rot)
		president = players[_rot].id
	_begin_nominate(now)


func _next_alive(from: int) -> int:
	var n := players.size()
	var i := from
	for k in n:
		i = (i + 1) % n
		if players[i].alive:
			return i
	return from


func _begin_nominate(now: int) -> void:
	phase = PHASE_NOMINATE
	chancellor = ""
	votes = {}
	hand = []
	power = ""
	power_target = ""
	peek = []
	veto_refused = false
	round_since = now


func _draw_hand() -> void:
	_ensure_deck()
	hand = []
	for i in 3:
		hand.append(deck.pop_back())
	history.back().drawn = hand.duplicate()


## Menos de 3 no baralho: o descarte volta e tudo é embaralhado (§3.3).
func _ensure_deck() -> void:
	if deck.size() >= 3:
		return
	deck.append_array(discard)
	discard = []
	_shuffle(deck)


func _enact(card: String, chaos: bool) -> Dictionary:
	if card == "L":
		liberal += 1
	else:
		fascist += 1
	tracker = 0
	last_policy = {"policy": card, "chaos": chaos, "vetoed": false}
	if not history.is_empty() and not chaos:
		history.back().policy = card
	var events: Array = [{"type": "policy", "policy": card, "chaos": chaos}]
	if liberal >= LIBERAL_TO_WIN:
		return _finish("liberal", "liberal_policies", events)
	if fascist >= FASCIST_TO_WIN:
		return _finish("fascista", "fascist_policies", events)
	power = "" if chaos or card == "L" else str(powers().get(fascist, ""))
	_ensure_deck()
	phase = PHASE_POLICY
	events.push_front({"type": "phase", "phase": phase})
	return _ok(events)


## Três eleições fracassadas: a lei do topo entra sem poder e os limites de mandato somem.
func _chaos() -> Dictionary:
	_ensure_deck()
	var card: String = deck.pop_back()
	history.append({"president": "", "chancellor": "", "votes": {}, "elected": false, "chaos": true, "policy": card})
	last_president = ""
	last_chancellor = ""
	return _enact(card, true)


func _finish(side: String, reason: String, events: Array = []) -> Dictionary:
	winner = side
	win_reason = reason
	phase = PHASE_GAME_OVER
	events.append({"type": "game_over", "winner": side, "reason": reason})
	return _ok(events)


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
