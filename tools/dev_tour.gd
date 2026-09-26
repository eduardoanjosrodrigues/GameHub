class_name DevTour
extends Node
## Ferramenta de desenvolvimento: percorre as telas e salva capturas em PNG.
## Uso: godot --resolution 720x1280 -- --tour=/caminho/da/pasta [--tour-set=all|game|board]

var out_dir := ""
var set_name := "all"
var _n := 0


static func requested() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour="):
			return true
	return false


static func start(main: Node) -> void:
	var t := DevTour.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour="):
			t.out_dir = a.substr(7)
		elif a.begins_with("--tour-set="):
			t.set_name = a.substr(11)
	main.add_child(t)
	t._run.call_deferred()


func _shot(label: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, _n, label])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Settings.music_volume = 0.0
	Settings.sfx_volume = 0.0
	if set_name in ["all", "hub"]:
		await _hub()
	if set_name in ["all", "game"]:
		await _local_game()
	if set_name in ["all", "board"]:
		await _board()
	get_tree().quit()


func _hub() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	await _shot("home")
	App.push(load("res://app/screens/settings_screen.gd").new())
	await _shot("settings")
	App.back()
	History.add({"date": "2026-09-25T21:40:00", "game": "chapeu", "game_name": "Chapéu", "mode": "local", "winner": "azul", "criterion": "pontos",
		"totals": {"azul": 31, "vermelho": 24}, "scores": [[12, 9], [10, 8], [9, 7]],
		"players": [{"name": "Ana", "team": "azul"}, {"name": "Bruno", "team": "azul"}, {"name": "Carla", "team": "vermelho"}, {"name": "Davi", "team": "vermelho"}]})
	App.push(load("res://app/screens/history_screen.gd").new())
	await _shot("history")
	App.back()
	App.push(load("res://games/chapeu/screens/chapeu_menu.gd").new())
	await _shot("chapeu_menu")
	App.push(load("res://games/chapeu/screens/how_to_screen.gd").new())
	await _shot("how_to")
	App.back()
	App.push(load("res://games/chapeu/screens/create_room_screen.gd").new())
	await _shot("create_room")
	App.back()
	App.push(load("res://games/chapeu/screens/join_screen.gd").new())
	await _shot("join")
	App.back()


func _local_game() -> void:
	var s := LocalSession.new()
	var game: Screen = load("res://games/chapeu/screens/chapeu_game.gd").new(s)
	App.push(game)
	await _shot("lobby_empty")
	var names := ["Ana", "Bruno", "Carla", "Davi", "Elisa", "Fábio"]
	for i in names.size():
		s.send({"type": "add_player", "name": names[i], "team": "azul" if i % 2 == 0 else "vermelho"})
	s.send({"type": "set_config", "words_per_player": 3})
	await _shot("lobby_players")
	game._show_config = true
	game._rebuild()
	await _shot("config")
	s.send({"type": "set_config", "source": "mistura"})
	await _shot("config_mix")
	s.send({"type": "set_config", "source": "jogadores"})
	game._show_config = false
	s.send({"type": "start"})
	await _shot("writing_cover")
	game._writer_revealed = true
	game._rebuild()
	await _shot("writing_form")
	var words := [["Pelé", "Guarda-chuva", "Titanic"], ["Xuxa", "Brigadeiro", "Frozen"], ["Capivara", "Torre Eiffel", "Shrek"],
		["Mickey", "Pipoca", "Matrix"], ["Anitta", "Violão", "Coco"], ["Batman", "Praia", "Up"]]
	for i in names.size():
		s.send({"type": "submit_words", "id": s.rules.players[i].id, "words": words[i]})
	await _shot("round_intro")
	s.send({"type": "next"})
	await _shot("turn_ready")
	s.send({"type": "choose_explainer", "id": s.rules.players[0].id})
	await _shot("turn_ready_chosen")
	s.send({"type": "start_turn"})
	s.send({"type": "hit"})
	s.send({"type": "hit"})
	s.send({"type": "skip"})
	await _shot("turn_explainer")
	s.rules.time_ms = 7000
	await _shot("turn_urgent")
	s.send({"type": "pause"})
	await _shot("paused")
	s.send({"type": "resume"})
	s.rules.time_ms = 10
	await get_tree().create_timer(0.2).timeout
	await _shot("turn_summary")
	# Termina as rodadas rápido.
	while s.rules.phase != ChapeuRules.PHASE_GAME_OVER:
		match s.rules.phase:
			ChapeuRules.PHASE_TURN_READY:
				if s.rules.explainer == "":
					s.send({"type": "choose_explainer", "id": s.rules.team_players(s.rules.current_team())[0].id})
				s.send({"type": "start_turn"})
			ChapeuRules.PHASE_TURN:
				s.send({"type": "hit"})
			ChapeuRules.PHASE_ROUND_END:
				if s.rules.round_idx == 0:
					await _shot("round_end")
				s.send({"type": "next"})
			_:
				s.send({"type": "next"})
	await _shot("game_over")
	await get_tree().create_timer(1.5).timeout
	s.leave()
	App.home()


func _board() -> void:
	# Host como tabuleiro, com jogadores falsos entrando direto nas regras.
	var s := HostSession.new("board", "")
	var err := s.open_room()
	if err != "":
		push_error(err)
		return
	var game: Screen = load("res://games/chapeu/screens/chapeu_game.gd").new(s)
	App.push(game)
	var names := ["Ana", "Bruno", "Carla", "Davi", "Elisa"]
	for i in names.size():
		s.rules.apply({"id": "", "host": true}, {"type": "add_player", "id": "d%d" % i, "name": names[i], "team": "azul" if i % 2 == 0 else "vermelho"})
	s.rules.set_connected("d4", false)
	s.send({"type": "set_config", "source": "lista"})
	await _shot("board_lobby")
	s.rules.set_connected("d4", true)
	s.send({"type": "start"})
	s.send({"type": "next"})
	s.rules.apply({"id": "d0", "host": false}, {"type": "choose_explainer", "id": "d0"})
	s.rules.apply({"id": "d0", "host": false}, {"type": "start_turn"})
	s.rules.apply({"id": "d0", "host": false}, {"type": "hit"})
	s._broadcast([])
	await _shot("board_turn")
	s.leave()
	App.home()
