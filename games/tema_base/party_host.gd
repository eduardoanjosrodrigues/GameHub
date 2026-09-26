class_name PartyHost
extends PartySession
## Este aparelho criou a sala: roda as regras e manda a cada aparelho só o que ele pode ver.
## É o mesmo host do Avalon e do Secret Hitler, sem nada do jogo: serve os dois jogos de tema.

var rules # ItoRules ou SintoniaRules
var game_name := ""
var host_name := ""
var _peers := {} # peer_id -> {"device": String, "role": "player" | "board"}
var _beacon: LanDiscovery
var _seats := SeatTransfer.new()


## role: "player" (o host também joga) ou "board" (este aparelho é o tabuleiro).
func _init(p_game_id: String, p_game_name: String, p_rules, role: String, p_name: String) -> void:
	game_id = p_game_id
	game_name = p_game_name
	rules = p_rules
	is_host = true
	local_role = role
	local_id = Settings.device_id if role == "player" else ""
	host_name = p_name
	if role == "player":
		rules.apply(_actor(local_id, true), {"type": "add_player", "id": local_id, "name": p_name})


## Abre a sala. Retorna "" se deu certo, senão o motivo.
func open_room() -> String:
	var err := Net.host()
	if err != OK:
		return "Não consegui abrir a sala (erro %d). Veja se o Wi-Fi está ligado." % err
	room_code = RoomCode.encode(Net.local_ip())
	# Quem não tem o app (ex: iPhone) entra pelo navegador. Se a porta estiver ocupada, segue sem.
	if Net.start_web({"jogo": game_id, "codigo": room_code, "sala": _beacon_info().nome, "v": Net.PROTOCOL_V}) != OK:
		push_warning("Não consegui abrir a página do navegador.")
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_peer_left)
	_beacon = LanDiscovery.beacon(_beacon_info())
	add_child(_beacon)
	_refresh_local([])
	return ""


func now_ms() -> int:
	return Time.get_ticks_msec()


func _actor(id: String, host: bool, board := false) -> Dictionary:
	return {"id": id, "host": host, "board": board, "now": now_ms()}


func send(action: Dictionary) -> void:
	var res: Dictionary = rules.apply(_actor(local_id, true, local_role == "board"), action)
	if not res.ok:
		error.emit(res.error)
		return
	_broadcast(res.events)


func leave() -> void:
	Net.close()
	queue_free()


func _on_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"qual_jogo":
			Net.send_to(peer_id, {"type": "jogo", "jogo": game_id})
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
			var info: Dictionary = _peers[peer_id]
			var is_board: bool = info.role == "board"
			var res: Dictionary = rules.apply(_actor("" if is_board else info.device, false, is_board), msg.get("action", {}))
			if not res.ok:
				Net.send_to(peer_id, {"type": "erro", "codigo": "acao", "mensagem": res.error})
				return
			_broadcast(res.events)


func _on_hello(peer_id: int, msg: Dictionary) -> void:
	if int(msg.get("v", 0)) != Net.PROTOCOL_V:
		_reject(peer_id, "versao", "Versões diferentes do gamehub. Atualizem o app.")
		return
	if str(msg.get("jogo", "chapeu")) != game_id:
		_reject(peer_id, "outro_jogo", "Essa sala é de %s." % game_name)
		return
	var device: String = str(msg.get("device", ""))
	var role: String = "board" if msg.get("papel", "") == "board" else "player"
	var name: String = str(msg.get("nome", "")).strip_edges()
	if device == "":
		_reject(peer_id, "invalido", "Não deu pra identificar o aparelho.")
		return
	var taken := false
	if role == "player":
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
	if role == "player":
		if rules.player(device).is_empty():
			if rules.phase != "lobby":
				_reject(peer_id, "partida_em_andamento", "A partida já começou. Espere a próxima!")
				return
			var res: Dictionary = rules.apply(_actor("", true), {"type": "add_player", "id": device, "name": name})
			if not res.ok:
				_reject(peer_id, "cheia", res.error)
				return
			events = res.events
		else:
			events = rules.set_connected(device, true)
	_peers[peer_id] = {"device": device, "role": role}
	Net.send_to(peer_id, {"type": "bem_vindo", "id": device if role == "player" else "", "papel": role, "codigo": room_code})
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
	if seat == "" or seat == local_id or rules.player(seat).is_empty() or rules.phase == "lobby":
		return ""
	return _seats.issue(seat, Time.get_ticks_msec())


func _seat_refusal(seat: String) -> String:
	if seat == local_id:
		return "A vaga do host não pode ser trocada: é o aparelho dele que roda a partida."
	return "Não dá pra trocar essa vaga agora."


func _reject(peer_id: int, code: String, message: String) -> void:
	Net.send_to(peer_id, {"type": "erro", "codigo": code, "mensagem": message})
	get_tree().create_timer(0.5).timeout.connect(func(): Net.disconnect_peer(peer_id))


func _on_peer_left(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	var info: Dictionary = _peers[peer_id]
	_peers.erase(peer_id)
	if info.role != "player":
		return
	var events: Array
	if rules.phase == "lobby":
		events = rules.apply(_actor("", true), {"type": "remove_player", "id": info.device}).events
	else:
		# No meio da partida o jogo segue; a pessoa volta pro mesmo lugar (§8).
		events = rules.set_connected(info.device, false)
	_broadcast(events)


func _broadcast(events: Array) -> void:
	var now := now_ms()
	for pid in _peers:
		var info: Dictionary = _peers[pid]
		var v: Dictionary = rules.view_for({"id": info.device if info.role == "player" else "", "role": info.role}, now)
		Net.send_to(pid, {"type": "estado", "view": v, "events": events})
	_refresh_local(events)
	if _beacon:
		if rules.phase == "lobby":
			_beacon.info = _beacon_info()
		else:
			_beacon.queue_free()
			_beacon = null


func _refresh_local(events: Array) -> void:
	var v: Dictionary = rules.view_for({"id": local_id, "role": local_role}, now_ms())
	v.room_code = room_code
	v.host_ip = Net.local_ip()
	_emit_view(v, events)


func _beacon_info() -> Dictionary:
	return {
		"nome": "Sala de %s" % host_name if host_name != "" else "Sala do tabuleiro",
		"jogo": game_id,
		"jogadores": rules.players.size(),
		"porta": Net.PORT,
		"codigo": room_code,
	}
