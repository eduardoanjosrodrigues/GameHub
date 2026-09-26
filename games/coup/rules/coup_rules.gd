class_name CoupRules
extends RefCounted
## Regras do Coup (base + variante do Inquisidor) como máquina de estados pura (docs/PLANO_COUP.md §3).
##
## Na sua vez, a pessoa faz uma ação e pode dizer que tem qualquer personagem. Toda ação que dá pra
## desafiar ou bloquear abre uma janela de 5 s (§3.4): quem reage primeiro (pela hora do host,
## resolve_timed) vale. Bloqueio: todos podem desafiar; só o "Aceitar" de quem foi bloqueado encerra.
## Ator de uma ação: {"id", "host", "board", "now"}.

const MIN_PLAYERS := 2
const MAX_PLAYERS := 6
const WINDOW_MS := 5000
const START_COINS := 2
const COUP_COST := 7
const ASSASSIN_COST := 3
const MUST_COUP := 10
const COPIES := 3
const LOG_MAX := 12

## Ações: personagem que alega, custo, precisa de alvo, abre janela, quem bloqueia e com o quê.
const ACTIONS := {
	"renda": {"claim": "", "cost": 0, "target": false, "window": false, "blockers": [], "block_by": ""},
	"ajuda": {"claim": "", "cost": 0, "target": false, "window": true, "blockers": ["duque"], "block_by": "anyone"},
	"golpe": {"claim": "", "cost": COUP_COST, "target": true, "window": false, "blockers": [], "block_by": ""},
	"imposto": {"claim": "duque", "cost": 0, "target": false, "window": true, "blockers": [], "block_by": ""},
	"assassinar": {"claim": "assassino", "cost": ASSASSIN_COST, "target": true, "window": true, "blockers": ["condessa"], "block_by": "target"},
	"extorquir": {"claim": "capitao", "cost": 0, "target": true, "window": true, "blockers": ["capitao", "QUINTO"], "block_by": "target"},
	"trocar": {"claim": "QUINTO", "cost": 0, "target": false, "window": true, "blockers": [], "block_by": ""},
	"examinar": {"claim": "inquisidor", "cost": 0, "target": true, "window": true, "blockers": [], "block_by": ""},
}

const PHASE_LOBBY := "lobby"
const PHASE_PICK_FIRST := "pick_first" # só com 2: cada um escolhe a primeira carta entre 5
const PHASE_TURN := "turn"
const PHASE_WINDOW := "window" # 5 s pra desafiar ou bloquear
const PHASE_BLOCK := "block" # alguém bloqueou: desafiar o bloqueio ou quem foi bloqueado aceita
const PHASE_LOSE := "lose" # alguém escolhe a carta que vira
const PHASE_EXCHANGE := "exchange"
const PHASE_EXAMINE_SHOW := "examine_show" # o alvo escolhe a carta que mostra
const PHASE_EXAMINE_DECIDE := "examine_decide" # o Inquisidor devolve ou obriga a trocar
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected}, na ordem da mesa.
var players: Array = []
## fifth: "embaixador" ou "inquisidor". window_ms: a janela de reação (5 s; os testes de rede usam menos).
var config := {"fifth": "embaixador", "window_ms": WINDOW_MS}
var cards := {} # id -> [{role, up}]
var coins := {} # id -> moedas
var deck: Array = []
var turn := ""
## A ação em andamento: {action, actor, target, claim, stage: "action" | "block_only", window_until,
## blocker, block_claim, accepted: [ids]}
var pending := {}
var losses: Array = [] # fila de quem perde influência: [id]
var loser := ""
var after := "" # o que acontece quando a fila de perdas esvaziar
var drawn: Array = [] # troca: as cartas compradas (só quem troca vê)
var shown := -1 # examinar: índice da carta que o alvo mostrou
var first_options := {} # 2 jogadores: id -> [5 personagens]
var first_pick := {} # 2 jogadores: id -> escolhido
var log: Array = [] # últimos acontecimentos, pra todos
var winner := ""
var clock := 0 # a última hora do host que as regras viram (pra abrir a janela do bloqueio)
var rng := RandomNumberGenerator.new()

