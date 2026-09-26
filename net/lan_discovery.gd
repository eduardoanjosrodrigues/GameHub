class_name LanDiscovery
extends Node
## Descoberta de salas na rede local por broadcast UDP (porta 7778).
##
## Modo "beacon" (host): anuncia a sala a cada segundo.
## Modo "scan" (quem quer entrar): escuta e mantém a lista de salas vistas nos últimos 3 s.
## No Android, precisa da permissão CHANGE_WIFI_MULTICAST_STATE (o Godot pega o multicast lock).

signal rooms_changed(rooms: Array)

const PORT := 7778
const APP_ID := "gamehub"
const INTERVAL_S := 1.0
const EXPIRE_MS := 3500

var info := {} # o que o beacon anuncia
var _mode := ""
var _udp := PacketPeerUDP.new()
var _elapsed := 0.0
var _rooms := {} # ip -> {info, seen}


static func beacon(p_info: Dictionary) -> LanDiscovery:
	var d := LanDiscovery.new()
	d._mode = "beacon"
	d.info = p_info
	return d


static func scanner() -> LanDiscovery:
	var d := LanDiscovery.new()
	d._mode = "scan"
	return d


func _ready() -> void:
	_udp.set_broadcast_enabled(true)
	if _mode == "scan":
		var err := _udp.bind(PORT, "*")
		if err != OK:
			push_warning("Descoberta: não consegui escutar a porta %d (%d)" % [PORT, err])
	else:
		_elapsed = INTERVAL_S


func _exit_tree() -> void:
	_udp.close()


func _process(delta: float) -> void:
	if _mode == "beacon":
		_elapsed += delta
		if _elapsed >= INTERVAL_S:
			_elapsed = 0.0
			_announce()
	else:
		_receive()


func _announce() -> void:
	var payload := info.duplicate()
	payload.app = APP_ID
	payload.v = Net.PROTOCOL_V
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	for addr in Net.broadcast_addresses():
		_udp.set_dest_address(addr, PORT)
		_udp.put_packet(bytes)


func _receive() -> void:
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var data = JSON.parse_string(pkt.get_string_from_utf8())
		if not (data is Dictionary) or data.get("app", "") != APP_ID:
			continue
		if not _rooms.has(ip):
			changed = true
		elif _rooms[ip].info.hash() != data.hash():
			changed = true
		_rooms[ip] = {"info": data, "seen": Time.get_ticks_msec()}
	var now := Time.get_ticks_msec()
	for ip in _rooms.keys():
		if now - _rooms[ip].seen > EXPIRE_MS:
			_rooms.erase(ip)
			changed = true
	if changed:
		rooms_changed.emit(rooms())


func rooms() -> Array:
	var out: Array = []
	for ip in _rooms:
		var r: Dictionary = _rooms[ip].info.duplicate()
		r.ip = ip
		out.append(r)
	out.sort_custom(func(a, b): return str(a.get("nome", "")) < str(b.get("nome", "")))
	return out
