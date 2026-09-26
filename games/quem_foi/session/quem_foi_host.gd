class_name QuemFoiHost
extends PartyHost
## Host do Quem Foi?: o PartyHost dos jogos de tema, mais a corrida justa do sino do Halli Galli
## (docs/PLANO_QUEM_FOI.md §5). Responde os pings do relógio; ao chegar o primeiro toque, espera uma
## janela pra chegarem os toques de quem tem a rede mais lenta e decide pelo horário do toque.

const GAME := "quem_foi"
const WINDOW_MIN_MS := 80
const WINDOW_MAX_MS := 300
const WINDOW_MARGIN_MS := 40
## Um toque não pode dizer que aconteceu no futuro (relógio do cliente adiantado demais).
const FUTURE_SLACK_MS := 50

var _taps: Array = []
var _tap_deadline := -1
var _rtt := {} # peer_id -> maior ida e volta recente (ms)


func _init(role: String, p_name: String) -> void:
	super(GAME, "Quem Foi?", QuemFoiRules.new(), role, p_name)


## Janela da corrida: o maior atraso de ida entre os jogadores, com folga e limites.
func window_ms() -> int:
	var worst := 0
	for pid in _rtt:
		worst = maxi(worst, int(_rtt[pid]))
	return clampi(worst / 2 + WINDOW_MARGIN_MS, WINDOW_MIN_MS, WINDOW_MAX_MS)


func send(action: Dictionary) -> void:
	if action.get("type", "") == "tap":
		_queue_tap(local_id, int(action.get("local_us", Time.get_ticks_usec())) / 1000, str(action.get("animal", "")))
		return
	super(action)


func _on_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"ping":
			Net.send_to(peer_id, {"type": "pong", "c": msg.get("c", 0), "h": Time.get_ticks_usec()}, true)
			_rtt[peer_id] = int(msg.get("rtt", 0))
			return
		"acao":
			var action: Dictionary = msg.get("action", {})
			if action.get("type", "") == "tap" and _peers.has(peer_id) and _peers[peer_id].role == "player":
				_queue_tap(_peers[peer_id].device, int(action.get("t", 0)), str(action.get("animal", "")))
				return
	super(peer_id, msg)


func _on_peer_left(peer_id: int) -> void:
	_rtt.erase(peer_id)
	super(peer_id)


func _queue_tap(id: String, t: int, animal: String) -> void:
	if rules.phase != QuemFoiRules.PHASE_RACE:
		return
	_taps.append({"player": id, "t": mini(t, now_ms() + FUTURE_SLACK_MS), "animal": animal})
	if _tap_deadline < 0:
		_tap_deadline = now_ms() + window_ms()


func _process(_delta: float) -> void:
	var now := now_ms()
	if _tap_deadline >= 0 and now >= _tap_deadline:
		var taps := _taps
		_taps = []
		_tap_deadline = -1
		var res: Dictionary = rules.ring(taps, now)
		if not res.events.is_empty():
			_broadcast(res.events)
	var t: Dictionary = rules.tick(now)
	if not t.events.is_empty():
		_broadcast(t.events)
