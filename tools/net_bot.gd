class_name NetBot
extends Node
## Ferramenta de teste: um jogador robô que joga uma partida inteira pela rede local.
## Uso (um processo por jogador):
##   godot --headless -- --bot=host --bot-name=Host
##   godot --headless -- --bot=client --bot-name=Bia --bot-team=vermelho [--bot-drop] [--bot-late]
## Imprime linhas "BOT <nome>: ..." pra conferir o resultado.

var mode := ""
var bot_name := "Bot"
var team := "azul"
var drop := false
var late := false
var session: ChapeuSession
var _busy := false
var _dropped := false
var _deadline := 0


static func requested() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			return true
	return false


static func start(main: Node) -> void:
	var b := NetBot.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			b.mode = a.substr(6)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-team="):
			b.team = a.substr(11)
		elif a == "--bot-drop":
			b.drop = true
		elif a == "--bot-late":
			b.late = true
	main.add_child(b)
	b._begin.call_deferred()


func _log(msg: String) -> void:
	print("BOT %s: %s" % [bot_name, msg])


func _begin() -> void:
	Settings.device_id = "bot-" + bot_name
	Settings.music_volume = 0.0
	Settings.sfx_volume = 0.0
	_deadline = Time.get_ticks_msec() + 120000
	if mode == "scan":
		var sc := LanDiscovery.scanner()
		add_child(sc)
		sc.rooms_changed.connect(func(rooms):
			for r in rooms:
				_log("SALA ACHADA %s em %s código %s (decodifica pra %s)" % [r.get("nome"), r.ip, r.get("codigo"), RoomCode.decode(str(r.get("codigo")))])
			if not rooms.is_empty():
				get_tree().quit(0))
		return
	if mode == "host":
		var h := HostSession.new("player", bot_name)
		session = h
		add_child(h)
		var err := h.open_room()
		if err != "":
			_log("ERRO ao abrir sala: " + err)
			get_tree().quit(1)
			return
		_log("sala aberta, código %s" % h.room_code)
	else:
		var c := ClientSession.new("127.0.0.1", bot_name)
		session = c
		add_child(c)
		c.connect_to_host()
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): _log("erro: " + m))
	session.ended.connect(func(r):
		_log("ENCERRADO: " + r)
		get_tree().quit(0 if late else 1))
	session.connection_changed.connect(func(s): _log("conexão: " + s))


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		_log("TIMEOUT")
		get_tree().quit(2)


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		if e.type in ["player_joined", "player_connection", "game_over"]:
			_log("evento %s %s" % [e.type, JSON.stringify(e)])
	if late:
		_log("ERRO: entrou atrasado e recebeu estado (%s)" % v.phase)
		return
	_act.call_deferred(v)


func _act(v: Dictionary) -> void:
	var me: Dictionary = {}
	for p in v.players:
		if p.id == v.you:
			me = p
	match v.phase:
		"lobby":
			if not me.is_empty() and me.team != team:
				session.send({"type": "set_team", "team": team})
			if session.is_host and v.can_start == "" and v.players.size() >= 4:
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "set_config", "words_per_player": 3})
				session.send({"type": "start"})
		"writing":
			if v.you not in v.submitted:
				var words := []
				for i in int(v.config.words_per_player):
					words.append("%s palavra %d" % [bot_name, i + 1])
				session.send({"type": "submit_words", "words": words})
		"round_intro", "round_end":
			if session.is_host:
				await get_tree().create_timer(0.2).timeout
				session.send({"type": "next"})
		"turn_ready":
			if v.explainer == "" and not me.is_empty() and me.team == v.team_turn:
				session.send({"type": "choose_explainer", "id": v.you})
			elif v.explainer == v.you:
				session.send({"type": "start_turn"})
		"turn":
			if v.explainer == v.you and not _busy:
				if v.paused:
					session.send({"type": "resume"})
					return
				if v.word == "":
					_log("ERRO: explicador sem palavra")
					return
				_busy = true
				await get_tree().create_timer(0.15).timeout
				_busy = false
				session.send({"type": "skip" if randf() < 0.15 else "hit"})
			elif v.explainer != v.you and v.word != "" and not v.config.opponent_sees_word:
				_log("ERRO: vi a palavra sem ser o explicador")
		"turn_summary":
			if drop and not _dropped and not session.is_host:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await get_tree().create_timer(1.5).timeout
				(session as ClientSession).connect_to_host()
				return
			if session.is_host or v.explainer == v.you:
				await get_tree().create_timer(0.1).timeout
				session.send({"type": "next"})
		"game_over":
			_log("FIM vencedor=%s critério=%s placar=%s" % [v.result.winner, v.result.criterion, JSON.stringify(v.result.totals)])
			await get_tree().create_timer(1.0).timeout
			get_tree().quit(0)
