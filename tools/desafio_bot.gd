extends Node
## Ferramenta de teste: robôs jogando a Corrida do Wordle/Senha ou o Duelo do Senha pela rede local
## (docs/PLANO_WORDLE_SENHA.md §5, §8).
##   godot --headless -- --dbot=host --bot-game=wordle --bot-name=Host --bot-players=4 [--bot-mode=duelo] [--bot-crit=pontos]
##   godot --headless -- --dbot=client --bot-game=wordle --bot-name=Bia [--bot-drop]
## O host conhece o segredo e acerta no 3º palpite; os outros chutam. Cada robô confere que nunca
## recebe o segredo (nem as letras dos outros) antes da hora. Imprime "BOT <nome>: ...".

var mode := ""
var game := "wordle"
var bot_name := "Bot"
var players := 3
var net_mode := "corrida"
var criterio := "tentativas"
var drop := false
var session: PartySession
var _deadline := 0
var _dropped := false
var _busy := false
var _started := false
var _rounds_seen := 0
var _words: Array = []
var rng := RandomNumberGenerator.new()


static func start(main: Node) -> void:
	var b = load("res://tools/desafio_bot.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dbot="):
			b.mode = a.substr(7)
		elif a.begins_with("--bot-game="):
			b.game = a.substr(11)
		elif a.begins_with("--bot-name="):
			b.bot_name = a.substr(11)
		elif a.begins_with("--bot-players="):
			b.players = int(a.substr(14))
		elif a.begins_with("--bot-mode="):
			b.net_mode = a.substr(11)
		elif a.begins_with("--bot-crit="):
			b.criterio = a.substr(11)
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
	DesafioStore.reset_for_tests()
	rng.seed = hash(bot_name)
	_words = WordleWords.answers().map(func(w): return WordleWords.norm(w))
	_deadline = Time.get_ticks_msec() + 150000
	if mode == "host":
		var h: PartyHost = WordleHost.new("player", bot_name) if game == "wordle" else SenhaHost.new("player", bot_name)
		session = h
		add_child(h)
		if h.open_room() != "":
			_log("ERRO ao abrir sala")
			get_tree().quit(1)
			return
		_log("sala aberta")
	else:
		var c: PartyClient = WordleClient.new("127.0.0.1", bot_name) if game == "wordle" else SenhaClient.new("127.0.0.1", bot_name)
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
	_check_secrets(v)
	for e in events:
		if e.get("type", "") == "player_connection":
			_log("conexão %s" % JSON.stringify(e))
	match v.phase:
		"lobby":
			if session.is_host and not _started and v.players.size() >= players:
				_started = true
				session.send({"type": "set_config", "modo": net_mode, "criterio": criterio, "rodadas": 3, "nivel": "medio", "retorno": "contagem"})
				_later(0.5, func(): session.send({"type": "start"}))
		"create":
			if not v.codes_ready.get(v.you, false) and not _busy:
				_busy = true
				_later(0.3, func():
					_busy = false
					session.send({"type": "set_code", "pins": SenhaLogic.random_code("medio", rng)}))
		"play":
			_play(v)
		"round_end":
			if session.is_host and not _busy:
				_busy = true
				_later(0.5, func():
					_busy = false
					session.send({"type": "next_round"}))
		"game_over":
			_log("FIM %s" % JSON.stringify(v.results.map(func(r): return [r.pos, r.solved, r.tries])))
			# O host espera um pouco: quem estava reconectando ainda recebe o fim.
			_later(5.0 if session.is_host else 1.0, func(): get_tree().quit(0))


func _play(v: Dictionary) -> void:
	var me: Dictionary = v.get("me", {})
	if me.is_empty() or me.done or _busy:
		return
	if v.get("duel", false) and v.config.duelo == "alternado" and v.turn != v.you:
		return
	# Um cliente derruba a própria conexão no meio da rodada e volta.
	if drop and not _dropped and me.guesses.size() >= 2:
		_dropped = true
		_log("derrubando a conexão")
		Net.close()
		_later(1.5, func(): (session as PartyClient).connect_to_host())
		return
	_busy = true
	_later(0.6 + rng.randf() * 0.5, func():
		_busy = false
		var n: int = session.view.me.get("guesses", []).size()
		if session.view.phase != "play" or session.view.me.get("done", false):
			return
		session.send(_guess_action(n)))


func _guess_action(n: int) -> Dictionary:
	var r = (session as PartyHost).rules if session.is_host else null
	if game == "wordle":
		var w: String = r.secret if r and n >= 2 else _words[rng.randi_range(0, _words.size() - 1)]
		return {"type": "guess", "word": w, "local_us": Time.get_ticks_usec()}
	var pins: Array
	if r and n >= 2:
		pins = r.codes[r.other_of(session.local_id)] if r.duel() else r.secret
	else:
		pins = SenhaLogic.random_code("medio", rng)
	return {"type": "guess", "pins": pins, "local_us": Time.get_ticks_usec()}


## Antes do fim, nada do segredo chega a quem joga: nem o segredo, nem as letras dos outros.
func _check_secrets(v: Dictionary) -> void:
	if session.is_host or v.phase in ["round_end", "game_over", "lobby"]:
		return
	if v.get("secret") != null:
		_log("ERRO segredo vazou: %s" % str(v.secret))
	for o in v.get("others", []):
		if JSON.stringify(o).contains("\"w\""):
			_log("ERRO letras dos outros vazaram")
	if v.get("duel", false) and not v.get("codes", {}).is_empty():
		_log("ERRO senhas do duelo vazaram")


func _later(s: float, f: Callable) -> void:
	get_tree().create_timer(s).timeout.connect(f)
