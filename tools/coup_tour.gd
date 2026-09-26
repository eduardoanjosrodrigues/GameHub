extends RefCounted
## Capturas do Coup pro tour (tools/dev_tour.gd, --tour-set=coup): cada fase no celular do host e no
## tabuleiro.


func _rig(r: CoupRules, me: String) -> void:
	var hands := [["duque", "condessa"], ["capitao", "assassino"], ["embaixador", "duque"], ["condessa", "capitao"]]
	var i := 0
	for p in r.players:
		r.cards[p.id] = hands[i % hands.size()].map(func(x): return {"role": x, "up": false})
		r.coins[p.id] = [2, 5, 3, 7][i % 4]
		i += 1
	r.turn = me
	r.phase = "turn"


func run(tour) -> void:
	var tree: SceneTree = tour.get_tree()
	App.push(load("res://games/coup/screens/coup_menu.gd").new())
	await tour._shot("coup_menu")
	App.push(load("res://games/coup/screens/coup_how_to.gd").new())
	await tour._shot("coup_how_to")
	App.home()
	for role in ["player", "board"]:
		var h := CoupHost.new(role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/coup/screens/coup_game.gd").new(h)
		App.push(game)
		var r: CoupRules = h.rules
		for n in ["Bruno", "Carla", "Davi"]:
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
		h._broadcast([])
		await tour._shot("coup_%s_lobby" % role)
		h.send({"type": "start"})
		var me: String = h.local_id if role == "player" else "d_Bruno"
		_rig(r, me)
		r._log({"k": "declared", "id": "d_Carla", "action": "imposto", "target": "", "claim": "duque"})
		r._log({"k": "challenge", "id": "d_Davi", "target": "d_Carla", "role": "duque", "had": true})
		r._log({"k": "lost", "id": "d_Davi", "role": "capitao"})
		r.cards["d_Davi"][1].up = true
		h._broadcast([])
		await tour._shot("coup_%s_turn" % role)
		# Carla diz ter o Duque: a janela vista por quem pode desafiar.
		r.turn = "d_Carla"
		r.apply({"id": "d_Carla", "host": false, "now": h.now_ms()}, {"type": "act", "action": "imposto"})
		h._broadcast([])
		await tour._shot("coup_%s_window" % role)
		r.phase = "turn"
		r.pending = {}
		# Bruno assassina o host: ele pode bloquear com a Condessa.
		r.turn = "d_Bruno"
		r.apply({"id": "d_Bruno", "host": false, "now": h.now_ms()}, {"type": "act", "action": "assassinar", "target": me if role == "player" else "d_Carla"})
		h._broadcast([])
		await tour._shot("coup_%s_window_target" % role)
		r.resolve_timed([{"type": "block", "player": me if role == "player" else "d_Carla", "t": h.now_ms(), "role": "condessa"}], h.now_ms())
		h._broadcast([])
		await tour._shot("coup_%s_block" % role)
		r.apply({"id": "d_Carla", "host": false}, {"type": "accept"})
		r.apply({"id": "d_Bruno", "host": false}, {"type": "accept"})
		# O host perde uma carta.
		r.losses = [me]
		r.after = "end_turn"
		r.pending = {"action": "golpe", "actor": "d_Davi", "target": me, "claim": ""}
		var ev := r._continue([])
		h._broadcast(ev)
		await tour._shot("coup_%s_lose" % role)
		r.apply({"id": me, "host": false}, {"type": "lose", "index": 1})
		# Troca com o Embaixador.
		r.turn = me
		r.phase = "turn"
		r.pending = {}
		r.apply({"id": me, "host": false, "now": h.now_ms()}, {"type": "act", "action": "trocar"})
		r.tick(h.now_ms() + 6000)
		h._broadcast([])
		await tour._shot("coup_%s_exchange" % role)
		r.apply({"id": me, "host": false}, {"type": "exchange", "keep": [0]})
		# Fim.
		for p in r.players:
			if p.id != me:
				for c in r.cards[p.id]:
					c.up = true
		r._end_turn([])
		h._broadcast([])
		await tour._shot("coup_%s_game_over" % role)
		h.leave()
		App.home()
		await tree.create_timer(0.4).timeout
