extends Node
## Ferramenta de teste: robôs jogando Sintonia ou Ito pela rede local (docs/PLANO_SINTONIA_ITO.md, T2/T3).
##   godot --headless -- --pbot=host --bot-game=ito --bot-name=Host --bot-players=4
##   godot --headless -- --pbot=client --bot-game=ito --bot-name=Bia [--bot-board] [--bot-drop]
## Cada robô joga sozinho e confere que só recebe o que pode ver. Imprime "BOT <nome>: ...".

var mode := ""
var game := "ito"
var bot_name := "Bot"
var players := 4
var board := false
var drop := false
var session: PartySession
var _deadline := 0
var _dropped := false
var _acted := ""
var _busy := false
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b = load("res://tools/party_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-game="):
			b.game = a.substr(11)
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
		var rules = ItoRules.new(ThemeBank.load_file("res://games/ito/data/temas.txt")) if game == "ito" else SintoniaRules.new(ThemeBank.load_file("res://games/sintonia/data/temas.txt"))
		var h := PartyHost.new(game, "Ito" if game == "ito" else "Sintonia", rules, "player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c := PartyClient.new(game, "127.0.0.1", bot_name, "board" if board else "player")
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
		if e.type in ["game_over", "player_connection", "revealed"]:
			_log("evento %s" % JSON.stringify(e))
	if game == "ito":
		_check_ito(v)
	else:
		_check_sintonia(v)
	if v.phase == "game_over":
		if game == "ito":
			_log("FIM motivo=%s recorde=%d rodadas=%d" % [v.end_reason, int(v.best), v.rounds.size()])
		else:
			_log("FIM vencedor=%s placar=%s rodadas=%d" % [v.winner, JSON.stringify(v.scores), v.rounds.size()])
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0))
		return
	var key := _key(v)
	if key == _acted or _busy:
		return
	_acted = key
	_act.call_deferred(v)


func _key(v: Dictionary) -> String:
	if game == "ito":
		return "%s|%d|%d|%s|%s|%d" % [v.phase, int(v.round_no), v.players.size(), ",".join(v.row.map(func(r): return r.card)), v.hand.map(func(c): return c.word).hash(), int(v.shown)]
	return "%s|%d|%d|%s|%s|%s" % [v.phase, v.rounds.size(), v.players.size(), v.psychic, v.side, v.theme.hash()]


# --- O que chega tem que bater com o que o aparelho pode saber ---------------

func _check_ito(v: Dictionary) -> void:
	var open: bool = v.phase in ["reveal", "game_over"]
	if board and not v.hand.is_empty():
		_log("ERRO: tabuleiro recebeu números")
	for i in v.row.size():
		var r: Dictionary = v.row[i]
		if int(r.n) >= 0 and not open and not r.mine:
			_log("ERRO: viu o número de outro na fila")
		if v.phase == "reveal" and (int(r.n) >= 0) != (i < int(v.shown)):
			_log("ERRO: número da revelação fora da virada")
		if v.extreme and not open and not r.mine and r.owner != "":
			_log("ERRO: modo extremo mostrou o dono")
	if v.phase == "reveal" and int(v.shown) < v.row.size() and not v.result.is_empty():
		_log("ERRO: resultado antes de virar tudo")
	if not v.loose.is_empty():
		_log("ERRO: recebeu cartas soltas do celular só")


func _check_sintonia(v: Dictionary) -> void:
	var open: bool = v.phase in ["reveal", "game_over"]
	var psy: bool = not board and v.you == v.psychic
	if float(v.target) >= 0 and not open and not (psy and v.phase in ["pick", "dial", "guess"]):
		_log("ERRO: viu o alvo sem dar a dica")
	if not v.options.is_empty() and not psy:
		_log("ERRO: viu os temas sem dar a dica")


# --- Jogadas ---------------------------------------------------------------

func _wait(ms: int) -> void:
	await get_tree().create_timer(ms / 1000.0).timeout


func _act(v: Dictionary) -> void:
	_busy = true
	if game == "ito":
		await _act_ito(v)
	else:
		await _act_sintonia(v)
	_busy = false
	# O estado pode ter mudado enquanto o robô esperava: olha de novo.
	if session.view != v:
		_acted = ""
		_on_view(session.view, [])


