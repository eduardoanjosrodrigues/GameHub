class_name HalliBot
extends Node
## Ferramenta de teste: robôs jogando Halli Galli pela rede local, com atraso artificial por robô
## (docs/PLANO_HALLI_GALLI.md, marco H4). Uso (um processo por robô):
##   godot --headless -- --hbot=host --bot-name=Host --bot-players=4 --bot-earliest=Bia
##   godot --headless -- --hbot=client --bot-name=Bia --bot-lag=200 --bot-offset=0 [--bot-drop]
##
## Toda vez que a mesa tem 5 frutas iguais, o host marca um instante T no relógio dele e manda cada
## robô bater o sino em T + offset. Quem tem o menor offset tocou primeiro e tem que ganhar,
## mesmo que o atraso de rede dele seja o maior. Imprime "BOT <nome>: ..." pra conferir.

const BELLS_TO_JUDGE := 6
const RING_AFTER_MS := 350

var mode := ""
var bot_name := "Bot"
var lag := 0
var offset := 0
var players := 4
var drop := false
var session: HalliSession
var _deadline := 0
var _judged := 0
var _fair := 0
var _expected := ""
var _dropped := false
var _flip_busy := false


static func start(main: Node) -> void:
	var b := HalliBot.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-lag="):
			b.lag = int(a.substr(10))
		elif a.begins_with("--bot-offset="):
			b.offset = int(a.substr(13))
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a == "--bot-drop":
			b.drop = true
	main.add_child(b)
	b._begin.call_deferred()


func _log(msg: String) -> void:
	print("BOT %s: %s" % [bot_name, msg])


func _begin() -> void:
	Settings.device_id = "bot-" + bot_name
	Settings.music_volume = 0.0
	Settings.sfx_volume = 0.0
	History.persist = false
	_deadline = Time.get_ticks_msec() + 150000
	if mode == "host":
		var h := HalliHost.new(bot_name)
		session = h
		add_child(h)
		var err := h.open_room()
		if err != "":
			_log("ERRO ao abrir sala: " + err)
			get_tree().quit(1)
			return
		_log("sala aberta, código %s" % h.room_code)
	else:
		Net.debug_lag_ms = lag
		var c := HalliClient.new("127.0.0.1", bot_name)
		session = c
		add_child(c)
		c.connect_to_host()
		Net.message.connect(_on_debug_message)
	session.view_changed.connect(_on_view)
	session.ended.connect(func(r):
		_log("ENCERRADO: " + r)
		get_tree().quit(1))
	session.connection_changed.connect(func(s): _log("conexão: " + s))


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		_log("TIMEOUT")
		get_tree().quit(2)
	if session == null or session.view.is_empty():
		return
	var v := session.view
	if v.phase == HalliRules.PHASE_PLAYING and not v.paused and v.turn == v.you and not _flip_busy:
		if session.now_ms() >= int(v.next_flip_at) + 50:
			_flip_busy = true
			session.send({"type": "flip"})
			get_tree().create_timer(0.4).timeout.connect(func(): _flip_busy = false)


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		match e.type:
			"player_connection", "paused", "resumed", "game_over":
				_log("evento %s" % JSON.stringify(e))
				if e.type == "paused":
					_expected = "" # sinos marcados antes da pausa não chegam a ser julgados
			"bell":
				if session.is_host:
					_judge(e)
			"flip":
				if session.is_host:
					_maybe_schedule()
	if session.is_host and v.phase == HalliRules.PHASE_LOBBY and v.players.size() >= players and v.players.all(func(p): return p.connected):
		_log("começando com %d jogadores" % v.players.size())
		session.send({"type": "start"})
	if drop and not _dropped and not session.is_host and v.phase == HalliRules.PHASE_PLAYING and _judged_seen(v) >= 2:
		_dropped = true
		_log("derrubando a própria conexão")
		Net.close()
		get_tree().create_timer(2.0).timeout.connect(func(): (session as HalliClient).connect_to_host())


func _judged_seen(v: Dictionary) -> int:
	var n := 0
	for p in v.players:
		n += int(p.ok) + int(p.wrong)
	return n


# --- Host: marca o instante do sino e confere quem ganhou -------------------

func _maybe_schedule() -> void:
	var h := session as HalliHost
	var r := h.rules
	if r.phase != HalliRules.PHASE_PLAYING or r.paused or _expected != "":
		return
	if HalliRules.five_fruit(r.table_at(h.now_ms())) < 0:
		return
	var at := h.now_ms() + RING_AFTER_MS
	_expected = "?"
	for pid in h._peers:
		Net.send_to(pid, {"type": "bot_ring", "at": at})


func _judge(e: Dictionary) -> void:
	if _expected == "":
		return
	_expected = ""
	if not e.ok:
		_log("ERRO: sino errado no teste (%s)" % JSON.stringify(e))
		return
	var r := (session as HalliHost).rules
	var winner := r.player(e.player)
	_judged += 1
	# O robô que devia ganhar é o de menor offset (o nome vem no id "bot-<nome>").
	var want := "bot-" + _earliest_name()
	if e.player == want:
		_fair += 1
		_log("JUSTO %d: %s ganhou por %d ms (janela %d ms)" % [_judged, winner.name, int(e.margin_ms), (session as HalliHost).window_ms()])
	else:
		_log("ERRO: %s ganhou, mas quem tocou primeiro foi %s" % [winner.name, want])
	if _judged >= BELLS_TO_JUDGE:
		_log("FIM justos=%d/%d" % [_fair, _judged])
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if _fair == _judged else 1)


static func _earliest_name() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-earliest="):
			return a.substr(15)
	return ""


# --- Cliente: bate o sino no instante marcado ------------------------------

func _on_debug_message(_peer: int, msg: Dictionary) -> void:
	if msg.get("type", "") != "bot_ring":
		return
	var c := session as HalliClient
	var target := int(msg.at) + offset
	while c.clock.host_now_ms() < target:
		await get_tree().process_frame
	session.send({"type": "bell", "local_us": Time.get_ticks_usec()})
