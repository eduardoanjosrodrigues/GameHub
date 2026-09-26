class_name HalliHost
extends HalliSession
## Wi-Fi, este aparelho criou a sala: roda as regras, responde os pings do relógio e decide o sino.
##
## Sino (docs/PLANO_HALLI_GALLI.md §5.3): ao chegar o primeiro toque, espera uma janela J pra dar
## tempo de chegarem toques anteriores de quem está com a rede mais lenta; depois resolve tudo
## pelo horário do toque.

const WINDOW_MIN_MS := 80
const WINDOW_MAX_MS := 300
const WINDOW_MARGIN_MS := 40
## Um toque não pode dizer que aconteceu no futuro (relógio do cliente adiantado demais).
const FUTURE_SLACK_MS := 50

var rules: HalliRules
var host_name := ""
var _peers := {} # peer_id -> {"device": String, "rtt": int}
var _beacon: LanDiscovery
var _seats := SeatTransfer.new()
var _bells: Array = []
var _bell_deadline := -1


func _init(p_name: String) -> void:
	mode = "wifi"
	is_host = true
	local_id = Settings.device_id
	host_name = p_name
	rules = HalliRules.new("wifi")
	rules.apply(_host_actor(), {"type": "add_player", "id": local_id, "name": p_name})


## Abre a sala. Retorna "" se deu certo, senão o motivo.
func open_room() -> String:
	var err := Net.host()
	if err != OK:
		return "Não consegui abrir a sala (erro %d). Veja se o Wi-Fi está ligado." % err
	room_code = RoomCode.encode(Net.local_ip())
	# Quem não tem o app (ex: iPhone) entra pelo navegador. Se a porta estiver ocupada, segue sem.
	if Net.start_web({"jogo": GAME_ID, "codigo": room_code, "sala": "Sala de %s" % host_name, "v": Net.PROTOCOL_V}) != OK:
		push_warning("Não consegui abrir a página do navegador.")
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_peer_left)
	_beacon = LanDiscovery.beacon(_beacon_info())
	add_child(_beacon)
	_refresh_local([])
	return ""


func _host_actor() -> Dictionary:
	return {"id": local_id, "host": true, "now": now_ms()}


func send(action: Dictionary) -> void:
	match action.get("type", ""):
		"bell":
			_queue_bell(local_id, int(action.get("local_us", Time.get_ticks_usec())) / 1000)
		"flip":
			_apply(_host_actor(), {"type": "flip", "t": now_ms()}, -1)
		_:
			_apply(_host_actor(), action, -1)


func leave() -> void:
	Net.close()
	queue_free()


## Janela do sino: o maior atraso de ida entre os jogadores, com folga e limites.
func window_ms() -> int:
	var worst := 0
	for pid in _peers:
		worst = maxi(worst, int(_peers[pid].rtt))
	return clampi(worst / 2 + WINDOW_MARGIN_MS, WINDOW_MIN_MS, WINDOW_MAX_MS)


func _apply(actor: Dictionary, action: Dictionary, from_peer: int) -> void:
	var res := rules.apply(actor, action)
	if not res.ok:
		if from_peer < 0:
			rejected.emit(res.error)
			_refresh_local([])
		else:
			# O cliente pode ter mostrado a carta antes da resposta: manda o estado certo de volta.
			Net.send_to(from_peer, {"type": "erro", "codigo": "acao", "mensagem": res.error})
			_send_state(from_peer, [])
		return
	_broadcast(res.events)


func _queue_bell(id: String, t: int) -> void:
	if rules.phase != HalliRules.PHASE_PLAYING or rules.paused:
		return
	_bells.append({"player": id, "t": mini(t, now_ms() + FUTURE_SLACK_MS)})
	if _bell_deadline < 0:
		_bell_deadline = now_ms() + window_ms()


func _process(_delta: float) -> void:
	if _bell_deadline >= 0 and now_ms() >= _bell_deadline:
		var bells := _bells
		_bells = []
		_bell_deadline = -1
		var res := rules.ring(bells, now_ms())
		if not res.events.is_empty():
			_broadcast(res.events)


# --- Mensagens dos clientes ------------------------------------------------

func _on_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"ping":
			Net.send_to(peer_id, {"type": "pong", "c": msg.get("c", 0), "h": Time.get_ticks_usec()}, true)
			if _peers.has(peer_id):
				_peers[peer_id].rtt = int(msg.get("rtt", 0))
		"qual_jogo":
			Net.send_to(peer_id, {"type": "jogo", "jogo": GAME_ID})
		"hello":
			_on_hello(peer_id, msg)
		"pedir_vaga":
			# Só o tabuleiro (além do host) pode abrir o QR pra passar a vaga de alguém.
			if _peers.has(peer_id) and _peers[peer_id].get("role", "") == "board":
				var seat := str(msg.get("id", ""))
				var token := _issue_seat(seat)
				if token != "":
					Net.send_to(peer_id, {"type": "vaga", "id": seat, "token": token})
				else:
					Net.send_to(peer_id, {"type": "erro", "codigo": "vaga", "mensagem": _seat_refusal(seat)})
		"acao":
			if not _peers.has(peer_id):
				return
			var device: String = _peers[peer_id].device
			var action: Dictionary = msg.get("action", {})
			match action.get("type", ""):
				"bell":
					_queue_bell(device, int(action.get("t", 0)))
				"flip":
					var t := mini(int(action.get("t", 0)), now_ms() + FUTURE_SLACK_MS)
					_apply({"id": device, "host": false}, {"type": "flip", "t": t}, peer_id)
				_:
					_apply({"id": device, "host": false, "now": now_ms()}, action, peer_id)