var _next_color := 0


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# --- Consultas -------------------------------------------------------------

func roles() -> Array:
	return ["duque", "assassino", "capitao", config.fifth, "condessa"]


func player(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


func hidden(id: String) -> Array:
	return cards.get(id, []).filter(func(c): return not c.up)


func alive(id: String) -> bool:
	return not hidden(id).is_empty()


func alive_ids() -> Array:
	return players.filter(func(p): return alive(p.id)).map(func(p): return p.id)


func has_role(id: String, role: String) -> bool:
	return hidden(id).any(func(c): return c.role == role)


## A ação com o quinto personagem resolvido (Embaixador ou Inquisidor).
func spec(action: String) -> Dictionary:
	var s: Dictionary = ACTIONS.get(action, {}).duplicate(true)
	if s.is_empty():
		return s
	if s.claim == "QUINTO":
		s.claim = config.fifth
	s.blockers = s.blockers.map(func(b): return config.fifth if b == "QUINTO" else b)
	return s


func available_actions() -> Array:
	return ACTIONS.keys().filter(func(a): return a != "examinar" or config.fifth == "inquisidor")


func can_start() -> String:
	var n := players.size()
	if n < MIN_PLAYERS:
		return "São precisos pelo menos %d jogadores." % MIN_PLAYERS
	if n > MAX_PLAYERS:
		return "O máximo é %d jogadores." % MAX_PLAYERS
	return ""


## Quem pode bloquear a ação pendente, e com quais personagens.
func can_block(id: String) -> Array:
	if phase != PHASE_WINDOW or pending.is_empty() or id == pending.actor or not alive(id):
		return []
	var s := spec(pending.action)
	if s.blockers.is_empty():
		return []
	if s.block_by == "target" and id != pending.target:
		return []
	return s.blockers


func can_challenge(id: String) -> bool:
	if pending.is_empty() or not alive(id):
		return false
	if phase == PHASE_WINDOW:
		return pending.stage == "action" and pending.claim != "" and id != pending.actor
	if phase == PHASE_BLOCK:
		return id != pending.blocker
	return false


# --- Ações -----------------------------------------------------------------

func apply(actor: Dictionary, action: Dictionary) -> Dictionary:
	var type: String = action.get("type", "")
	clock = maxi(clock, int(actor.get("now", clock)))
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
	if a.has("window_ms"):
		config.window_ms = clampi(int(a.window_ms), 500, 15000)
	if a.has("fifth"):
		if a.fifth not in ["embaixador", "inquisidor"]:
			return _err("Personagem inválido.")
		config.fifth = a.fifth
	return _ok([{"type": "config"}])


func _a_start(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase not in [PHASE_LOBBY, PHASE_GAME_OVER]:
		return _err("A partida já começou.")
	if not actor.get("host", false):
		return _err("Só o host começa a partida.")
	var why := can_start()
	if why != "":
		return _err(why)
	cards = {}
	coins = {}
	pending = {}
	losses = []
	loser = ""
	drawn = []
	shown = -1
	log = []
	winner = ""
	turn = players[rng.randi_range(0, players.size() - 1)].id
	if players.size() == 2:
		# Regra oficial de 2: três conjuntos de 5; cada um escolhe 1 do seu, o terceiro vira mão e baralho.
		first_options = {}
		first_pick = {}
		for p in players:
			first_options[p.id] = roles()
			coins[p.id] = 1 if p.id == turn else START_COINS
		phase = PHASE_PICK_FIRST
		return _ok([{"type": "started"}, {"type": "phase", "phase": phase}])
	deck = []
	for r in roles():
		for k in COPIES:
			deck.append(r)
	_shuffle(deck)
	for p in players:
		cards[p.id] = [{"role": deck.pop_back(), "up": false}, {"role": deck.pop_back(), "up": false}]
		coins[p.id] = START_COINS
	phase = PHASE_TURN
	return _ok([{"type": "started"}, {"type": "phase", "phase": phase}, {"type": "turn", "id": turn}])


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


## 2 jogadores: escolher a primeira carta.
func _a_pick_first(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_PICK_FIRST:
		return _err("Não é hora de escolher.")
	var id: String = actor.get("id", "")
	var role := str(a.get("role", ""))
	if not first_options.has(id) or role not in first_options[id]:
		return _err("Escolha um dos seus personagens.")
	first_pick[id] = role
	if first_pick.size() < players.size():
		return _ok([{"type": "picked", "id": id}])
	var third: Array = roles()
	_shuffle(third)
	for p in players:
		cards[p.id] = [{"role": first_pick[p.id], "up": false}, {"role": third.pop_back(), "up": false}]
	deck = third
	first_options = {}
	phase = PHASE_TURN
	return _ok([{"type": "picked", "id": id}, {"type": "phase", "phase": phase}, {"type": "turn", "id": turn}])


## Na vez: {action, target}.
func _a_act(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_TURN:
		return _err("Não é hora de agir.")
	var id: String = actor.get("id", "")
	if id != turn:
		return _err("Não é a sua vez.")
	var action := str(a.get("action", ""))
	if action not in available_actions():
		return _err("Ação desconhecida.")
	var s := spec(action)
	if int(coins[id]) >= MUST_COUP and action != "golpe":
		return _err("Com %d moedas, o Golpe de Estado é obrigatório." % MUST_COUP)
	if int(coins[id]) < int(s.cost):
		return _err("Faltam moedas: custa %d." % int(s.cost))
	var target := str(a.get("target", ""))
	if s.target:
		if target == id or not alive(target):
			return _err("Escolha um alvo que ainda está no jogo.")
	else:
		target = ""
	coins[id] = int(coins[id]) - int(s.cost)
	var events: Array = [{"type": "declared", "id": id, "action": action, "target": target, "claim": s.claim}]
	_log({"k": "declared", "id": id, "action": action, "target": target, "claim": s.claim})
	match action:
		"renda":
			coins[id] = int(coins[id]) + 1
			return _ok(_end_turn(events))
		"golpe":
			pending = {"action": action, "actor": id, "target": target, "claim": ""}
			losses.append(target)
			after = "end_turn"
			return _ok(_continue(events))
	pending = {"action": action, "actor": id, "target": target, "claim": s.claim, "stage": "action",
		"window_until": clock + int(config.window_ms), "blocker": "", "block_claim": "", "accepted": []}
	phase = PHASE_WINDOW
	events.append({"type": "phase", "phase": phase})
	return _ok(events)


## No bloqueio, quem foi bloqueado aceita (a vez passa); o aceitar dos outros só avisa a mesa.
func _a_accept(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_BLOCK:
		return _err("Não tem bloqueio pra aceitar.")
	var id: String = actor.get("id", "")
	if id == pending.blocker or not alive(id):
		return _err("Você não aceita este bloqueio.")
	if id != pending.actor:
		if id not in pending.accepted:
			pending.accepted.append(id)
		return _ok([{"type": "accepted", "id": id}])
	var events: Array = [{"type": "block_accepted", "id": id}]
	_log({"k": "blocked", "id": pending.blocker, "role": pending.block_claim, "action": pending.action})
	return _ok(_end_turn(events))


## Quem perde influência escolhe qual carta vira.
func _a_lose(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_LOSE:
		return _err("Ninguém está perdendo influência.")
	var id: String = actor.get("id", "")
	if id != loser:
		return _err("Não é você quem perde agora.")
	var i := int(a.get("index", -1))
	var list: Array = cards[id]
	if i < 0 or i >= list.size() or list[i].up:
		return _err("Escolha uma das suas cartas viradas pra baixo.")
	return _ok(_continue(_reveal(id, i, [])))


## Trocar. Embaixador: {keep: [índices em cartas escondidas + compradas]}; Inquisidor: {swap: índice
## da carta escondida que sai, ou -1 pra devolver a comprada}.
func _a_exchange(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_EXCHANGE:
		return _err("Não é hora de trocar.")
	var id: String = actor.get("id", "")
	if id != pending.actor:
		return _err("Não é você quem troca.")
	var mine: Array = hidden(id).map(func(c): return c.role)
	if config.fifth == "embaixador":
		var pool: Array = mine + drawn
		var keep: Array = a.get("keep", [])
		var uniq := {}
		for k in keep:
			uniq[int(k)] = true
		if uniq.size() != mine.size() or uniq.keys().any(func(k): return k < 0 or k >= pool.size()):
			return _err("Escolha %d carta%s pra ficar." % [mine.size(), "" if mine.size() == 1 else "s"])
		var kept: Array = []
		for k in range(pool.size()):
			if uniq.has(k):
				kept.append(pool[k])
			else:
				deck.append(pool[k])
		_set_hidden(id, kept)
	else:
		var sw := int(a.get("swap", -1))
		if sw >= mine.size():
			return _err("Carta inválida.")
		if sw >= 0:
			deck.append(mine[sw])
			mine[sw] = drawn[0]
			_set_hidden(id, mine)
		else:
			deck.append(drawn[0])
	drawn = []
	_shuffle(deck)
	_log({"k": "exchanged", "id": id})
	return _ok(_end_turn([{"type": "exchanged", "id": id}]))


## Examinar: o alvo escolhe qual carta mostra (só o Inquisidor vê).
func _a_show(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_EXAMINE_SHOW:
		return _err("Não é hora de mostrar.")
	if actor.get("id", "") != pending.target:
		return _err("Não é você quem mostra.")
	var i := int(a.get("index", -1))
	var list: Array = cards[pending.target]
	if i < 0 or i >= list.size() or list[i].up:
		return _err("Escolha uma das suas cartas viradas pra baixo.")
	shown = i
	phase = PHASE_EXAMINE_DECIDE
	return _ok([{"type": "phase", "phase": phase}])


## Examinar: o Inquisidor devolve a carta ou obriga o alvo a trocá-la por outra do baralho.
func _a_examine(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_EXAMINE_DECIDE:
		return _err("Não é hora de decidir.")
	if actor.get("id", "") != pending.actor:
		return _err("Não é você quem examina.")
	var force := bool(a.get("force", false))
	if force:
		_replace(pending.target, shown)
	_log({"k": "examined", "id": pending.actor, "target": pending.target, "force": force})
	shown = -1
	return _ok(_end_turn([{"type": "examined", "id": pending.actor, "target": pending.target, "force": force}]))


## Reações que chegaram na janela do host (PartyClockHost): [{type: "challenge" | "block", player, t,
## role}]. Vale a mais cedo que ainda for válida.
func resolve_timed(list: Array, now: int) -> Dictionary:
	clock = maxi(clock, now)
	var sorted := list.duplicate()
	sorted.sort_custom(func(x, y): return int(x.t) < int(y.t))
	for r in sorted:
		var id: String = r.get("player", "")
		match r.get("type", ""):
			"challenge":
				if can_challenge(id) and (phase != PHASE_WINDOW or int(r.t) <= int(pending.window_until)):
					return _ok(_challenge(id, sorted.filter(func(x): return x.player != id)))
			"block":
				var role := str(r.get("role", ""))
				if role in can_block(id) and int(r.t) <= int(pending.window_until):
					return _ok(_block(id, role, sorted.filter(func(x): return x.player != id)))
	return _err("Tarde demais: não dá mais pra reagir." if not list.is_empty() else "")


## O host chama sempre: fecha a janela de 5 s.
func tick(now: int) -> Dictionary:
	clock = maxi(clock, now)
	if phase == PHASE_WINDOW and now >= int(pending.window_until):
		return _ok(_resolve([{"type": "window_closed"}]))
	return _ok()


func set_connected(id: String, connected: bool) -> Array:
	var p := player(id)
	if p.is_empty() or p.connected == connected:
		return []
	p.connected = connected
	return [{"type": "player_connection", "id": id, "connected": connected, "name": p.name}]


# --- Visão -----------------------------------------------------------------

## viewer: {"id", "role": "player" | "board"}. now: ms do host.
func view_for(viewer: Dictionary, now := 0) -> Dictionary:
	var you: String = viewer.get("id", "")
	var over := phase == PHASE_GAME_OVER
	var out_players: Array = []
	for p in players:
		var q: Dictionary = p.duplicate()
		q.coins = int(coins.get(p.id, 0))
		q.alive = alive(p.id) if phase != PHASE_PICK_FIRST else true
		# Cartas viradas pra cima todo mundo vê; as outras, só o dono (ou todo mundo no fim).
		q.cards = cards.get(p.id, []).map(func(c): return {"role": c.role if c.up or over or p.id == you else "", "up": c.up})
		out_players.append(q)
	var pub := {}
	if not pending.is_empty():
		pub = pending.duplicate(true)
		if pub.has("window_until"):
			pub.window_left_ms = maxi(0, int(pub.window_until) - now) if phase == PHASE_WINDOW else 0
			pub.window_total_ms = int(config.window_ms)
	var v := {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": out_players,
		"config": config.duplicate(),
		"roles": roles(),
		"actions": available_actions(),
		"can_start": can_start(),
		"turn": turn,
		"pending": pub,
		"loser": loser,
		"deck_count": deck.size(),
		"log": log.duplicate(true),
		"winner": winner,
		"can_block": can_block(you),
		"can_challenge": can_challenge(you),
		"exchange": [],
		"examined": "",
		"first_options": first_options.get(you, []).duplicate() if not first_pick.has(you) else [],
		"picked": first_pick.keys(),
	}
	if phase == PHASE_EXCHANGE and you == pending.get("actor", "_"):
		v.exchange = drawn.duplicate()
	if phase == PHASE_EXAMINE_DECIDE and you == pending.get("actor", "_") and shown >= 0:
		v.examined = cards[pending.target][shown].role
	return v


# --- Internos --------------------------------------------------------------

func _log(e: Dictionary) -> void:
	log.append(e)
	while log.size() > LOG_MAX:
		log.pop_front()


func _challenge(challenger: String, _rest: Array) -> Array:
	var in_block := phase == PHASE_BLOCK
	var defender: String = pending.blocker if in_block else pending.actor
	var role: String = pending.block_claim if in_block else pending.claim
	var had := has_role(defender, role)
	var events: Array = [{"type": "challenge", "by": challenger, "target": defender, "role": role, "had": had}]
	_log({"k": "challenge", "id": challenger, "target": defender, "role": role, "had": had})
	if had:
		# Mostra, a carta volta pro baralho e vem outra; quem desafiou perde.
		for i in cards[defender].size():
			var c: Dictionary = cards[defender][i]
			if not c.up and c.role == role:
				_replace(defender, i)
				break
		losses.append(challenger)
		if in_block:
			after = "end_turn" # o bloqueio vale
		else:
			after = "block_window" if not spec(pending.action).blockers.is_empty() else "resolve"
	else:
		losses.append(defender)
		if in_block:
			after = "resolve" # o bloqueio cai e a ação acontece
		else:
			if pending.action == "assassinar":
				coins[pending.actor] = int(coins[pending.actor]) + ASSASSIN_COST
			after = "end_turn"
	return _continue(events)


func _block(blocker: String, role: String, _rest: Array) -> Array:
	pending.blocker = blocker
	pending.block_claim = role
	pending.accepted = []
	phase = PHASE_BLOCK
	return [{"type": "blocked", "id": blocker, "role": role, "action": pending.action}, {"type": "phase", "phase": phase}]


## Esvazia a fila de perdas (uma por vez) e depois segue com `after`.
func _continue(events: Array) -> Array:
	while not losses.is_empty():
		var id: String = losses.pop_front()
		if not alive(id):
			continue
		var h := hidden(id)
		if h.size() == 1:
			events = _reveal(id, cards[id].find(h[0]), events)
			continue
		loser = id
		phase = PHASE_LOSE
		events.append({"type": "phase", "phase": phase})
		events.append({"type": "must_lose", "id": id})
		return events
	loser = ""
	var left := alive_ids()
	if left.size() <= 1:
		winner = left[0] if not left.is_empty() else ""
		phase = PHASE_GAME_OVER
		pending = {}
		events.append({"type": "game_over", "winner": winner})
		return events
	match after:
		"resolve":
			return _resolve(events)
		"block_window":
			# Depois do desafio perdido por quem desafiou, ainda dá pra bloquear: nova janela, só pra isso.
			var s := spec(pending.action)
			if s.block_by == "target" and not alive(pending.target):
				return _end_turn(events)
			pending.stage = "block_only"
			pending.window_until = clock + int(config.window_ms)
			phase = PHASE_WINDOW
			events.append({"type": "phase", "phase": phase})
			events.append({"type": "block_window"})
			return events
	return _end_turn(events)


func _resolve(events: Array) -> Array:
	var a: String = pending.action
	var id: String = pending.actor
	var t: String = pending.target
	match a:
		"ajuda":
			coins[id] = int(coins[id]) + 2
		"imposto":
			coins[id] = int(coins[id]) + 3
		"extorquir":
			var take := mini(2, int(coins[t]))
			coins[t] = int(coins[t]) - take
			coins[id] = int(coins[id]) + take
		"assassinar":
			if alive(t):
				losses.append(t)
				after = "end_turn"
				_log({"k": "done", "id": id, "action": a, "target": t})
				return _continue(events + [{"type": "resolved", "action": a}])
		"trocar":
			drawn = []
			for k in (2 if config.fifth == "embaixador" else 1):
				if not deck.is_empty():
					drawn.append(deck.pop_back())
			phase = PHASE_EXCHANGE
			events.append({"type": "resolved", "action": a})
			events.append({"type": "phase", "phase": phase})
			return events
		"examinar":
			if not alive(t):
				return _end_turn(events)
			var h := hidden(t)
			phase = PHASE_EXAMINE_SHOW
			events.append({"type": "resolved", "action": a})
			if h.size() == 1:
				shown = cards[t].find(h[0])
				phase = PHASE_EXAMINE_DECIDE
			events.append({"type": "phase", "phase": phase})
			return events
	_log({"k": "done", "id": id, "action": a, "target": t})
	events.append({"type": "resolved", "action": a})
	return _end_turn(events)


func _reveal(id: String, i: int, events: Array) -> Array:
	cards[id][i].up = true
	var role: String = cards[id][i].role
	events.append({"type": "lost", "id": id, "role": role})
	_log({"k": "lost", "id": id, "role": role})
	if not alive(id):
		events.append({"type": "eliminated", "id": id})
	return events


## A carta i da pessoa volta pro baralho, embaralha e vem outra.
func _replace(id: String, i: int) -> void:
	deck.append(cards[id][i].role)
	_shuffle(deck)
	cards[id][i] = {"role": deck.pop_back(), "up": false}


## Troca as cartas escondidas pelas da lista, mantendo as viradas.
func _set_hidden(id: String, roles_list: Array) -> void:
	var k := 0
	for c in cards[id]:
		if not c.up:
			c.role = roles_list[k]
			k += 1


func _end_turn(events: Array) -> Array:
	pending = {}
	drawn = []
	shown = -1
	after = ""
	var left := alive_ids()
	if left.size() <= 1:
		winner = left[0] if not left.is_empty() else ""
		phase = PHASE_GAME_OVER
		events.append({"type": "game_over", "winner": winner})
		return events
	var n := players.size()
	var i := players.find(player(turn))
	for k in n:
		i = (i + 1) % n
		if alive(players[i].id):
			break
	turn = players[i].id
	phase = PHASE_TURN
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "turn", "id": turn})
	return events


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
