extends Node
## Ferramenta de teste: robôs jogando Quem Foi? pela rede local, com atraso artificial por robô
## (docs/PLANO_QUEM_FOI.md, marco Q2). Uso (um processo por robô):
##   godot --headless -- --qbot=host --bot-name=Host --bot-players=4 --bot-order=Bia,Caio,Duda
##   godot --headless -- --qbot=client --bot-name=Bia --bot-lag=200 --bot-offset=0 [--bot-drop] [--bot-board]
##
## Em cada corrida, quem tem o bicho toca em T + offset (T = início da corrida + RACE_AFTER_MS, no
## relógio do host). Quem tem o menor offset tocou primeiro e tem que ganhar, mesmo com a pior
## rede. O host confere cada corrida pela ordem --bot-order. Imprime "BOT <nome>: ...".

const RACE_AFTER_MS := 350
## O host joga mais devagar que todos, pra não atrapalhar a conta da justiça.
const HOST_OFFSET_MS := 600

var mode := ""
var bot_name := "Bot"
var lag := 0
var offset := 0
var players := 4
var board := false
var drop := false
var order: Array = []
var session: PartySession
var _deadline := 0
var _dropped := false
var _acted := ""
var _expected := ""
var _judged := 0
var _fair := 0
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b = load("res://tools/quem_foi_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-lag="):
			b.lag = int(a.substr(10))
		elif a.begins_with("--bot-offset="):
			b.offset = int(a.substr(13))
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a.begins_with("--bot-order="):
			b.order = Array(a.substr(12).split(","))
		elif a == "--bot-board":
			b.board = true
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
	rng.seed = hash(bot_name)
	Net.debug_lag_ms = lag
	_deadline = Time.get_ticks_msec() + int(OS.get_environment("BOT_DEADLINE_MS") if OS.get_environment("BOT_DEADLINE_MS") != "" else "150000")
	if mode == "host":
		offset = HOST_OFFSET_MS
		var h := QuemFoiHost.new("player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c := QuemFoiClient.new("127.0.0.1", bot_name, "board" if board else "player")
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
	if session is QuemFoiClient:
		return (session as QuemFoiClient).host_now_ms()
	return Time.get_ticks_msec()


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		if e.type in ["guilty", "game_over", "player_connection"]:
			_log("evento %s" % JSON.stringify(e))
		if session.is_host:
			_judge(e)
	_check(v)
	if v.phase == "game_over":
		if session.is_host:
			_log("FIM justos=%d/%d" % [_fair, _judged])
		else:
			_log("FIM")
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	var key := "%s|%d|%d|%s|%d" % [v.phase, int(v.round_no), int(v.race_no), v.accuser, v.players.size()]
	if key == _acted:
		return
	_acted = key
	_act.call_deferred(v)


## Host: quem devia ganhar cada corrida (o primeiro da ordem que tem o bicho).
func _judge(e: Dictionary) -> void:
	var r: QuemFoiRules = (session as QuemFoiHost).rules
	match e.type:
		"accused":
			_expected = ""
			var racers := r.racers()
			for n in order + [bot_name]:
				if "bot-" + n in racers:
					_expected = "bot-" + n
					break
		"won_race":
			if _expected == "":
				return
			_judged += 1
			if e.id == _expected:
				_fair += 1
				_log("JUSTO %d: %s ganhou (janela %d ms)" % [_judged, r.player(e.id).name, (session as QuemFoiHost).window_ms()])
			else:
				_log("ERRO: corrida %d ganha por %s, devia ser %s" % [_judged, r.player(e.id).name, r.player(_expected).name])


## O que este aparelho recebe tem que bater com o que ele pode saber.
func _check(v: Dictionary) -> void:
	if board and not v.hand.is_empty():
		_log("ERRO: tabuleiro recebeu uma mão")
	if v.has("hands"):
		_log("ERRO: recebeu as mãos de todos")
	if v.phase not in ["round_end", "game_over"] and not v.last.is_empty():
		_log("ERRO: viu as mãos antes do fim da rodada")
	if not v.config.memory_help and not v.played.is_empty():
		_log("ERRO: ajuda de memória sem estar ligada")


func _wait(ms: int) -> void:
	await get_tree().create_timer(maxf(0.0, ms / 1000.0)).timeout


func _act(v: Dictionary) -> void:
	var wait := int(OS.get_environment("BOT_CONTINUE_MS")) if OS.get_environment("BOT_CONTINUE_MS") != "" else 60
	if board:
		if v.phase == "round_end" and rng.randf() < 0.3:
			await _wait(wait + 300)
			session.send({"type": "continue"})
		return
	var me: String = v.you
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				# Dá tempo dos relógios acertarem, como numa mesa de verdade.
				await _wait(3000)
				if session.view.get("phase", "") != "lobby":
					return
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"accuse":
			if v.accuser != me:
				return
			if drop and not _dropped and int(v.round_no) >= 2:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await _wait(2000)
				(session as PartyClient).connect_to_host()
				# Na volta chega o mesmo estado: tem que agir de novo.
				_acted = ""
				return
			await _wait(150)
			var a := {"type": "accuse", "animal": v.animals[rng.randi() % v.animals.size()]}
			if v.top.is_empty():
				a.play = v.hand[rng.randi() % v.hand.size()]
			session.send(a)
		"race":
			if v.accuser == me or v.accused not in v.hand:
				return
			# Toca em T + offset, no relógio do host.
			var at: int = int(v.race_at) + RACE_AFTER_MS + offset
			while _host_now() < at:
				await get_tree().process_frame
			if session.view.get("race_no", -1) != v.race_no or session.view.get("phase", "") != "race":
				return
			session.send({"type": "tap", "animal": v.accused, "local_us": Time.get_ticks_usec()})
		"round_end":
			if session.is_host:
				await _wait(wait)
				session.send({"type": "continue"})
