class_name QuemFoiRules
extends RefCounted
## Regras do Quem Foi? (Who Did It?) como máquina de estados pura (docs/PLANO_QUEM_FOI.md §3).
##
## Cada um tem os 6 bichos da sua cor. Quem acusa joga um bicho e diz "acho que foi o <bicho> de
## alguém"; quem ainda tem esse bicho corre pra jogar o seu primeiro e acusa o próximo. A corrida é
## decidida pelo host com os toques no relógio dele (ring), como o sino do Halli Galli.
## Ator de uma ação: {"id", "host", "board", "now"}.

const MIN_PLAYERS := 3
const MAX_PLAYERS := 6
const ANIMALS := ["gato", "peixe", "tartaruga", "coelho", "hamster", "papagaio"]
const POOPS_RANGE := Vector2i(2, 5)
## Ninguém mais tem o bicho acusado: todo mundo procura por esse tempo antes do culpado aparecer.
const SUSPENSE_MS := 5000
## Tocar no bicho errado trava a pessoa por esse tempo (o celular também trava sozinho).
const MISS_LOCK_MS := 1000

const PHASE_LOBBY := "lobby"
const PHASE_ACCUSE := "accuse" # alguém joga (na abertura) e acusa
const PHASE_RACE := "race" # quem tem o bicho acusado corre
const PHASE_ROUND_END := "round_end"
const PHASE_GAME_OVER := "game_over"

var phase := PHASE_LOBBY
## Cada jogador: {id, name, color, connected, poops}, na ordem da mesa.
var players: Array = []
var config := {"max_poops": 3, "memory_help": false}
var hands := {} # id -> [bichos que ainda tem]
var pile: Array = [] # [{animal, owner}], o topo é o fim
var accuser := "" # quem está acusando (ou acabou de acusar)
var accused := "" # bicho acusado na corrida
var race_no := 0 # conta as acusações (a mão embaralha a cada uma)
var race_at := 0 # hora do host em que a corrida começou
var doomed := false # ninguém tem o bicho: a rodada acaba quando o suspense passar
var suspense_until := 0
var locked := {} # id -> hora do host até quando está travado por tocar errado
var round_no := 0
var starter := "" # quem abre a próxima rodada
var last := {} # fim da rodada: {guilty, animal, reason: "ninguem_tem" | "ultimo", hands}
var winners: Array = []
var rng := RandomNumberGenerator.new()

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


func has_animal(id: String, animal: String) -> bool:
	return animal in hands.get(id, [])


## Quem pode correr agora: tem o bicho acusado e não é quem acusou.
func racers() -> Array:
	var out: Array = []
	for p in players:
		if p.id != accuser and has_animal(p.id, accused):
			out.append(p.id)
	return out


func with_cards() -> Array:
	return players.filter(func(p): return not hands.get(p.id, []).is_empty()).map(func(p): return p.id)


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
	if id == "" or not player(id).is_empty():
		return _err("Jogador já está na sala.")
	# Cada um com uma cor que ainda está livre.
	var used := players.map(func(p): return int(p.color))
	var c := 0
	while c in used:
		c += 1
	players.append({"id": id, "name": n, "color": c, "connected": true, "poops": 0})
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
	if a.has("max_poops"):
		config.max_poops = clampi(int(a.max_poops), POOPS_RANGE.x, POOPS_RANGE.y)
	if a.has("memory_help"):
		config.memory_help = bool(a.memory_help)
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
		p.poops = 0
	winners = []
	round_no = 0
	starter = players[rng.randi_range(0, players.size() - 1)].id
	return _ok(_new_round([{"type": "started"}]))


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


## Quem acusa: na abertura da rodada joga um bicho (play) e acusa (animal); depois de ganhar a
## corrida, a carta já está na pilha e só acusa.
func _a_accuse(actor: Dictionary, a: Dictionary) -> Dictionary:
	if phase != PHASE_ACCUSE:
		return _err("Não é hora de acusar.")
	if actor.get("id", "") != accuser:
		return _err("Não é você quem acusa agora.")
	var animal := str(a.get("animal", ""))
	if animal not in ANIMALS:
		return _err("Escolha um bicho.")
	var events: Array = []
	if pile.is_empty():
		var play := str(a.get("play", ""))
		if not has_animal(accuser, play):
			return _err("Escolha um bicho da sua mão pra jogar.")
		_place(accuser, play)
		events.append({"type": "played", "id": accuser, "animal": play})
		var alone := _only_one_left()
		if alone != "":
			return _ok(_end_round(alone, play, "ultimo", events))
	accused = animal
	race_no += 1
	race_at = int(actor.get("now", 0))
	locked = {}
	events.append({"type": "accused", "by": accuser, "animal": animal, "race": race_no})
	phase = PHASE_RACE
	events.push_front({"type": "phase", "phase": phase})
	if racers().is_empty():
		# Ninguém tem: a tela segue igual à da corrida durante o suspense (§3.6).
		doomed = true
		suspense_until = race_at + SUSPENSE_MS
	else:
		doomed = false
	return _ok(events)