func _on_hello(peer_id: int, msg: Dictionary) -> void:
	if int(msg.get("v", 0)) != Net.PROTOCOL_V:
		_reject(peer_id, "versao", "Versões diferentes do gamehub. Atualizem o app.")
		return
	if str(msg.get("jogo", "chapeu")) != GAME_ID:
		_reject(peer_id, "outro_jogo", "Essa sala é de Halli Galli.", {"jogo": GAME_ID})
		return
	var device: String = str(msg.get("device", ""))
	var name: String = str(msg.get("nome", "")).strip_edges()
	if device == "":
		_reject(peer_id, "invalido", "Não deu pra identificar o aparelho.")
		return
	var taken := false
	var sr := _seats.on_hello(device, str(msg.get("vaga", "")), func(id: String) -> bool: return not rules.player(id).is_empty(), Time.get_ticks_msec())
	if sr.has("erro"):
		_reject(peer_id, sr.erro, sr.mensagem)
		return
	device = sr.seat
	taken = sr.taken
	# O mesmo aparelho reconectando: esquece a conexão antiga. Se outro aparelho assumiu a vaga
	# (QR de troca), o antigo é avisado e desconectado.
	for pid in _peers.keys():
		if _peers[pid].device == device and pid != peer_id:
			if taken:
				_reject(pid, "vaga_passada", "Seu lugar na partida foi passado para outro aparelho.")
			_peers.erase(pid)
	var events: Array = []
	if rules.player(device).is_empty():
		if rules.phase != HalliRules.PHASE_LOBBY:
			_reject(peer_id, "partida_em_andamento", "A partida já começou. Espere a próxima!")
			return
		var res := rules.apply(_host_actor(), {"type": "add_player", "id": device, "name": name})
		if not res.ok:
			_reject(peer_id, "cheia", res.error)
			return
		events = res.events
	else:
		events = rules.set_connected(device, true, now_ms())
	_peers[peer_id] = {"device": device, "rtt": 0}
	Net.send_to(peer_id, {"type": "bem_vindo", "id": device, "codigo": room_code})
	_broadcast(events)


## Abre o QR pra passar a vaga de alguém pra outro aparelho (host). A resposta vem por seat_link.
func request_seat(seat: String) -> void:
	var token := _issue_seat(seat)
	if token != "":
		seat_link.emit(seat, token)
	else:
		error.emit(_seat_refusal(seat))


func _issue_seat(seat: String) -> String:
	# A vaga do próprio host não troca: é ele que roda a partida.
	if seat == "" or seat == local_id or rules.player(seat).is_empty() or rules.phase == HalliRules.PHASE_LOBBY:
		return ""
	return _seats.issue(seat, Time.get_ticks_msec())


func _seat_refusal(seat: String) -> String:
	if seat == local_id:
		return "A vaga do host não pode ser trocada: é o aparelho dele que roda a partida."
	return "Não dá pra trocar essa vaga agora."


func _reject(peer_id: int, code: String, message: String, extra := {}) -> void:
	var msg := {"type": "erro", "codigo": code, "mensagem": message}
	msg.merge(extra)
	Net.send_to(peer_id, msg)
	# Dá tempo da mensagem chegar antes de desconectar.
	get_tree().create_timer(0.5).timeout.connect(func(): Net.disconnect_peer(peer_id))


func _on_peer_left(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	var device: String = _peers[peer_id].device
	_peers.erase(peer_id)
	var events: Array
	if rules.phase == HalliRules.PHASE_LOBBY:
		events = rules.apply(_host_actor(), {"type": "remove_player", "id": device}).events
	else:
		events = rules.set_connected(device, false, now_ms())
	_broadcast(events)


# --- Envio -----------------------------------------------------------------

func _send_state(peer_id: int, events: Array) -> void:
	var v := rules.view_for({"id": _peers[peer_id].device, "role": "player"})
	Net.send_to(peer_id, {"type": "estado", "view": v, "events": events})


func _broadcast(events: Array) -> void:
	for pid in _peers:
		_send_state(pid, events)
	_refresh_local(events)
	if _beacon:
		if rules.phase == HalliRules.PHASE_LOBBY:
			_beacon.info = _beacon_info()
		else:
			# Partida começou: a sala some da descoberta (não entra ninguém novo).
			_beacon.queue_free()
			_beacon = null


func _refresh_local(events: Array) -> void:
	var v := rules.view_for({"id": local_id, "role": "player"})
	v.room_code = room_code
	v.host_ip = Net.local_ip()
	_emit_view(v, events)


func _beacon_info() -> Dictionary:
	return {
		"nome": "Sala de %s" % host_name,
		"jogo": GAME_ID,
		"jogadores": rules.players.size(),
		"porta": Net.PORT,
		"codigo": room_code,
	}