func _act_ito(v: Dictionary) -> void:
	var wait := int(OS.get_environment("BOT_CONTINUE_MS")) if OS.get_environment("BOT_CONTINUE_MS") != "" else 60
	if board:
		if v.phase == "reveal" and int(v.shown) >= v.row.size() and rng.randf() < 0.3:
			await _wait(wait + 300)
			session.send({"type": "continue"})
		return
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"theme":
			if drop and not _dropped and int(v.round_no) >= 2:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await _wait(2000)
				(session as PartyClient).connect_to_host()
				return
			# Primeiro a palavra-chave (o robô "fala" o número), depois alguém escolhe o tema.
			for c in v.hand:
				if c.word == "":
					session.send({"type": "word", "card": c.card, "text": str(int(c.n))})
					return
			if session.is_host:
				await _wait(100)
				session.send({"type": "pick_theme", "index": rng.randi() % maxi(1, v.theme_options.size())})
		"play":
			for c in v.hand:
				if c.word == "":
					session.send({"type": "word", "card": c.card, "text": str(int(c.n))})
					return
			for c in v.hand:
				if not c.placed:
					await _wait(rng.randi_range(20, 120))
					session.send({"type": "place", "card": c.card, "to": _spot(v, int(c.n))})
					return
			if v.all_placed and session.is_host:
				await _wait(150)
				# O grupo "conversa": o host arruma a fila pelas palavras-chave (às vezes deixa passar).
				var fix := _misplaced(v)
				if fix.is_empty() or rng.randf() < 0.1:
					session.send({"type": "reveal"})
				else:
					session.send({"type": "move", "card": fix.card, "to": fix.to})
		"reveal":
			if session.is_host:
				await _wait(wait)
				# O host vira carta por carta; só depois alguém continua.
				session.send({"type": "flip" if int(v.shown) < v.row.size() else "continue"})


## Primeira carta fora do lugar pelas palavras-chave: {card, to}.
func _misplaced(v: Dictionary) -> Dictionary:
	var words: Array = v.row.map(func(r): return int(r.word) if str(r.word).is_valid_int() else 50)
	var sorted := words.duplicate()
	sorted.sort()
	for i in words.size():
		if words[i] != sorted[i]:
			var j := sorted.find(words[i])
			return {"card": v.row[i].card, "to": j}
	return {}


## Onde pôr a carta: pelas palavras-chave dos outros (os robôs escrevem o número). Às vezes erra.
func _spot(v: Dictionary, n: int) -> int:
	if rng.randf() < 0.12:
		return rng.randi_range(0, v.row.size())
	var i := 0
	for r in v.row:
		var w := int(r.word) if str(r.word).is_valid_int() else 50
		if w < n:
			i += 1
	return i


func _act_sintonia(v: Dictionary) -> void:
	var wait := int(OS.get_environment("BOT_CONTINUE_MS")) if OS.get_environment("BOT_CONTINUE_MS") != "" else 60
	var me: String = v.you
	var times: bool = v.config.mode == "times"
	if board:
		if v.phase == "reveal" and rng.randf() < 0.3:
			await _wait(wait + 300)
			session.send({"type": "continue"})
		return
	match v.phase:
		"lobby":
			if session.is_host and v.players.size() >= players and v.can_start == "":
				_log("começando com %d jogadores" % v.players.size())
				session.send({"type": "start"})
		"pick":
			if me == v.psychic:
				if float(v.target) < 0:
					_log("ERRO: quem dá a dica não viu o alvo")
				await _wait(80)
				session.send({"type": "pick_theme", "index": rng.randi() % maxi(1, v.options.size())})
		"dial":
			if drop and not _dropped and v.rounds.size() >= 2:
				_dropped = true
				_log("derrubando a própria conexão")
				Net.close()
				await _wait(2000)
				(session as PartyClient).connect_to_host()
				return
			var mine: bool = me != v.psychic and (not times or v.my_team == v.turn_team)
			if not mine:
				return
			# Arrasta um pouco (ao vivo) e o primeiro do time trava.
			var goal := rng.randf_range(5.0, 95.0)
			for k in 6:
				session.send({"type": "dial", "pos": lerpf(float(v.dial), goal, (k + 1) / 6.0)})
				await _wait(66)
			if _first_turner(v) == me:
				await _wait(200)
				session.send({"type": "lock"})
		"guess":
			if times and v.my_team != "" and v.my_team != v.turn_team:
				if v.side == "":
					session.send({"type": "side", "side": "left" if rng.randf() < 0.5 else "right"})
				elif _first_bettor(v) == me:
					await _wait(100)
					session.send({"type": "lock_side"})
		"reveal":
			if session.is_host:
				await _wait(wait)
				session.send({"type": "continue"})


func _first_turner(v: Dictionary) -> String:
	for p in v.players:
		if p.id != v.psychic and (v.config.mode != "times" or p.team == v.turn_team):
			return p.id
	return ""


func _first_bettor(v: Dictionary) -> String:
	for p in v.players:
		if p.team != v.turn_team:
			return p.id
	return ""
