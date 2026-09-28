extends RefCounted
## Capturas do Wordle e do Senha pro tour (tools/dev_tour.gd, --tour-set=desafio): menus, partidas
## solo, estatísticas e as telas de rede (Corrida e Duelo). Nada vai pro disco.


func _type(s: Screen, word: String, tree: SceneTree) -> void:
	for ch in word:
		s._on_key(ch)
	s._on_key("enter")
	await tree.create_timer(1.4).timeout


func run(tour) -> void:
	var tree: SceneTree = tour.get_tree()
	DesafioStore.reset_for_tests()
	var today := Desafio.day_index()
	# Tela inicial: os dois jogados por último sobem pro topo.
	Settings.last_played = {"senha": 200, "wordle": 100}
	App.push(load("res://app/screens/home_screen.gd").new())
	await tour._shot("desafio_home")
	App.home()
	# Wordle.
	DesafioStore.record("wordle_dia", true, 4, today - 2)
	DesafioStore.record("wordle_dia", true, 3, today - 1)
	App.push(load("res://games/wordle/screens/wordle_menu.gd").new())
	await tour._shot("wordle_menu")
	var answer := WordleWords.norm(WordleWords.daily(today))
	var solo: Screen = load("res://games/wordle/screens/wordle_solo.gd").new("dia")
	App.push(solo)
	await tree.create_timer(0.5).timeout
	for w in ["carta", "sonho"]:
		await _type(solo, w if w != answer else "praia", tree)
	for ch in "lim":
		solo._on_key(ch)
	await tour._shot("wordle_solo_playing")
	solo._on_key("o")
	solo._on_key("enter")
	await tree.create_timer(0.1).timeout
	await tour._shot("wordle_solo_invalid")
	solo._on_key("back")
	solo._on_key("back")
	solo._on_key("back")
	for ch in answer:
		solo._on_key(ch)
	solo._on_key("enter")
	await tree.create_timer(1.8).timeout
	await tour._shot("wordle_solo_won")
	App.home()
	for m in ["dueto", "quarteto"]:
		var s: Screen = load("res://games/wordle/screens/wordle_solo.gd").new(m)
		App.push(s)
		await tree.create_timer(0.4).timeout
		await _type(s, "carta", tree)
		await _type(s, "sonho", tree)
		await _type(s, WordleWords.display(s.answers[0]), tree)
		await tour._shot("wordle_" + m)
		App.home()
	App.push(load("res://games/wordle/screens/wordle_menu.gd").stats_screen())
	await tour._shot("wordle_stats")
	App.home()
	App.push(load("res://games/wordle/screens/wordle_how_to.gd").new())
	await tour._shot("wordle_how_to")
	App.home()
	# Senha solo.
	App.push(load("res://games/senha/screens/senha_menu.gd").new())
	await tour._shot("senha_menu")
	for cfg in [["contagem", "cores", "medio"], ["posicao", "cores", "dificil"], ["contagem", "numeros", "facil"]]:
		DesafioStore.set_pref("senha_retorno", cfg[0])
		DesafioStore.set_pref("senha_aparencia", cfg[1])
		var ss: Screen = load("res://games/senha/screens/senha_solo.gd").new("treino", cfg[2])
		App.push(ss)
		await tree.create_timer(0.3).timeout
		var lv := SenhaLogic.level(cfg[2])
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for k in 4:
			ss.typed = SenhaLogic.random_code(cfg[2], rng)
			ss._submit()
		ss._on_pick(0)
		ss._on_pick(1)
		await tour._shot("senha_solo_%s_%s" % [cfg[0], cfg[1]])
		if cfg[2] == "facil":
			ss.typed = ss.code.duplicate()
			ss._submit()
			await tour._shot("senha_solo_won")
		App.home()
	DesafioStore.set_pref("senha_retorno", "contagem")
	DesafioStore.set_pref("senha_aparencia", "cores")
	await _wordle_net(tour, tree)
	await _senha_net(tour, tree)


func _add_bots(h: PartyHost, names: Array) -> void:
	for n in names:
		h.rules.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
	h._broadcast([])


