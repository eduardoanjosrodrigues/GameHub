class_name WebGateway
extends Node
## Deixa quem não tem o app (ex: iPhone) jogar pelo navegador, na rede local.
##
## O host abre dois servidores:
##   HTTP (porta 7780): serve a página do jogo (res://web/) e /config.json com os dados da sala.
##   WebSocket (porta 7781): cada navegador vira um "peer" com id próprio (a partir de 1.000.000),
##   e as mensagens são os mesmos dicionários do Net, em JSON. Assim as sessões dos jogos tratam
##   o navegador igual a um celular com o app.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal message(peer_id: int, msg: Dictionary)

const HTTP_PORT := 7780
const WS_PORT := 7781
const ROOT := "res://web/"
## Imagens que ficam só na pasta do jogo (uma cópia só no APK): pasta res:// -> caminho publicado.
const IMAGE_DIRS := {
	"res://games/avalon/art/roles/": "/assets/avalon/", "res://games/avalon/art/": "/assets/avalon/",
	"res://games/secret_hitler/art/roles/": "/assets/sh/", "res://games/secret_hitler/art/": "/assets/sh/",
	"res://games/quem_foi/art/": "/assets/qf/",
	"res://games/coup/art/": "/assets/coup/",
}
const FIRST_ID := 1_000_000
const HTTP_TIMEOUT_MS := 5000
const TYPES := {
	"html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
	"svg": "image/svg+xml", "wav": "audio/wav", "ttf": "font/ttf", "json": "application/json", "png": "image/png",
	"jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp",
}

## O que /config.json responde (jogo, código da sala, nome...).
var info := {}
var _http := TCPServer.new()
var _ws := TCPServer.new()
var _http_conns: Array = [] # [{stream, buf, at}]
var _peers := {} # id -> {ws: WebSocketPeer, open: bool}
var _next_id := FIRST_ID
var _files := {} # caminho publicado ("/app.js") -> caminho res://


func start() -> Error:
	_index_files(ROOT, "/")
	for dir in IMAGE_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() in ["png", "jpg", "webp"]:
				_files[IMAGE_DIRS[dir] + f] = dir + f
	var err := _http.listen(HTTP_PORT)
	if err != OK:
		return err
	err = _ws.listen(WS_PORT)
	if err != OK:
		_http.stop()
	return err


func stop() -> void:
	for id in _peers:
		_peers[id].ws.close()
	_peers.clear()
	_http_conns.clear()
	_http.stop()
	_ws.stop()


func _exit_tree() -> void:
	stop()


func has_peer(id: int) -> bool:
	return _peers.has(id) and _peers[id].open


func send(id: int, msg: Dictionary) -> void:
	if has_peer(id):
		_peers[id].ws.send_text(JSON.stringify(msg))


func kick(id: int) -> void:
	if _peers.has(id):
		_peers[id].ws.close()


func _index_files(dir: String, published: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		_files[published + f] = dir + f
	for d in DirAccess.get_directories_at(dir):
		_index_files(dir + d + "/", published + d + "/")


func _process(_delta: float) -> void:
	_poll_http()
	_poll_ws()


# --- HTTP ------------------------------------------------------------------

func _poll_http() -> void:
	while _http.is_connection_available():
		_http_conns.append({"stream": _http.take_connection(), "buf": PackedByteArray(), "at": Time.get_ticks_msec()})
	var now := Time.get_ticks_msec()
	for c in _http_conns.duplicate():
		var s: StreamPeerTCP = c.stream
		s.poll()
		if s.get_status() != StreamPeerTCP.STATUS_CONNECTED or now - int(c.at) > HTTP_TIMEOUT_MS:
			_http_conns.erase(c)
			continue
		var n := s.get_available_bytes()
		if n > 0:
			var got: Array = s.get_partial_data(n)
			if got[0] == OK:
				c.buf.append_array(got[1])
		var text: String = c.buf.get_string_from_utf8()
		if text.contains("\r\n\r\n") or c.buf.size() > 16384:
			_answer(s, text)
			s.disconnect_from_host()
			_http_conns.erase(c)


func _answer(s: StreamPeerTCP, request: String) -> void:
	var line := request.get_slice("\r\n", 0).split(" ")
	if line.size() < 2 or line[0] != "GET":
		_respond(s, 405, "text/plain", "Método não permitido".to_utf8_buffer())
		return
	var path: String = line[1].get_slice("?", 0).uri_decode()
	if path == "/":
		path = "/index.html"
	if path == "/config.json":
		var cfg := info.duplicate()
		cfg.ws_port = WS_PORT
		_respond(s, 200, TYPES.json, JSON.stringify(cfg).to_utf8_buffer(), false)
		return
	if path == "/qr.svg":
		# QR pro tabuleiro do navegador ("Trocar aparelho"): a página não tem gerador de QR.
		var text := ""
		for part in line[1].get_slice("?", 1).split("&"):
			if part.begins_with("d="):
				text = part.substr(2).uri_decode()
		_respond(s, 200, TYPES.svg, _qr_svg(text).to_utf8_buffer(), false)
		return
	if not _files.has(path):
		_respond(s, 404, "text/plain", "Não encontrado".to_utf8_buffer())
		return
	var body := FileAccess.get_file_as_bytes(_files[path])
	var ext := path.get_extension()
	# Página e scripts sempre frescos (mudam a cada versão); o resto pode ficar em cache.
	_respond(s, 200, TYPES.get(ext, "application/octet-stream"), body, ext not in ["html", "js", "css"])


static func _qr_svg(text: String) -> String:
	var qr := QrCode.encode(text)
	if qr == null or text == "":
		return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>'
	var n := qr.size + 8
	var out := PackedStringArray(['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" shape-rendering="crispEdges"><rect width="%d" height="%d" fill="#fff"/><path fill="#1F1D1A" d="' % [n, n, n, n]])
	for y in qr.size:
		for x in qr.size:
			if qr.is_dark(y, x):
				out.append("M%d %dh1v1h-1z" % [x + 4, y + 4])
	out.append('"/></svg>')
	return "".join(out)


func _respond(s: StreamPeerTCP, code: int, type: String, body: PackedByteArray, cache := false) -> void:
	var status: String = {200: "OK", 404: "Not Found", 405: "Method Not Allowed"}.get(code, "OK")
	var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: %s\r\nConnection: close\r\n\r\n" % [
		code, status, type, body.size(), "max-age=3600" if cache else "no-cache"]
	s.put_data(head.to_utf8_buffer())
	s.put_data(body)


# --- WebSocket -------------------------------------------------------------

func _poll_ws() -> void:
	while _ws.is_connection_available():
		var p := WebSocketPeer.new()
		if p.accept_stream(_ws.take_connection()) == OK:
			_peers[_next_id] = {"ws": p, "open": false}
			_next_id += 1
	for id in _peers.keys():
		var e: Dictionary = _peers[id]
		var p: WebSocketPeer = e.ws
		p.poll()
		match p.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not e.open:
					e.open = true
					peer_joined.emit(id)
				while p.get_available_packet_count() > 0:
					var data = JSON.parse_string(p.get_packet().get_string_from_utf8())
					if data is Dictionary:
						message.emit(id, data)
			WebSocketPeer.STATE_CLOSED:
				var was_open: bool = e.open
				_peers.erase(id)
				if was_open:
					peer_left.emit(id)
