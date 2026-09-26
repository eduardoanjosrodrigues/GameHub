class_name AvalonBot
extends Node
## Ferramenta de teste: robôs jogando Avalon pela rede local (docs/PLANO_AVALON.md, marco A2).
##   godot --headless -- --abot=host --bot-name=Host --bot-players=5
##   godot --headless -- --abot=client --bot-name=Bia [--bot-board] [--bot-drop] [--bot-die]
##       [--bot-swapper] [--bot-seat=<token>]
## --bot-die: some de vez no meio (bateria acabou). --bot-swapper (host ou tabuleiro): abre o QR de
## "Trocar aparelho" pra quem sumiu e imprime "VAGA <id> <token>". --bot-seat: entra por esse QR.
## Cada robô joga sozinho e confere que só recebe o que pode ver. Imprime "BOT <nome>: ...".

var mode := ""
var bot_name := "Bot"
var players := 5
var board := false
var drop := false
var die := false
var swapper := false
var seat_token := ""
var _swapped := {}
var session: AvalonSession
var _deadline := 0
var _dropped := false
var _acted := ""
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b := AvalonBot.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--abot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a == "--bot-board":
			b.board = true
		elif a == "--bot-drop":
			b.drop = true
		elif a == "--bot-die":
			b.die = true
		elif a == "--bot-swapper":
			b.swapper = true
		elif a.begins_with("--bot-seat="):
			b.seat_token = a.substr(11)
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
	_deadline = Time.get_ticks_msec() + int(OS.get_environment("BOT_DEADLINE_MS") if OS.get_environment("BOT_DEADLINE_MS") != "" else "120000")
	if mode == "host":
		var h := AvalonHost.new("player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c := AvalonClient.new("127.0.0.1", bot_name, "board" if board else "player")
		c.seat_token = seat_token
		session = c
		add_child(c)
		c.connect_to_host()
	session.view_changed.connect(_on_view)
	session.seat_link.connect(func(id, token): _log("VAGA %s %s" % [id, token]))
	session.error.connect(func(m): _log("erro: " + m))
	session.ended.connect(func(r):
		_log("ENCERRADO: " + r)
		get_tree().quit(1))


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		_log("TIMEOUT fase=%s" % session.view.get("phase", "?"))
		get_tree().quit(2)


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		if e.type in ["game_over", "player_connection"]:
			_log("evento %s" % JSON.stringify(e))
	_check(v)
	if swapper and v.phase != "lobby":
		for p in v.players:
			if not p.connected and not _swapped.has(p.id):
				_swapped[p.id] = true
				_log("pedindo QR pra vaga de %s" % p.name)
				session.request_seat(p.id)
	if v.phase == "game_over":
		_log("FIM vencedor=%s motivo=%s" % [v.winner, v.win_reason])
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	# Uma ação por estado (o estado muda a cada ação de alguém).
	var key := "%s|%s|%s|%d|%d|%d|%d|%d" % [v.phase, v.leader, v.team, v.voted.size(), v.played.size(), v.players.size(), v.ready.size(), v.results.size()]
	if key == _acted:
		return
	_acted = key
	_act.call_deferred(v)


## O que este aparelho recebe tem que bater com o que ele pode saber.
func _check(v: Dictionary) -> void:
	if board and (v.role != "" or not v.knows.is_empty()):
		_log("ERRO: tabuleiro recebeu papel")
	if v.phase != "game_over" and not v.all_roles.is_empty():
		_log("ERRO: papéis revelados antes do fim")
	if v.role == "servo" and not v.knows.is_empty():
		_log("ERRO: servo sabe de alguém")
	if not board and v.phase not in ["lobby"] and v.role == "":
		_log("ERRO: jogador sem papel")


func _act(v: Dictionary) -> void:
	if board:
		if v.phase in ["vote_result", "quest_result"] and rng.randf() < 0.5 and OS.get_environment("BOT_CONTINUE_MS") == "":
			await get_tree().create_timer(0.1).timeout
			session.send({"type": "continue"})
		return
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "set_config", "toggle": "percival"})
				session.send({"type": "start"})
		"reveal":
			if v.you not in v.ready:
				session.send({"type": "ready"})
		"team":
			if v.leader == v.you:
				var need: int = v.quest_sizes[v.quest]
				var t: Array = [v.you]
				for p in v.players:
					if t.size() < need and p.id != v.you:
						t.append(p.id)
				session.send({"type": "select_team", "ids": t})
				session.send({"type": "propose"})
		"vote":
			if v.my_vote == null:
				if die and int(v.quest) >= 1:
					_log("morrendo (bateria acabou)")
					Net.close()
					get_tree().quit(0)
					return
				if drop and not _dropped and int(v.quest) >= 1:
					_dropped = true
					_log("derrubando a própria conexão")
					Net.close()
					await get_tree().create_timer(2.0).timeout
					(session as AvalonClient).connect_to_host()
					return
				session.send({"type": "vote", "approve": rng.randf() < 0.75})
		"vote_result", "quest_result":
			if session.is_host:
				# BOT_CONTINUE_MS deixa a partida mais lenta (tempo pra outro aparelho entrar no meio).
				var wait_ms := int(OS.get_environment("BOT_CONTINUE_MS")) if OS.get_environment("BOT_CONTINUE_MS") != "" else 100
				await get_tree().create_timer(wait_ms / 1000.0).timeout
				session.send({"type": "continue"})
		"quest":
			if v.you in v.team and v.my_card == null:
				var fail: bool = v.evil and rng.randf() < 0.6
				if not v.evil:
					# O bem tentando falhar tem que ser recusado.
					session.send({"type": "quest_card", "success": false})
				session.send({"type": "quest_card", "success": not fail})
		"assassin":
			if v.role == "assassino":
				var evil_ids: Array = v.evil_team.map(func(e): return e.id)
				var targets: Array = v.players.filter(func(p): return p.id not in evil_ids)
				session.send({"type": "assassinate", "id": targets[rng.randi() % targets.size()].id})
