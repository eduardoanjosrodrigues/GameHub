extends RefCounted
## Capturas do Quem Foi? pro tour (tools/dev_tour.gd, --tour-set=quem_foi): cada fase no celular do
## host e no tabuleiro.


func run(tour) -> void:
	var tree: SceneTree = tour.get_tree()
	App.push(load("res://app/screens/home_screen.gd").new())
	await tour._shot("qf_home")
	App.push(load("res://games/quem_foi/screens/quem_foi_menu.gd").new())
	await tour._shot("qf_menu")
	App.push(load("res://games/quem_foi/screens/quem_foi_how_to.gd").new())
	await tour._shot("qf_how_to")
	App.home()
	for role in ["player", "board"]:
		var h := QuemFoiHost.new(role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/quem_foi/screens/quem_foi_game.gd").new(h)
		App.push(game)
		var r: QuemFoiRules = h.rules
		for n in ["Bruno", "Carla", "Davi"]:
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
		h._broadcast([])
		await tour._shot("qf_%s_lobby" % role)
		h.send({"type": "start"})
		var me: String = h.local_id if role == "player" else "d_Bruno"
		r.starter = me
		r.accuser = me
		h._broadcast([])
		await tour._shot("qf_%s_open" % role)
		if role == "player":
			game._open_play = "gato"
			game._rebuild()
			await tour._shot("qf_player_accuse")
		r.apply({"id": me, "host": false, "now": h.now_ms()}, {"type": "accuse", "play": "gato", "animal": "coelho"})
		r.hands["d_Carla"].erase("peixe")
		# A corrida vista por quem corre: o host joga no lugar do Bruno.
		r.accuser = "d_Bruno"
		h._broadcast([])
		await tour._shot("qf_%s_race" % role)
		r.ring([{"player": "d_Carla", "t": h.now_ms(), "animal": "coelho"}], h.now_ms())
		h._broadcast([{"type": "won_race", "id": "d_Carla"}])
		await tour._shot("qf_%s_accuse_other" % role)
		r.hands["d_Bruno"].erase("peixe")
		r.hands["d_Davi"].erase("peixe")
		if role == "player":
			r.hands[me].erase("peixe")
		r.apply({"id": "d_Carla", "host": false, "now": h.now_ms()}, {"type": "accuse", "animal": "peixe"})
		r.suspense_until = 0
		r.tick(h.now_ms())
		h._broadcast([])
		await tour._shot("qf_%s_round_end" % role)
		for p in r.players:
			p.poops = [3, 1, 0, 2][r.players.find(p)]
		r.apply({"id": me, "host": false}, {"type": "continue"})
		h._broadcast([])
		await tour._shot("qf_%s_game_over" % role)
		h.leave()
		App.home()
		await tree.create_timer(0.4).timeout
