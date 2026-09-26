extends Node
## Ferramenta de teste: robôs jogando Coup pela rede local (docs/PLANO_COUP.md, marco C2).
##   godot --headless -- --cbot=host --bot-name=Host --bot-players=4 [--bot-fifth=inquisidor]
##   godot --headless -- --cbot=client --bot-name=Bia [--bot-lag=120] [--bot-board] [--bot-drop]
## Os robôs blefam, desafiam, bloqueiam e aceitam ao acaso, e conferem que só recebem o que podem
## ver. A janela do teste é mais curta (BOT_WINDOW_MS, padrão 1200). Imprime "BOT <nome>: ...".

var mode := ""
var bot_name := "Bot"
var lag := 0
var players := 4
var fifth := "embaixador"
var board := false
var drop := false
var session: PartySession
var _deadline := 0
var _dropped := false
var _acted := ""
var _counts := {}
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b = load("res://tools/coup_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-lag="):
			b.lag = int(a.substr(10))
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a.begins_with("--bot-fifth="):
			b.fifth = a.substr(12)
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
	_deadline = Time.get_ticks_msec() + int(OS.get_environment("BOT_DEADLINE_MS") if OS.get_environment("BOT_DEADLINE_MS") != "" else "240000")
	if mode == "host":
		var h := CoupHost.new("player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		var w := int(OS.get_environment("BOT_WINDOW_MS")) if OS.get_environment("BOT_WINDOW_MS") != "" else 1200
		h.send({"type": "set_config", "fifth": fifth, "window_ms": w})
		_log("sala aberta")
	else:
		var c := CoupClient.new("127.0.0.1", bot_name, "board" if board else "player")
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
		if e.type in ["challenge", "blocked", "lost", "eliminated", "exchanged", "examined", "game_over", "player_connection"]:
			_counts[e.type] = int(_counts.get(e.type, 0)) + 1
		if e.type in ["game_over", "player_connection", "eliminated"]:
			_log("evento %s" % JSON.stringify(e))
	_check(v)
	if v.phase == "game_over":
		_log("FIM vencedor=%s %s" % [v.winner, JSON.stringify(_counts)])
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	var p: Dictionary = v.pending
	var key := "%s|%s|%s|%s|%s|%s|%s|%d" % [v.phase, v.turn, p.get("action", ""), p.get("stage", ""), p.get("blocker", ""), v.loser, JSON.stringify(v.log), v.players.size()]
	if key == _acted:
		return
	_acted = key
	_act.call_deferred(v)


## O que chega tem que bater com o que o aparelho pode saber.
func _check(v: Dictionary) -> void:
	if v.phase == "game_over":
		return
	for p in v.players:
		for c in p.cards:
			if c.role != "" and not c.up and (board or p.id != v.you):
				_log("ERRO: viu carta escondida de %s" % p.name)
	if not v.exchange.is_empty() and v.pending.get("actor", "") != v.you:
		_log("ERRO: viu a troca de outro")
	if v.examined != "" and v.pending.get("actor", "") != v.you:
		_log("ERRO: viu a carta examinada sem ser o Inquisidor")


func _wait(ms: int) -> void:
	await get_tree().create_timer(maxf(0.0, ms / 1000.0)).timeout


func _me(v: Dictionary) -> Dictionary:
	for p in v.players:
		if p.id == v.you:
			return p
	return {}


func _act(v: Dictionary) -> void:
	if board:
		return
	var me: String = v.you
	var mine := _me(v)
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				await _wait(3000)
				if session.view.get("phase", "") != "lobby":
					return
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"pick_first":
			if not v.first_options.is_empty():
				session.send({"type": "pick_first", "role": v.first_options[rng.randi() % v.first_options.size()]})
		"turn":
			if v.turn != me:
				return
			if drop and not _dropped and v.log.size() >= 6:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await _wait(2000)
				(session as PartyClient).connect_to_host()
				_acted = ""
				return
			await _wait(120)
			var coins: int = int(mine.coins)
			var others: Array = v.players.filter(func(p): return p.id != me and p.alive).map(func(p): return p.id)
			var target: String = others[rng.randi() % others.size()]
			if coins >= 10 or (coins >= 7 and rng.randf() < 0.6):
				session.send({"type": "act", "action": "golpe", "target": target})
				return
			var pool: Array = ["renda", "ajuda", "imposto", "extorquir", "trocar"]
			if coins >= 3:
				pool.append("assassinar")
			if v.config.fifth == "inquisidor":
				pool.append("examinar")
			var a: String = pool[rng.randi() % pool.size()]
			session.send({"type": "act", "action": a, "target": target})
		"window":
			if v.can_challenge and rng.randf() < 0.3:
				await _wait(rng.randi_range(100, 500))
				session.send({"type": "challenge", "local_us": Time.get_ticks_usec()})
			elif not v.can_block.is_empty() and rng.randf() < 0.45:
				await _wait(rng.randi_range(100, 500))
				session.send({"type": "block", "role": v.can_block[rng.randi() % v.can_block.size()], "local_us": Time.get_ticks_usec()})
		"block":
			if v.pending.blocker == me or not mine.alive:
				return
			await _wait(rng.randi_range(150, 600))
			if v.can_challenge and rng.randf() < (0.35 if v.pending.actor == me else 0.15):
				session.send({"type": "challenge", "local_us": Time.get_ticks_usec()})
			else:
				session.send({"type": "accept"})
		"lose":
			if v.loser == me:
				var idx: Array = []
				for i in mine.cards.size():
					if not mine.cards[i].up:
						idx.append(i)
				session.send({"type": "lose", "index": idx[rng.randi() % idx.size()]})
		"exchange":
			if v.pending.actor != me:
				return
			if v.config.fifth == "embaixador":
				var n: int = mine.cards.filter(func(c): return not c.up).size()
				var all: Array = range(n + v.exchange.size())
				for i in range(all.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var tmp = all[i]
					all[i] = all[j]
					all[j] = tmp
				session.send({"type": "exchange", "keep": all.slice(0, n)})
			else:
				session.send({"type": "exchange", "swap": rng.randi_range(-1, mine.cards.filter(func(c): return not c.up).size() - 1)})
		"examine_show":
			if v.pending.target == me:
				var idx2: Array = []
				for i in mine.cards.size():
					if not mine.cards[i].up:
						idx2.append(i)
				session.send({"type": "show", "index": idx2[rng.randi() % idx2.size()]})
		"examine_decide":
			if v.pending.actor == me:
				if v.examined == "":
					_log("ERRO: Inquisidor não viu a carta")
				session.send({"type": "examine", "force": rng.randf() < 0.5})
