class_name QuemFoiClient
extends PartyClient
## Cliente do Quem Foi?: o PartyClient dos jogos de tema, mais o relógio acertado com o host por
## pings (net/clock_sync.gd, igual ao Halli Galli). O toque na corrida vai com a hora do host.

const PING_FAST_S := 0.1
const PING_FAST_COUNT := 12
const PING_SLOW_S := 1.0

var clock := ClockSync.new()
var _ping_timer: Timer
var _pings_sent := 0


func _init(ip: String, p_name: String, role := "player") -> void:
	super("quem_foi", ip, p_name, role)


func _ready() -> void:
	super()
	_ping_timer = Timer.new()
	_ping_timer.timeout.connect(_ping)
	add_child(_ping_timer)


func host_now_ms() -> int:
	return clock.host_now_ms()


func send(action: Dictionary) -> void:
	if action.get("type", "") == "tap":
		var a := action.duplicate()
		a.t = clock.to_host_ms(int(a.get("local_us", Time.get_ticks_usec())))
		a.erase("local_us")
		super(a)
		return
	super(action)


func _ping() -> void:
	if _reconnecting or not _welcomed:
		return
	Net.send_to_host({"type": "ping", "c": Time.get_ticks_usec(), "rtt": clock.recent_max_rtt_ms()}, true)
	_pings_sent += 1
	if _pings_sent == PING_FAST_COUNT:
		_ping_timer.start(PING_SLOW_S)


func _on_message(peer: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		"pong":
			clock.add_sample(int(msg.get("c", 0)), int(msg.get("h", 0)), Time.get_ticks_usec())
			return
		"bem_vindo":
			_pings_sent = 0
			_ping_timer.start(PING_FAST_S)
	super(peer, msg)
	if msg.get("type", "") == "bem_vindo":
		_ping()