## Tocou no bicho errado: fica travado por 1 s (os toques nesse tempo não contam).
func _a_miss(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_RACE:
		return _err("Não tem corrida agora.")
	var id: String = actor.get("id", "")
	if player(id).is_empty():
		return _err("Só quem joga corre.")
	locked[id] = int(actor.get("now", 0)) + MISS_LOCK_MS
	return _ok([{"type": "miss", "id": id}])


func _a_continue(actor: Dictionary, _a: Dictionary) -> Dictionary:
	if phase != PHASE_ROUND_END:
		return _err("Nada pra continuar.")
	if player(actor.get("id", "")).is_empty() and not actor.get("board", false) and not actor.get("host", false):
		return _err("Só quem está na partida continua.")
	var worst := 0
	for p in players:
		worst = maxi(worst, int(p.poops))
	if worst >= int(config.max_poops):
		var least := 999
		for p in players:
			least = mini(least, int(p.poops))
		winners = players.filter(func(p): return int(p.poops) == least).map(func(p): return p.id)
		phase = PHASE_GAME_OVER
		return _ok([{"type": "game_over", "winners": winners}])
	return _ok(_new_round([]))


## Resolve a corrida com os toques que chegaram na janela: [{player, t, animal}] (t no relógio do
## host). Ganha o toque mais cedo de quem pode correr, com o bicho certo e sem estar travado.
func ring(taps: Array, _now: int) -> Dictionary:
	if phase != PHASE_RACE or doomed:
		return _ok()
	var best := {}
	for tap in taps:
		var id: String = tap.get("player", "")
		if tap.get("animal", "") != accused or id == accuser or not has_animal(id, accused):
			continue
		if int(tap.t) < int(locked.get(id, -1)) or int(tap.t) < race_at:
			continue
		if best.is_empty() or int(tap.t) < int(best.t):
			best = tap
	if best.is_empty():
		return _ok()
	var winner: String = best.player
	_place(winner, accused)
	var events: Array = [{"type": "won_race", "id": winner, "animal": accused, "race": race_no}]
	var alone := _only_one_left()
	if alone != "":
		return _ok(_end_round(alone, accused, "ultimo", events))
	accuser = winner
	accused = ""
	phase = PHASE_ACCUSE
	events.push_front({"type": "phase", "phase": phase})
	return _ok(events)


## O host chama sempre: acaba o suspense quando o tempo passa.
func tick(now: int) -> Dictionary:
	if phase == PHASE_RACE and doomed and now >= suspense_until:
		var top: Dictionary = pile.back()
		return _ok(_end_round(top.owner, top.animal, "ninguem_tem", []))
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
	var out_players: Array = []
	for p in players:
		var q: Dictionary = p.duplicate()
		q.cards = hands.get(p.id, []).size()
		out_players.append(q)
	var hand: Array = []
	if you != "" and hands.has(you):
		hand = hands[you].duplicate()
		# Posições novas a cada acusação (§2), iguais em qualquer tela da mesma pessoa.
		var r := RandomNumberGenerator.new()
		r.seed = hash("%s|%d|%d" % [you, round_no, race_no])
		for i in range(hand.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var tmp = hand[i]
			hand[i] = hand[j]
			hand[j] = tmp
	var played := {}
	if config.memory_help:
		for c in pile:
			played[c.animal] = int(played.get(c.animal, 0)) + 1
	return {
		"phase": phase,
		"you": you,
		"role_view": viewer.get("role", "player"),
		"players": out_players,
		"config": config.duplicate(),
		"can_start": can_start(),
		"animals": ANIMALS.duplicate(),
		"hand": hand,
		"top": pile.back().duplicate() if not pile.is_empty() else {},
		"pile_size": pile.size(),
		"played": played,
		"accuser": accuser,
		"accused": accused,
		"race_no": race_no,
		"race_at": race_at,
		"round_no": round_no,
		"locked_ms": maxi(0, int(locked.get(you, 0)) - now) if phase == PHASE_RACE else 0,
		"last": last.duplicate(true) if phase in [PHASE_ROUND_END, PHASE_GAME_OVER] else {},
		"winners": winners.duplicate(),
		"max_poops": config.max_poops,
	}


# --- Internos --------------------------------------------------------------

func _place(id: String, animal: String) -> void:
	hands[id].erase(animal)
	pile.append({"animal": animal, "owner": id})


## Só uma pessoa ainda tem cartas: ela fica com a culpa (oficial).
func _only_one_left() -> String:
	var left := with_cards()
	return left[0] if left.size() == 1 else ""


func _new_round(events: Array) -> Array:
	round_no += 1
	hands = {}
	for p in players:
		hands[p.id] = ANIMALS.duplicate()
	pile = []
	accuser = starter
	accused = ""
	doomed = false
	locked = {}
	last = {}
	phase = PHASE_ACCUSE
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "round", "round": round_no, "starter": starter})
	return events


func _end_round(guilty: String, animal: String, reason: String, events: Array) -> Array:
	var p := player(guilty)
	p.poops = int(p.poops) + 1
	last = {"guilty": guilty, "animal": animal, "reason": reason, "accused": accused, "hands": hands.duplicate(true)}
	starter = guilty
	doomed = false
	phase = PHASE_ROUND_END
	events.append({"type": "phase", "phase": phase})
	events.append({"type": "guilty", "id": guilty, "animal": animal, "reason": reason})
	return events


func _ok(events: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "events": events}


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}
