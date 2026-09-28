extends RefCounted
## Capturas do Genius pro tour (tools/dev_tour.gd, --tour-set=genius): solo, passa o aparelho e
## Corrida no celular do host.


func run(tour) -> void:
	var tree: SceneTree = tour.get_tree()
	App.push(load("res://app/screens/home_screen.gd").new())
	await tour._shot("gn_home")
	App.push(load("res://games/genius/screens/genius_menu.gd").new())
	await tour._shot("gn_menu")
	App.push(load("res://games/genius/screens/genius_how_to.gd").new())
	await tour._shot("gn_how_to")
	App.back()
	var solo: Screen = load("res://games/genius/screens/genius_solo.gd").new()
	App.push(solo)
	await tour._shot("gn_solo_idle")
	solo._start()
	solo._seq = [0, 1, 3, 2, 1]
	solo._play_round(0)
	await tree.create_timer(0.3).timeout
	await tour._shot("gn_solo_playing")
	await tree.create_timer(2.6).timeout
	solo._board._gui_input(_click(solo._board, 0, true))
	await tour._shot("gn_solo_press")
	solo._board._gui_input(_click(solo._board, 0, false))
	solo._i = 2
	solo._on_press(0)
	await tree.create_timer(0.4).timeout
	await tour._shot("gn_solo_over")
	App.home()
	await _check_release(tree)

	# Passa o aparelho.
	var loc := PartyLocal.new("genius", GeniusRules.new(3))
	var game: Screen = load("res://games/genius/screens/genius_game.gd").new(loc)
	App.push(game)
	for n in ["Ana", "Bruno", "Carla", "Davi"]:
		loc.send({"type": "add_player", "name": n})
	await tour._shot("gn_local_lobby")
	loc.send({"type": "start"})
	await tour._shot("gn_local_gate")
	game._ready_round = int(game.v.round_no)
	game._rebuild()
	await tree.create_timer(0.9).timeout
	await tour._shot("gn_local_board")
	App.home()
	await tree.create_timer(0.3).timeout

	# Corrida no celular do host.
	var h := GeniusHost.new("Ana")
	if h.open_room() != "":
		return
	var rg: Screen = load("res://games/genius/screens/genius_game.gd").new(h)
	App.push(rg)
	var r: GeniusRules = h.rules
	for n in ["Bruno", "Carla", "Davi"]:
		r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
	h._broadcast([])
	await tour._shot("gn_race_lobby")
	h.send({"type": "start"})
	await tour._shot("gn_race_countdown")
	r.seq = [2, 0, 3]
	r.round_at = h.now_ms() - 5000
	for c in r.seq:
		h.send({"type": "press", "color": c, "i": r.progress.get(h.local_id, 0)})
	r.apply({"id": "d_Bruno", "host": false}, {"type": "press", "color": 1, "i": 0})
	h._broadcast([])
	await tour._shot("gn_race_waiting")
	for id in ["d_Carla", "d_Davi"]:
		for c in r.seq:
			r.apply({"id": id, "host": false, "now": h.now_ms()}, {"type": "press", "color": c, "i": r.progress.get(id, 0)})
	h._broadcast([])
	await tour._shot("gn_race_round_end")
	r.round_end_until = 0
	r.tick(h.now_ms())
	for id in ["d_Carla", "d_Davi"]:
		r.apply({"id": id, "host": false, "now": h.now_ms()}, {"type": "press", "color": (int(r.seq[0]) + 1) % 4, "i": 0})
	for c in r.seq:
		h.send({"type": "press", "color": c, "i": r.progress.get(h.local_id, 0)})
	h._broadcast([])
	await tour._shot("gn_race_game_over")
	h.leave()
	App.home()
	await tree.create_timer(0.4).timeout


func _click(board: Control, color: int, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	var s: Vector2 = board.size
	var off: Vector2 = [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)][color]
	e.position = s / 2.0 + off * s
	return e


## Soltar o último botão da rodada com a próxima sequência já agendada apaga o botão e para o som.
func _check_release(tree: SceneTree) -> void:
	var solo: Screen = load("res://games/genius/screens/genius_solo.gd").new()
	App.push(solo)
	await tree.process_frame
	solo._start()
	solo._seq = [2]
	solo._play_round(0)
	await tree.create_timer(0.8).timeout
	var b: GeniusBoard = solo._board
	b._gui_input(_click(b, 2, true))
	await tree.create_timer(0.3).timeout
	b._gui_input(_click(b, 2, false))
	await tree.process_frame
	if b._lit != -1 or b.tones._on:
		print("TOUR ERRO: botão ficou aceso depois do último toque (lit=%d)" % b._lit)
	else:
		print("TOUR ok: botão apaga depois do último toque")
	App.home()
