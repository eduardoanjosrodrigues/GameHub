extends Node
## Ferramenta de teste: robôs jogando Secret Hitler pela rede local (docs/PLANO_SECRET_HITLER.md, marco S2).
##   godot --headless -- --sbot=host --bot-name=Host --bot-players=7
##   godot --headless -- --sbot=client --bot-name=Bia [--bot-board] [--bot-drop]
## Cada robô joga sozinho e confere que só recebe o que pode ver. Imprime "BOT <nome>: ...".

var mode := ""
var bot_name := "Bot"
var players := 7
var board := false
var drop := false
var session: ShSession
var _deadline := 0
var _dropped := false
var _acted := ""
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b = load("res://tools/sh_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
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
	_deadline = Time.get_ticks_msec() + int(OS.get_environment("BOT_DEADLINE_MS") if OS.get_environment("BOT_DEADLINE_MS") != "" else "150000")
	if mode == "host":
		var h := ShHost.new("player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c := ShClient.new("127.0.0.1", bot_name, "board" if board else "player")
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


func _on_view(v: Dictionary, events: Array) -> void:
	for e in events:
		if e.type in ["game_over", "player_connection", "policy", "executed"]:
			_log("evento %s" % JSON.stringify(e))
	_check(v)
	if v.phase == "game_over":
		_log("FIM vencedor=%s motivo=%s L=%d F=%d" % [v.winner, v.win_reason, v.liberal, v.fascist])
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	var key := "%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%s|%s" % [v.phase, v.president, v.chancellor, v.voted.size(), v.hand.size(), v.players.size(), v.ready.size(), v.liberal, v.fascist, v.tracker, v.veto_refused, v.power_target]
	if key == _acted:
		return
	_acted = key
	_act.call_deferred(v)


## O que este aparelho recebe tem que bater com o que ele pode saber.
func _check(v: Dictionary) -> void:
	var me: String = v.you
	if board and (v.role != "" or not v.knows.is_empty() or not v.hand.is_empty() or not v.peek.is_empty()):
		_log("ERRO: tabuleiro recebeu coisa secreta")
	if v.phase != "game_over" and not v.all_roles.is_empty():
		_log("ERRO: papéis revelados antes do fim")
	if v.phase != "game_over":
		for h in v.history:
			if h.has("drawn") or h.has("passed"):
				_log("ERRO: histórico mostra as leis antes do fim")
	if v.role == "liberal" and not v.knows.is_empty():
		_log("ERRO: liberal sabe de alguém")
	if v.role == "hitler" and v.players.size() > 6 and not v.knows.is_empty():
		_log("ERRO: Hitler com 7+ sabe de alguém")
	if not v.hand.is_empty():
		var ok: bool = (v.phase == "leg_president" and v.president == me) or (v.phase in ["leg_chancellor", "veto"] and v.chancellor == me)
		if not ok:
			_log("ERRO: recebeu leis sem ser do governo")
	if not v.peek.is_empty() and not (v.phase == "power" and v.president == me):
		_log("ERRO: viu o baralho sem ser o presidente")
	if not board and v.phase not in ["lobby"] and v.role == "":
		_log("ERRO: jogador sem papel")


func _act(v: Dictionary) -> void:
	var wait_ms := int(OS.get_environment("BOT_CONTINUE_MS")) if OS.get_environment("BOT_CONTINUE_MS") != "" else 60
	if board:
		if v.phase in ["vote_result", "policy", "power_result"] and rng.randf() < 0.3:
			await get_tree().create_timer(wait_ms / 1000.0).timeout
			session.send({"type": "continue"})
		return
	var me: String = v.you
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"reveal":
			if me not in v.ready:
				session.send({"type": "ready"})
		"nominate":
			if v.president == me:
				var el: Array = v.eligible
				session.send({"type": "nominate", "id": el[rng.randi() % el.size()]})
		"vote":
			if v.alive and v.my_vote == null:
				if drop and not _dropped and int(v.liberal) + int(v.fascist) >= 1:
					_dropped = true
					_log("derrubando a própria conexão")
					Net.close()
					await get_tree().create_timer(2.0).timeout
					(session as ShClient).connect_to_host()
					return
				session.send({"type": "vote", "ja": rng.randf() < 0.7})
		"vote_result", "policy", "power_result":
			if session.is_host:
				await get_tree().create_timer(wait_ms / 1000.0).timeout
				session.send({"type": "continue"})
		"leg_president":
			if v.president == me and v.hand.size() == 3:
				session.send({"type": "discard", "index": rng.randi() % 3})
		"leg_chancellor":
			if v.chancellor == me and v.hand.size() == 2:
				if v.veto_unlocked and not v.veto_refused and rng.randf() < 0.4:
					session.send({"type": "veto"})
				else:
					session.send({"type": "enact", "index": rng.randi() % 2})
		"veto":
			if v.president == me:
				session.send({"type": "veto_answer", "accept": rng.randf() < 0.5})
		"power":
			if v.president == me:
				if v.power == "peek":
					if v.peek.size() != 3:
						_log("ERRO: presidente não viu as 3 leis")
					session.send({"type": "power"})
					return
				var ok: Array = v.players.filter(func(p): return p.alive and p.id != me and (v.power != "investigate" or p.id not in v.investigated))
				session.send({"type": "power", "id": ok[rng.randi() % ok.size()].id})