func _wordle_net(tour, tree: SceneTree) -> void:
	var h := WordleHost.new("player", "Ana")
	if h.open_room() != "":
		return
	var game: Screen = load("res://games/wordle/screens/wordle_net.gd").new(h)
	App.push(game)
	_add_bots(h, ["Bruno", "Carla", "Davi"])
	h.send({"type": "set_config", "criterio": "pontos", "tempo_min": 3})
	await tour._shot("wordle_net_lobby")
	h.send({"type": "start"})
	await tour._shot("wordle_net_countdown")
	var r: WordleNetRules = h.rules
	r.tick(r.start_at)
	h._broadcast([{"type": "go"}])
	var t := r.start_at
	for g in [["d_Bruno", "carta"], ["d_Bruno", "sonho"], ["d_Carla", "praia"], ["d_Davi", r.secret]]:
		r.resolve_timed([{"type": "guess", "player": g[0], "word": g[1], "t": t + 100}], t + 100)
	h._broadcast([])
	game._typed = "lim"
	r.resolve_timed([{"type": "guess", "player": h.local_id, "word": "livro", "t": t + 300}], t + 300)
	h._broadcast([{"type": "guess", "id": h.local_id}])
	game._on_key("c")
	game._on_key("a")
	await tour._shot("wordle_net_play")
	for id in [h.local_id, "d_Bruno", "d_Carla"]:
		r.resolve_timed([{"type": "guess", "player": id, "word": r.secret, "t": t + 900}], t + 900)
	h._broadcast([{"type": "round_end"}])
	await tour._shot("wordle_net_round_end")
	App.home()
	h.leave()
	await tree.create_timer(0.3).timeout


func _senha_net(tour, tree: SceneTree) -> void:
	# Corrida.
	var h := SenhaHost.new("player", "Ana")
	if h.open_room() != "":
		return
	var game: Screen = load("res://games/senha/screens/senha_net.gd").new(h)
	App.push(game)
	_add_bots(h, ["Bruno", "Carla"])
	h.send({"type": "set_config", "retorno": "posicao"})
	await tour._shot("senha_net_lobby")
	h.send({"type": "start"})
	var r: SenhaNetRules = h.rules
	r.tick(r.start_at)
	h._broadcast([{"type": "go"}])
	var t := r.start_at
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for id in ["d_Bruno", "d_Bruno", "d_Carla", h.local_id, h.local_id]:
		r.resolve_timed([{"type": "guess", "player": id, "pins": SenhaLogic.random_code("medio", rng), "t": t + 100}], t + 100)
	h._broadcast([])
	await tour._shot("senha_net_play")
	App.home()
	h.leave()
	await tree.create_timer(0.3).timeout
	# Duelo.
	var d := SenhaHost.new("player", "Ana")
	if d.open_room() != "":
		return
	var dg: Screen = load("res://games/senha/screens/senha_net.gd").new(d)
	App.push(dg)
	_add_bots(d, ["Bruno"])
	d.send({"type": "set_config", "modo": "duelo"})
	await tour._shot("senha_duel_lobby")
	d.send({"type": "start"})
	dg._typed = [0, 3]
	d._broadcast([])
	await tour._shot("senha_duel_create")
	var dr: SenhaNetRules = d.rules
	dr.apply({"id": "d_Bruno", "host": false, "now": d.now_ms()}, {"type": "set_code", "pins": [1, 1, 4, 2]})
	dg._typed = []
	d.send({"type": "set_code", "pins": [0, 3, 3, 5]})
	dr.tick(dr.start_at)
	dr.starter = d.local_id
	dr.turn = d.local_id
	var tt := dr.start_at
	for g in [[d.local_id, [0, 0, 1, 1]], ["d_Bruno", [0, 1, 2, 3]], [d.local_id, [1, 2, 4, 1]], ["d_Bruno", [0, 3, 4, 4]]]:
		dr.resolve_timed([{"type": "guess", "player": g[0], "pins": g[1], "t": tt}], tt)
	d._broadcast([])
	await tour._shot("senha_duel_play")
	dr.resolve_timed([{"type": "guess", "player": d.local_id, "pins": [1, 1, 4, 2], "t": tt}], tt)
	dr.resolve_timed([{"type": "guess", "player": "d_Bruno", "pins": [0, 3, 5, 3], "t": tt}], tt)
	d._broadcast([{"type": "game_over"}])
	await tour._shot("senha_duel_end")
	App.home()
	d.leave()
