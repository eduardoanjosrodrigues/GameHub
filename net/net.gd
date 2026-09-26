extends Node
## Transporte de rede local (ENet) genérico, reutilizável por qualquer jogo do hub.
## O host também pode abrir a porta pro navegador (WebGateway): quem entra pela página vira um
## peer como qualquer outro, com as mesmas mensagens.
##
## Todas as mensagens são dicionários {v, type, ...} que passam por um único par de RPCs.
## O host é autoritativo: clientes mandam intenções, o host responde com estado.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal message(peer_id: int, msg: Dictionary)
signal joined
signal join_failed(reason: String)
signal host_lost

const PORT := 7777
const PROTOCOL_V := 2
const MAX_CLIENTS := 20
const JOIN_TIMEOUT_S := 6.0

var role := "" # "host", "client" ou ""
## Só pra testes (robôs de rede): atraso artificial em cada sentido, no cliente.
var debug_lag_ms := 0
## Servidor pra quem joga pelo navegador (só no host, se aberto com start_web).
var web: WebGateway
var _join_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func is_active() -> bool:
	return role != ""


func host(port := PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = "host"
	return OK


func join(ip: String, port := PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = "client"
	var t := get_tree().create_timer(JOIN_TIMEOUT_S)
	_join_timer = t
	t.timeout.connect(func():
		if _join_timer == t and role == "client" and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			close()
			join_failed.emit("timeout"))
	return OK


## Abre a página do jogo pra navegadores (host). info vai no /config.json da página.
func start_web(info: Dictionary) -> Error:
	stop_web()
	web = WebGateway.new()
	web.info = info
	web.peer_joined.connect(func(id): peer_joined.emit(id))
	web.peer_left.connect(func(id): peer_left.emit(id))
	web.message.connect(func(id, msg): if role == "host": message.emit(id, msg))
	add_child(web)
	var err := web.start()
	if err != OK:
		stop_web()
	return err


func stop_web() -> void:
	if web:
		web.stop()
		web.queue_free()
		web = null


## Endereço da página pra quem entra pelo navegador ("" se não estiver aberta).
func web_url() -> String:
	return "http://%s:%d/" % [local_ip(), WebGateway.HTTP_PORT] if web else ""


func close() -> void:
	stop_web()
	_join_timer = null
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = ""


# --- Envio -----------------------------------------------------------------

## fast: sem garantia de entrega nem de ordem (pings do relógio, onde um atraso vale menos que uma perda).
func send_to_host(msg: Dictionary, fast := false) -> void:
	if role != "client":
		return
	msg.v = PROTOCOL_V
	if debug_lag_ms > 0:
		get_tree().create_timer(debug_lag_ms / 1000.0).timeout.connect(func():
			if role == "client":
				(_c2h_fast if fast else _c2h).rpc_id(1, msg))
		return
	if fast:
		_c2h_fast.rpc_id(1, msg)
	else:
		_c2h.rpc_id(1, msg)


func send_to(peer_id: int, msg: Dictionary, fast := false) -> void:
	if role != "host":
		return
	msg.v = PROTOCOL_V
	if web and web.has_peer(peer_id):
		web.send(peer_id, msg)
		return
	if peer_id not in multiplayer.get_peers():
		return
	if fast:
		_h2c_fast.rpc_id(peer_id, msg)
	else:
		_h2c.rpc_id(peer_id, msg)


func disconnect_peer(peer_id: int) -> void:
	if web and web.has_peer(peer_id):
		web.kick(peer_id)
		return
	if role == "host" and multiplayer.multiplayer_peer is ENetMultiplayerPeer and peer_id in multiplayer.get_peers():
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id)


# --- RPCs ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _c2h(msg: Dictionary) -> void:
	if role != "host":
		return
	message.emit(multiplayer.get_remote_sender_id(), msg)


@rpc("any_peer", "call_remote", "unreliable")
func _c2h_fast(msg: Dictionary) -> void:
	if role != "host":
		return
	message.emit(multiplayer.get_remote_sender_id(), msg)


@rpc("authority", "call_remote", "reliable")
func _h2c(msg: Dictionary) -> void:
	_from_host(msg)


@rpc("authority", "call_remote", "unreliable_ordered")
func _h2c_fast(msg: Dictionary) -> void:
	_from_host(msg)


func _from_host(msg: Dictionary) -> void:
	if debug_lag_ms > 0:
		get_tree().create_timer(debug_lag_ms / 1000.0).timeout.connect(func(): message.emit(1, msg))
	else:
		message.emit(1, msg)


# --- Eventos ---------------------------------------------------------------

func _on_connected() -> void:
	_join_timer = null
	joined.emit()


func _on_failed() -> void:
	close()
	join_failed.emit("failed")


func _on_server_lost() -> void:
	close()
	host_lost.emit()


# --- Endereços -------------------------------------------------------------

## IP deste aparelho na rede local.
## Prefere interfaces de Wi-Fi/hotspot/cabo e ignora dados móveis, VPN e redes virtuais
## (no celular, os dados móveis também usam IP privado, por isso o nome da interface importa).
static func local_ip() -> String:
	var best := ""
	var best_rank := 999
	for iface in IP.get_local_interfaces():
		var name_rank := _iface_rank(str(iface.get("name", "")))
		if name_rank < 0:
			continue
		for addr in iface.get("addresses", []):
			var r := _ip_rank(addr)
			if r >= 99:
				continue
			var rank := name_rank * 10 + r
			if rank < best_rank:
				best_rank = rank
				best = addr
	if best == "":
		for addr in IP.get_local_addresses():
			if _ip_rank(addr) < 99:
				return addr
	return best


## Menor = melhor. -1 = ignorar.
static func _iface_rank(n: String) -> int:
	n = n.to_lower()
	for bad in ["rmnet", "ccmni", "pdp", "tun", "tap", "ppp", "docker", "br-", "veth", "virbr", "tailscale", "zt", "wg", "lo", "dummy", "ipsec", "clat", "v4-"]:
		if n.begins_with(bad):
			return -1
	for good in ["wlan", "wl", "swlan", "ap", "eth", "en"]:
		if n.begins_with(good):
			return 0
	return 5


static func _ip_rank(addr: String) -> int:
	if not addr.is_valid_ip_address() or addr.contains(":"):
		return 99
	var p := addr.split(".")
	if p.size() != 4:
		return 99
	var a := int(p[0])
	var b := int(p[1])
	if a == 192 and b == 168:
		return 0
	if a == 10:
		return 1
	if a == 172 and b >= 16 and b <= 31:
		return 2
	return 99


## Endereços de broadcast pra descoberta (assume /24, o mais comum em casa e em hotspot).
static func broadcast_addresses() -> Array:
	var out := ["255.255.255.255"]
	for iface in IP.get_local_interfaces():
		if _iface_rank(str(iface.get("name", ""))) < 0:
			continue
		for addr in iface.get("addresses", []):
			if _ip_rank(addr) < 99:
				var p: PackedStringArray = addr.split(".")
				var b := "%s.%s.%s.255" % [p[0], p[1], p[2]]
				if b not in out:
					out.append(b)
	return out
