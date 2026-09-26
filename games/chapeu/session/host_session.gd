class_name HostSession
extends ChapeuSession
## Wi-Fi, este aparelho é o host: roda as regras e manda a cada aparelho só o que ele pode ver.

const TIME_SYNC_MS := 250

var rules: ChapeuRules
var host_name := ""
var _peers := {} # peer_id -> {"device": String, "role": "player" | "board"}
var _beacon: LanDiscovery
var _last_tick := 0
var _last_sync := 0


## role: "player" (o host também joga) ou "board" (este aparelho é o tabuleiro).
func _init(role: String, p_name: String) -> void:
	mode = "wifi"
	is_host = true
	local_role = role
	local_id = Settings.device_id if role == "player" else ""
	host_name = p_name
	rules = ChapeuRules.new("wifi", WordBank.load_all())
	if role == "player":
		rules.apply(_host_actor(), {"type": "add_player", "id": local_id, "name": p_name, "team": "azul"})


## Abre a sala. Retorna "" se deu certo, senão o motivo.
func open_room() -> String:
	var err := Net.host()
	if err != OK:
		return "Não consegui abrir a sala (erro %d). Veja se o Wi-Fi está ligado." % err
	var ip := Net.local_ip()
	room_code = RoomCode.encode(ip)
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_peer_left)
	_beacon = LanDiscovery.beacon(_beacon_info())
	add_child(_beacon)
	_refresh_local([])
	return ""


func host_ip() -> String:
	return Net.local_ip()


func _host_actor() -> Dictionary:
	return {"id": local_id, "host": true}


func send(action: Dictionary) -> void:
	var res := rules.apply(_host_actor(), action)
	if not res.ok:
		error.emit(res.error)
		return
	_broadcast(res.events)


func leave() -> void:
	Net.close()
	queue_free()


# --- Mensagens dos clientes ------------------------------------------------

func _on_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"hello":
			_on_hello(peer_id, msg)
		"acao":
			if not _peers.has(peer_id):
				return
			var info: Dictionary = _peers[peer_id]
			var actor := {"id": info.device if info.role == "player" else "", "host": false}
			var res := rules.apply(actor, msg.get("action", {}))
			if not res.ok:
				Net.send_to(peer_id, {"type": "erro", "codigo": "acao", "mensagem": res.error})
				return
			_broadcast(res.events)


func _on_hello(peer_id: int, msg: Dictionary) -> void:
	if int(msg.get("v", 0)) != Net.PROTOCOL_V:
		_reject(peer_id, "versao", "Versões diferentes do gamehub. Atualizem o app.")
		return
	var device: String = str(msg.get("device", ""))
	var role: String = "board" if msg.get("papel", "") == "board" else "player"
	var name: String = str(msg.get("nome", "")).strip_edges()
	if device == "":
		_reject(peer_id, "invalido", "Não deu pra identificar o aparelho.")
		return
	# O mesmo aparelho reconectando: esquece a conexão antiga.
	for pid in _peers.keys():
		if _peers[pid].device == device and pid != peer_id:
			_peers.erase(pid)
	var events: Array = []
	if role == "player":
		var existing := rules.player(device)
		if existing.is_empty():
			if rules.phase != ChapeuRules.PHASE_LOBBY:
				_reject(peer_id, "partida_em_andamento", "A partida já começou. Espere a próxima!")
				return
			var res := rules.apply(_host_actor(), {"type": "add_player", "id": device, "name": name})
			if not res.ok:
				_reject(peer_id, "cheia", res.error)
				return
			events = res.events
		else:
			events = rules.set_connected(device, true)
	_peers[peer_id] = {"device": device, "role": role}
	Net.send_to(peer_id, {"type": "bem_vindo", "id": device if role == "player" else "", "papel": role, "codigo": room_code})
	_broadcast(events)


func _reject(peer_id: int, code: String, message: String) -> void:
	Net.send_to(peer_id, {"type": "erro", "codigo": code, "mensagem": message})
	# Dá tempo da mensagem chegar antes de desconectar.
	get_tree().create_timer(0.5).timeout.connect(func(): Net.disconnect_peer(peer_id))


func _on_peer_left(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	var info: Dictionary = _peers[peer_id]
	_peers.erase(peer_id)
	if info.role != "player":
		return
	var events: Array
	if rules.phase == ChapeuRules.PHASE_LOBBY:
		events = rules.apply(_host_actor(), {"type": "remove_player", "id": info.device}).events
	else:
		events = rules.set_connected(info.device, false)
	_broadcast(events)


# --- Envio -----------------------------------------------------------------

func _viewer_for(info: Dictionary) -> Dictionary:
	return {"id": info.device if info.role == "player" else "", "role": info.role}


func _broadcast(events: Array) -> void:
	for pid in _peers:
		Net.send_to(pid, {"type": "estado", "view": rules.view_for(_viewer_for(_peers[pid])), "events": events})
	_refresh_local(events)
	if _beacon:
		if rules.phase == ChapeuRules.PHASE_LOBBY:
			_beacon.info = _beacon_info()
		else:
			# Partida começou: a sala some da descoberta (não entra ninguém novo).
			_beacon.queue_free()
			_beacon = null


func _refresh_local(events: Array) -> void:
	var v := rules.view_for({"id": local_id, "role": local_role})
	v.room_code = room_code
	v.host_ip = Net.local_ip()
	_emit_view(v, events)


func _beacon_info() -> Dictionary:
	return {
		"nome": "Sala de %s" % host_name if host_name != "" else "Sala do tabuleiro",
		"jogo": "chapeu",
		"jogadores": rules.players.size(),
		"porta": Net.PORT,
		"codigo": room_code,
	}


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := now - _last_tick if _last_tick > 0 else 0
	_last_tick = now
	if rules.phase != ChapeuRules.PHASE_TURN or rules.paused:
		return
	var events := rules.tick(dt)
	if not events.is_empty():
		_broadcast(events)
		return
	time_changed.emit(rules.time_ms)
	if now - _last_sync >= TIME_SYNC_MS:
		_last_sync = now
		for pid in _peers:
			Net.send_to(pid, {"type": "tempo", "ms": rules.time_ms}, true)
