extends Node
## Ferramenta de teste: robôs jogando a Corrida do Genius pela rede local (docs/PLANO_GENIUS.md §5).
##   godot --headless -- --gbot=host --bot-name=Host --bot-players=4 --bot-fail=2
##   godot --headless -- --gbot=client --bot-name=Bia --bot-fail=2,3 [--bot-drop] [--bot-lag=80]
## --bot-fail: rodadas em que o robô erra na primeira tentativa (numa rodada repetida ele acerta).
## Cada robô espera a sequência tocar (pelo relógio do host) e repete. Imprime "BOT <nome>: ...".

var mode := ""
var bot_name := "Bot"
var players := 4
var fail_rounds: Array = []
var drop := false
var lag := 0
var session: PartySession
var _deadline := 0
var _dropped := false
var _acted := ""
var _tried := {} # rodada -> já tentou (a repetição acerta)
var _repeats := 0


static func start(main: Node) -> void:
	var b = load("res://tools/genius_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a.begins_with("--bot-fail="):
			b.fail_rounds = Array(a.substr(11).split(",")).map(func(x): return int(x))
		elif a.begins_with("--bot-lag="):
			b.lag = int(a.substr(10))
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
	Net.debug_lag_ms = lag
	_deadline = Time.get_ticks_msec() + int(OS.get_environment("BOT_DEADLINE_MS") if OS.get_environment("BOT_DEADLINE_MS") != "" else "150000")
	if mode == "host":
		var h := GeniusHost.new(bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c := GeniusClient.new("127.0.0.1", bot_name)
		session = c
		add_child(c)
		c.connect_to_host()
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): _log("erro: " + m))
	session.ended.connect(func(r):
		_log("ENCERRADO: " + r)
		get_tree().quit(1))


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		_log("TIMEOUT fase=%s" % session.view.get("phase", "?"))
		get_tree().quit(2)


func _host_now() -> int:
	if session is PartyClockClient:
		return (session as PartyClockClient).host_now_ms()
	return Time.get_ticks_msec()


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		if e.type in ["round_result", "game_over", "player_connection", "forfeit"]:
			_log("evento %s" % JSON.stringify(e))
		if e.type == "round_result" and e.repeat:
			_repeats += 1
	if v.phase == "game_over":
		var rk: Array = v.ranking.map(func(r): return "%d:%s" % [int(r.pos), _name(v, r.id)])
		_log("FIM ranking=%s repeticoes=%d" % [",".join(rk), _repeats])
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	var key := "%s|%d|%d|%d" % [v.phase, int(v.round_no), int(v.round_at), v.players.size()]
	if key == _acted:
		return
	_acted = key
	_act.call_deferred(v)


func _name(v: Dictionary, id: String) -> String:
	for p in v.players:
		if p.id == id:
			return p.name
	return "?"


func _wait(ms: int) -> void:
	await get_tree().create_timer(maxf(0.0, ms / 1000.0)).timeout


func _act(v: Dictionary) -> void:
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				# Dá tempo dos relógios acertarem.
				await _wait(2500)
				if session.view.get("phase", "") != "lobby":
					return
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"round":
			var me: String = v.you
			if me not in v.alive or str(v.mine) != "":
				return
			var round_no := int(v.round_no)
			if drop and not _dropped and round_no >= 3:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await _wait(2000)
				(session as PartyClient).connect_to_host()
				# Na volta chega o mesmo estado: tem que agir de novo.
				_acted = ""
				return
			# O relógio do host diz quando a sequência acabou de tocar em todo aparelho.
			while _host_now() < int(v.input_at):
				await get_tree().process_frame
			var fail: bool = round_no in fail_rounds and not _tried.has(round_no)
			_tried[round_no] = true
			var seq: Array = v.seq
			for i in range(int(v.progress), seq.size()):
				if session.view.get("round_at", -1) != v.round_at or session.view.get("phase", "") != "round":
					return
				var c: int = int(seq[i])
				if fail and i == seq.size() - 1:
					c = (c + 1) % GeniusRules.COLORS
				session.send({"type": "press", "color": c, "i": i})
				await _wait(40)
