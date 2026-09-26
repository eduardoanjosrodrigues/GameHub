class_name HalliClient
extends HalliSession
## Wi-Fi, este aparelho entrou na sala de outro. Sincroniza o relógio com o host por pings,
## carimba cada virada e cada sino no relógio do host e recebe o estado.

const RECONNECT_EVERY_S := 2.0
const RECONNECT_FOR_S := 60.0
## Logo depois de entrar, pings rápidos pro relógio ficar bom em ~1 s; depois, um por segundo.
const PING_FAST_S := 0.1
const PING_FAST_COUNT := 12
const PING_SLOW_S := 1.0
const WEAK_RTT_MS := 150

var host_ip := ""
var player_name := ""
## Token do QR de troca de aparelho: entra na vaga de alguém que já está na partida.
var seat_token := ""
var clock := ClockSync.new()
var _welcomed := false
var _reconnecting := false
var _reconnect_started := 0
var _retry_timer: Timer
var _ping_timer: Timer
var _pings_sent := 0


func _init(ip: String, p_name: String) -> void:
	mode = "wifi"
	is_host = false
	host_ip = ip
	player_name = p_name


func _ready() -> void:
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.host_lost.connect(_on_host_lost)
	Net.message.connect(_on_message)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = RECONNECT_EVERY_S
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_retry)
	add_child(_retry_timer)
	_ping_timer = Timer.new()
	_ping_timer.timeout.connect(_ping)
	add_child(_ping_timer)


func connect_to_host() -> void:
	if Net.join(host_ip) != OK:
		_on_join_failed("create")


func now_ms() -> int:
	return clock.host_now_ms()


func weak_signal() -> bool:
	return clock.synced() and clock.last_rtt_ms() > WEAK_RTT_MS


## Tabuleiro: pede ao host o QR pra passar a vaga de alguém pra outro aparelho.
func request_seat(seat: String) -> void:
	Net.send_to_host({"type": "pedir_vaga", "id": seat})


func send(action: Dictionary) -> void:
	if _reconnecting:
		error.emit("Reconectando ao host...")
		return
	var a := action.duplicate()
	match a.get("type", ""):
		"flip":
			a.t = now_ms()
		"bell":
			a.t = clock.to_host_ms(int(a.get("local_us", Time.get_ticks_usec())))
			a.erase("local_us")
	Net.send_to_host({"type": "acao", "action": a})


func leave() -> void:
	_reconnecting = false
	Net.close()
	queue_free()


func _on_joined() -> void:
	Net.send_to_host({"type": "hello", "jogo": GAME_ID, "device": Settings.device_id, "nome": player_name, "vaga": seat_token})
	_pings_sent = 0
	_ping_timer.start(PING_FAST_S)
	_ping()


func _ping() -> void:
	if Net.role != "client":
		return
	Net.send_to_host({"type": "ping", "c": Time.get_ticks_usec(), "rtt": clock.recent_max_rtt_ms()}, true)
	_pings_sent += 1
	if _pings_sent == PING_FAST_COUNT:
		_ping_timer.start(PING_SLOW_S)


func _on_join_failed(_reason: String) -> void:
	if _reconnecting:
		_schedule_retry()
	else:
		ended.emit("Não consegui entrar na sala. Confira se vocês estão no mesmo Wi-Fi.")


func _on_host_lost() -> void:
	_ping_timer.stop()
	if not _welcomed:
		ended.emit("A conexão com o host caiu.")
		return
	_reconnecting = true
	_reconnect_started = Time.get_ticks_msec()
	connection_changed.emit("reconnecting")
	_schedule_retry()


func _schedule_retry() -> void:
	if Time.get_ticks_msec() - _reconnect_started > RECONNECT_FOR_S * 1000:
		_reconnecting = false
		connection_changed.emit("lost")
		ended.emit("Não deu pra reconectar ao host.")
		return
	_retry_timer.start()


func _retry() -> void:
	if _reconnecting:
		Net.join(host_ip)


func _on_message(_peer: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"pong":
			clock.add_sample(int(msg.get("c", 0)), int(msg.get("h", 0)), Time.get_ticks_usec())
		"vaga":
			seat_link.emit(str(msg.get("id", "")), str(msg.get("token", "")))
		"bem_vindo":
			_welcomed = true
			local_id = msg.get("id", "")
			room_code = msg.get("codigo", "")
			if _reconnecting:
				_reconnecting = false
				connection_changed.emit("connected")
		"estado":
			var v: Dictionary = msg.get("view", {})
			v.room_code = room_code
			v.host_ip = host_ip
			_emit_view(v, msg.get("events", []))
		"erro":
			var code: String = msg.get("codigo", "")
			var text: String = msg.get("mensagem", "Erro.")
			if code in ["versao", "partida_em_andamento", "cheia", "invalido", "outro_jogo", "vaga_passada", "vaga_invalida"]:
				_welcomed = false
				ended.emit(text)
			elif code == "acao":
				rejected.emit(text)
			else:
				error.emit(text)
