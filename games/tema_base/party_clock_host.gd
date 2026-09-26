class_name PartyClockHost
extends PartyHost
## Host com relógio justo (docs/PLANO_QUEM_FOI.md §5, docs/PLANO_COUP.md §5): o PartyHost mais a
## janela do sino do Halli Galli. Responde os pings do relógio; as ações "com hora" (toque na corrida,
## desafio, bloqueio) esperam uma janela curta pra chegarem as de quem tem a rede mais lenta, e as
## regras decidem pela hora de cada uma (rules.resolve_timed). Também chama rules.tick(agora) sempre.

const WINDOW_MIN_MS := 80
const WINDOW_MAX_MS := 300
const WINDOW_MARGIN_MS := 40
## Uma ação não pode dizer que aconteceu no futuro (relógio do cliente adiantado demais).
const FUTURE_SLACK_MS := 50

## Tipos de ação que vão pela janela (cada jogo define).
var timed_types: Array = []
var _queue: Array = []
var _deadline := -1
var _rtt := {} # peer_id -> maior ida e volta recente (ms)


## Janela: o maior atraso de ida entre os jogadores, com folga e limites.
func window_ms() -> int:
	var worst := 0
	for pid in _rtt:
		worst = maxi(worst, int(_rtt[pid]))
	return clampi(worst / 2 + WINDOW_MARGIN_MS, WINDOW_MIN_MS, WINDOW_MAX_MS)


func send(action: Dictionary) -> void:
	if action.get("type", "") in timed_types:
		var a := action.duplicate()
		a.t = int(a.get("local_us", Time.get_ticks_usec())) / 1000
		a.erase("local_us")
		_enqueue(local_id, a)
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
			if action.get("type", "") in timed_types and _peers.has(peer_id) and _peers[peer_id].role == "player":
				_enqueue(_peers[peer_id].device, action)
				return
	super(peer_id, msg)


func _on_peer_left(peer_id: int) -> void:
	_rtt.erase(peer_id)
	super(peer_id)


func _enqueue(id: String, action: Dictionary) -> void:
	var a := action.duplicate()
	a.player = id
	a.t = mini(int(a.get("t", now_ms())), now_ms() + FUTURE_SLACK_MS)
	_queue.append(a)
	if _deadline < 0:
		_deadline = now_ms() + window_ms()


func _process(_delta: float) -> void:
	var now := now_ms()
	if _deadline >= 0 and now >= _deadline:
		var list := _queue
		_queue = []
		_deadline = -1
		var res: Dictionary = rules.resolve_timed(list, now)
		if not res.ok and res.error != "":
			for a in list:
				_tell_error(a.player, res.error)
		if not res.events.is_empty():
			_broadcast(res.events)
	var t: Dictionary = rules.tick(now)
	if not t.events.is_empty():
		_broadcast(t.events)


func _tell_error(id: String, text: String) -> void:
	if id == local_id:
		error.emit(text)
		return
	for pid in _peers:
		if _peers[pid].device == id:
			Net.send_to(pid, {"type": "erro", "codigo": "acao", "mensagem": text})
