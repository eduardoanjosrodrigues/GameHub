class_name ClientSession
extends ChapeuSession
## Wi-Fi, este aparelho entrou na sala de outro. Manda intenções e recebe o estado.

const RECONNECT_EVERY_S := 2.0
const RECONNECT_FOR_S := 60.0

var host_ip := ""
var player_name := ""
## Token do QR de troca de aparelho: entra na vaga de alguém que já está na partida.
var seat_token := ""
var _welcomed := false
var _reconnecting := false
var _reconnect_started := 0
var _retry_timer: Timer


## role: "player" ou "board".
func _init(ip: String, p_name: String, role := "player") -> void:
	mode = "wifi"
	is_host = false
	host_ip = ip
	player_name = p_name
	local_role = role


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


func connect_to_host() -> void:
	var err := Net.join(host_ip)
	if err != OK:
		_on_join_failed("create")


## Tabuleiro: pede ao host o QR pra passar a vaga de alguém pra outro aparelho.
func request_seat(seat: String) -> void:
	Net.send_to_host({"type": "pedir_vaga", "id": seat})


func send(action: Dictionary) -> void:
	if _reconnecting:
		error.emit("Reconectando ao host...")
		return
	Net.send_to_host({"type": "acao", "action": action})


func leave() -> void:
	_reconnecting = false
	Net.close()
	queue_free()


func _on_joined() -> void:
	Net.send_to_host({"type": "hello", "device": Settings.device_id, "nome": player_name, "papel": local_role, "vaga": seat_token})


func _on_join_failed(_reason: String) -> void:
	if _reconnecting:
		_schedule_retry()
	else:
		ended.emit("Não consegui entrar na sala. Confira se vocês estão no mesmo Wi-Fi.")


func _on_host_lost() -> void:
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
	if not _reconnecting:
		return
	Net.join(host_ip)


func _on_message(_peer: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
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
		"tempo":
			if view.has("time_ms"):
				view.time_ms = int(msg.get("ms", 0))
				time_changed.emit(view.time_ms)
		"erro":
			var code: String = msg.get("codigo", "")
			var text: String = msg.get("mensagem", "Erro.")
			if code in ["versao", "partida_em_andamento", "cheia", "invalido", "outro_jogo", "vaga_passada", "vaga_invalida"]:
				_welcomed = false
				ended.emit(text)
			else:
				error.emit(text)
