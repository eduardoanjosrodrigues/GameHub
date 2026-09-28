class_name DevTour
extends Node
## Ferramenta de desenvolvimento: percorre as telas e salva capturas em PNG.
## Uso: godot -- --tour=/caminho/da/pasta [--tour-set=all|hub|game|board] [--tour-size=1080x1920]
## Com --tour-size, renderiza fora da tela no tamanho exato (simulando o stretch do projeto).

var out_dir := ""
var set_name := "all"
var _n := 0
var _vp: SubViewport


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
		elif a.begins_with("--tour-size="):
			var wh := a.substr(12).split("x")
			t._offscreen(main, Vector2i(int(wh[0]), int(wh[1])))
	main.add_child(t)
	t._run.call_deferred()


## Move o app pra uma SubViewport do tamanho pedido, com o mesmo stretch do projeto
## (720x1280 base, aspecto "expand").
func _offscreen(main: Node, px: Vector2i) -> void:
	_vp = SubViewport.new()
	_vp.size = px
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var k: float = min(px.x / 720.0, px.y / 1280.0)
	_vp.size_2d_override = Vector2i(roundi(px.x / k), roundi(px.y / k))
	_vp.size_2d_override_stretch = true
	var root := main.get_tree().root
	root.add_child.call_deferred(_vp)
	(func():
		root.remove_child(main)
		_vp.add_child(main)
		(main as Control).theme = root.theme).call_deferred()


func _shot(label: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img := (_vp.get_texture() if _vp else get_viewport().get_texture()).get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, _n, label])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	# O tour não grava nada: histórico e configurações ficam só na memória.
	History.persist = false
	History.entries = []
	Settings.music_volume = 0.0
	Settings.sfx_volume = 0.0
	if set_name in ["all", "hub"]:
		await _hub()
	if set_name in ["all", "game"]:
		await _local_game()
	if set_name in ["all", "board"]:
		await _board()
	if set_name in ["all", "halli"]:
		await _halli()
	if set_name in ["all", "avalon"]:
		await _avalon()
	if set_name in ["all", "sh"]:
		await _sh()
	if set_name in ["all", "ito"]:
		await _ito()
	if set_name in ["all", "sintonia"]:
		await _sintonia()
	if set_name in ["all", "quem_foi"]:
		await load("res://tools/quem_foi_tour.gd").new().run(self)
	if set_name in ["all", "coup"]:
		await load("res://tools/coup_tour.gd").new().run(self)
	if set_name in ["all", "genius"]:
		await load("res://tools/genius_tour.gd").new().run(self)
	if set_name == "avalon_cards":
		await _avalon_cards()
	if set_name == "sh_cards":
		await _sh_cards()
	if set_name == "avalon_scroll":
		await _avalon_scroll()
	if set_name == "swap":
		await _swap()
	if set_name == "halli_table6":
		await _halli_table(["Ana", "Bruno", "Carla", "Davi", "Elisa", "Fábio"], "table6")
	get_tree().quit()


func _hub() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	await _shot("home")
	App.push(load("res://app/screens/settings_screen.gd").new())
	await _shot("settings")
	App.back()
	History.entries.push_front({"date": "2026-09-25T21:40:00", "game": "chapeu", "game_name": "Chapéu", "mode": "local", "winner": "azul", "criterion": "pontos",
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
	App.push(load("res://app/screens/join_screen.gd").new())
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


# --- Halli Galli -----------------------------------------------------------

func _halli() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	await _shot("hg_home")
	App.push(load("res://games/halli_galli/screens/halli_menu.gd").new())
	await _shot("hg_menu")
	App.push(load("res://games/halli_galli/screens/halli_how_to.gd").new())
	await _shot("hg_how_to")
	App.back()
	await _halli_table(["Ana", "Bruno"], "table2")
	await _halli_table(["Ana", "Bruno", "Carla", "Davi"], "table4")
	await _halli_wifi()


func _halli_table(names: Array, label: String) -> void:
	var game: Screen = load("res://games/halli_galli/screens/halli_table_game.gd").new()
	App.push(game)
	var s: HalliLocal = game.session
	for n in names:
		s.send({"type": "add_player", "name": n})
	await _shot("hg_%s_setup" % label)
	s.send({"type": "start"})
	var r := s.rules
	var cards := [HalliRules.make_card(0, 2), HalliRules.make_card(1, 4), HalliRules.make_card(0, 3), HalliRules.make_card(3, 1), HalliRules.make_card(2, 5), HalliRules.make_card(1, 1)]
	for i in r.players.size():
		r.players[i].up.append({"c": cards[i], "t": 0})
		r.players[i].down.pop_front()
	r.turn = r.players[0].id
	r.last_flip_t = -100000
	r.lock_until = 0
	s._emit_view(r.view_for({"role": "table"}), [])
	await _shot("hg_%s_play" % label)
	game._tv.banner(r.players[1].id, "+%d · 23 ms" % r.players.size(), Tokens.SALVIA)
	await get_tree().create_timer(0.1).timeout
	await _shot("hg_%s_bell" % label)
	App.home()
	await get_tree().create_timer(0.3).timeout


func _halli_wifi() -> void:
	var h := HalliHost.new("Ana")
	if h.open_room() != "":
		return
	var game: Screen = load("res://games/halli_galli/screens/halli_wifi_game.gd").new(h)
	App.push(game)
	var names := ["Bruno", "Carla", "Davi", "Elisa"]
	for i in names.size():
		h.rules.apply({"id": "", "host": true}, {"type": "add_player", "id": "d%d" % i, "name": names[i]})
	h._broadcast([])
	await _shot("hg_wifi_lobby")
	game._qr_web = true
	game._build_lobby()
	await _shot("hg_wifi_lobby_web")
	h.send({"type": "start"})
	var r := h.rules
	r.turn = h.local_id
	r.lock_until = 0
	r.last_flip_t = h.now_ms() - 450
	h._refresh_local([])
	await _shot("hg_wifi_cooldown")
	r.last_flip_t = -100000
	h._refresh_local([])
	await _shot("hg_wifi_turn")
	h.send({"type": "flip"})
	await get_tree().create_timer(0.4).timeout
	await _shot("hg_wifi_card")
	game._pv.show_banner("+7 cartas!", "5 morangos · por 23 ms", Tokens.SALVIA, 3.0)
	await get_tree().create_timer(0.25).timeout
	await _shot("hg_wifi_won")
	r.set_connected("d2", false, h.now_ms())
	h._broadcast([])
	await _shot("hg_wifi_paused")
	r.set_connected("d2", true, h.now_ms())
	r.phase = HalliRules.PHASE_GAME_OVER
	r.winner = h.local_id
	r.out_order = ["d0", "d3", "d1", "d2"]
	r.players[0].ok = 5
	r.players[1].wrong = 2
	h._broadcast([])
	await _shot("hg_wifi_game_over")
	h.leave()
	App.home()


# --- Avalon ----------------------------------------------------------------

func _avalon() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	App.push(load("res://games/avalon/screens/avalon_menu.gd").new())
	await _shot("av_menu")
	for role in ["player", "board"]:
		var h := AvalonHost.new(role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/avalon/screens/avalon_game.gd").new(h)
		App.push(game)
		var r := h.rules
		var names := ["Bruno", "Carla", "Davi", "Elisa", "Fábio", "Gabi"]
		for i in (names.size() if role == "player" else 7):
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d%d" % i, "name": names[i % names.size()] if i < names.size() else "Hugo"})
		r.apply({"id": "", "host": true}, {"type": "set_config", "toggle": "morgana"})
		r.config.lady = true
		h._broadcast([])
		await _shot("av_%s_lobby" % role)
		h.send({"type": "start"})
		var ids: Array = r.players.map(func(p): return p.id)
		var me: String = ids[0]
		if role == "player":
			r.roles[me] = "merlin"
			r.roles["d3"] = "morgana"
			r.roles["d4"] = "assassino"
			r.roles["d5"] = "lacaio"
			r.roles["d0"] = "percival"
			r.roles["d1"] = "servo"
			r.roles["d2"] = "servo"
		h._broadcast([])
		await _shot("av_%s_reveal" % role)
		for id in ids:
			r.apply({"id": id, "host": false, "now": 0}, {"type": "ready"})
		r.leader = 0
		r.team = [ids[0], ids[2]]
		h._broadcast([])
		await _shot("av_%s_team" % role)
		r.apply({"id": ids[0], "host": false}, {"type": "select_team", "ids": [ids[0], ids[2]]})
		r.apply({"id": ids[0], "host": false}, {"type": "propose"})
		for i in range(1, 4):
			r.apply({"id": ids[i], "host": false}, {"type": "vote", "approve": true})
		h._broadcast([])
		await _shot("av_%s_vote" % role)
		for i in ids.size():
			if not r.votes.has(ids[i]):
				r.apply({"id": ids[i], "host": false}, {"type": "vote", "approve": i % 3 != 0})
		h._broadcast([])
		await _shot("av_%s_vote_result" % role)
		h.send({"type": "continue"})
		h._broadcast([])
		await _shot("av_%s_quest" % role)
		r.apply({"id": ids[0], "host": false}, {"type": "quest_card", "success": true})
		r.cards[ids[2]] = false
		r.apply({"id": ids[2], "host": false}, {"type": "quest_card", "success": true}) # já jogou: ignora
		r.team = [ids[0], ids[2]]
		r.cards = {ids[0]: true}
		r.roles[ids[2]] = "lacaio"
		r.apply({"id": ids[2], "host": false}, {"type": "quest_card", "success": false})
		h._broadcast([])
		await get_tree().create_timer(1.2).timeout
		await _shot("av_%s_quest_result" % role)
		r.phase = AvalonRules.PHASE_LADY
		r.lady = me
		h._broadcast([])
		await _shot("av_%s_lady" % role)
		r.phase = AvalonRules.PHASE_GAME_OVER
		r.winner = "mal"
		r.win_reason = "assassin_hit"
		r.assassin_target = me
		h._broadcast([])
		await _shot("av_%s_game_over" % role)
		h.leave()
		App.home()
		await get_tree().create_timer(0.4).timeout


## Todas as cartas de papel lado a lado (pra conferir a arte).
func _avalon_cards() -> void:
	var sc := Screen.new()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var list := [["merlin", 0], ["percival", 0], ["servo", 0], ["servo", 1], ["servo", 2], ["assassino", 0], ["morgana", 0], ["mordred", 0], ["oberon", 0], ["lacaio", 0], ["lacaio", 1], ["lacaio", 2]]
	for e in list:
		var c := AvalonArt.RoleCard.new(e[0], e[1])
		c.custom_minimum_size = Vector2(170, 255)
		grid.add_child(c)
	App.push(sc)
	await _shot("av_cards")


## "Trocar aparelho" no meio de uma partida de Avalon (net/seat_transfer.gd).
func _swap() -> void:
	var h := AvalonHost.new("player", "Ana")
	if h.open_room() != "":
		return
	var game: Screen = load("res://games/avalon/screens/avalon_game.gd").new(h)
	App.push(game)
	var r := h.rules
	for n in ["Bruno", "Carla", "Davi", "Elisa"]:
		r.apply({"id": "", "host": true}, {"type": "add_player", "id": "id_" + n, "name": n})
	h.send({"type": "start"})
	r.set_connected("id_Carla", false)
	h._broadcast([])
	await _shot("swap_banner")
	game.call("_open_swap")
	await _shot("swap_list")
	game._swap._ask("id_Carla", false)
	h.request_seat("id_Carla")
	await _shot("swap_qr")


## Arrasta (toque emulado) as salas e as telas do app e diz se o scroll anda. Um cartão ou controle
## com mouse_filter STOP no meio do conteúdo quebra o arrasto: aparece "QUEBRADO".
func _avalon_scroll() -> void:
	Input.emulate_touch_from_mouse = true
	var simple := Screen.new()
	App.push(simple)
	var col := simple.make_column()
	for i in 60:
		col.add_child(UI.label("linha %d" % i))
	await get_tree().create_timer(0.4).timeout
	await _drag(0.5)
	var ss: ScrollContainer = simple.find_children("*", "ScrollContainer", true, false)[0]
	print("SIMPLES arrasto: scroll=%d" % ss.scroll_vertical)
	var h := AvalonHost.new("player", "Ana")
	if h.open_room() != "":
		return
	var game: Screen = load("res://games/avalon/screens/avalon_game.gd").new(h)
	App.push(game)
	for n in ["Bruno", "Carla", "Davi", "Elisa", "Fábio", "Gabi"]:
		h.rules.apply({"id": "", "host": true}, {"type": "add_player", "id": "id_" + n, "name": n})
	h._broadcast([])
	await get_tree().create_timer(0.6).timeout
	for xf in [0.5, 0.2, 0.95]:
		await _drag(xf)
		print("AVALON arrasto em x=%.2f: scroll=%d de %d" % [xf, game._scroll.scroll_vertical, game._scroll.get_v_scroll_bar().max_value - game._scroll.size.y])
	await _shot("av_scroll_end")
	h.leave()
	App.home()
	await get_tree().create_timer(0.3).timeout
	var hh := HalliHost.new("Ana")
	if hh.open_room() != "":
		return
	var hg: Screen = load("res://games/halli_galli/screens/halli_wifi_game.gd").new(hh)
	App.push(hg)
	for n in ["Bruno", "Carla", "Davi", "Elisa", "Fábio", "Gabi", "Hugo", "Iara"]:
		hh.rules.apply({"id": "", "host": true, "now": 0}, {"type": "add_player", "id": "id_" + n, "name": n})
	hh._broadcast([])
	await get_tree().create_timer(0.6).timeout
	for xf in [0.5, 0.2]:
		await _drag(xf)
		print("HALLI arrasto em x=%.2f: scroll=%d" % [xf, hg._scroll.scroll_vertical])
	hh.leave()
	App.home()
	await get_tree().create_timer(0.3).timeout
	var ch := HostSession.new("player", "Ana")
	if ch.open_room() != "":
		return
	var cg: Screen = load("res://games/chapeu/screens/chapeu_game.gd").new(ch)
	App.push(cg)
	for n in ["Bruno", "Carla", "Davi", "Elisa", "Fábio", "Gabi", "Hugo", "Iara"]:
		ch.rules.apply({"id": "", "host": true}, {"type": "add_player", "id": "id_" + n, "name": n})
	ch._broadcast([])
	await get_tree().create_timer(0.6).timeout
	await _drag(0.5)
	print("CHAPEU arrasto: scroll=%d de %d" % [cg._scroll.scroll_vertical, cg._scroll.get_v_scroll_bar().max_value - cg._scroll.size.y])
	ch.leave()
	App.home()
	await get_tree().create_timer(0.3).timeout
	for path in ["res://app/screens/home_screen.gd", "res://app/screens/settings_screen.gd", "res://app/screens/history_screen.gd", "res://app/screens/join_screen.gd",
			"res://games/chapeu/screens/chapeu_menu.gd", "res://games/chapeu/screens/how_to_screen.gd", "res://games/chapeu/screens/create_room_screen.gd",
			"res://games/halli_galli/screens/halli_menu.gd", "res://games/halli_galli/screens/halli_how_to.gd", "res://games/halli_galli/screens/halli_create_room.gd",
			"res://games/avalon/screens/avalon_menu.gd", "res://games/avalon/screens/avalon_how_to.gd", "res://games/avalon/screens/avalon_create_room.gd",
			"res://games/secret_hitler/screens/sh_menu.gd", "res://games/secret_hitler/screens/sh_how_to.gd", "res://games/secret_hitler/screens/sh_create_room.gd"]:
		App.home()
		await get_tree().create_timer(0.2).timeout
		if not path.ends_with("home_screen.gd"):
			App.push(load(path).new())
		await get_tree().create_timer(0.5).timeout
		var scs: Array = App.current().find_children("*", "ScrollContainer", true, false)
		if scs.is_empty():
			print("TELA %s: sem scroll" % path.get_file())
			continue
		var sc2: ScrollContainer = scs[0]
		var room := int(sc2.get_v_scroll_bar().max_value - sc2.size.y)
		await _drag(0.5)
		print("TELA %s: scroll=%d de %d %s" % [path.get_file(), sc2.scroll_vertical, room, "OK" if room <= 0 or sc2.scroll_vertical > 0 else "QUEBRADO"])


func _drag(xf: float) -> void:
	var sz := get_viewport().get_visible_rect().size
	var x := sz.x * xf
	var y0 := sz.y * 0.85
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = Vector2(x, y0)
	b.global_position = b.position
	get_viewport().push_input(b, true)
	await get_tree().process_frame
	for i in 15:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.position = Vector2(x, y0 - (i + 1) * 30)
		m.global_position = m.position
		m.relative = Vector2(0, -30)
		get_viewport().push_input(m, true)
		await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = Vector2(x, y0 - 450)
	u.global_position = u.position
	get_viewport().push_input(u, true)
	await get_tree().create_timer(0.4).timeout


## Secret Hitler: cada fase no celular de quem joga (o host, "Ana", presidente) e no tabuleiro.
func _sh() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	await _shot("sh_home")
	App.push(load("res://games/secret_hitler/screens/sh_menu.gd").new())
	await _shot("sh_menu")
	App.push(load("res://games/secret_hitler/screens/sh_how_to.gd").new())
	await _shot("sh_how_to")
	App.home()
	for role in ["player", "board"]:
		var h := ShHost.new(role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/secret_hitler/screens/sh_game.gd").new(h)
		App.push(game)
		var r := h.rules
		var names := ["Bruno", "Carla", "Davi", "Elisa", "Fábio", "Gabi"]
		for i in (names.size() if role == "player" else 7):
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d%d" % i, "name": names[i % names.size()] if i < names.size() else "Hugo"})
		h._broadcast([])
		await _shot("sh_%s_lobby" % role)
		h.send({"type": "start"})
		var ids: Array = r.players.map(func(p): return p.id)
		var me: String = ids[0]
		if role == "player":
			r.roles[me] = "fascista"
			r.roles["d0"] = "hitler"
			r.roles["d1"] = "fascista"
			for k in range(2, 6):
				r.roles["d%d" % k] = "liberal"
		r._rot = 0
		h._broadcast([])
		await _shot("sh_%s_reveal" % role)
		for id in ids:
			r.apply({"id": id, "host": false, "now": 0}, {"type": "ready"})
		r.fascist = 2
		r.liberal = 1
		r.tracker = 1
		r.deck = ["L", "F", "F", "L", "F", "F", "F"]
		h._broadcast([])
		await _shot("sh_%s_nominate" % role)
		var pres: String = r.president
		r.apply({"id": pres, "host": false}, {"type": "nominate", "id": ids[2]})
		for i in range(1, 4):
			r.apply({"id": ids[i], "host": false}, {"type": "vote", "ja": true})
		h._broadcast([])
		await _shot("sh_%s_vote" % role)
		for i in ids.size():
			if not r.votes.has(ids[i]):
				r.apply({"id": ids[i], "host": false}, {"type": "vote", "ja": i % 3 != 0})
		h._broadcast([])
		await _shot("sh_%s_vote_result" % role)
		h.send({"type": "continue"})
		h._broadcast([])
		await _shot("sh_%s_leg_president" % role)
		r.apply({"id": pres, "host": false}, {"type": "discard", "index": 0})
		r.fascist = 4
		h._broadcast([])
		await _shot("sh_%s_leg_waiting" % role)
		r.apply({"id": ids[2], "host": false}, {"type": "enact", "index": 0})
		h._broadcast([])
		await _shot("sh_%s_policy" % role)
		if r.power != "":
			h.send({"type": "continue"})
			h._broadcast([])
			await _shot("sh_%s_power" % role)
			r.apply({"id": pres, "host": false}, {"type": "power", "id": ids[3]})
			h._broadcast([])
			await _shot("sh_%s_power_result" % role)
		r.phase = ShRules.PHASE_POWER
		r.power = "investigate"
		r.president = me if role == "player" else pres
		h._broadcast([])
		await _shot("sh_%s_investigate" % role)
		r.apply({"id": r.president, "host": false}, {"type": "power", "id": ids[4]})
		h._broadcast([])
		await _shot("sh_%s_investigate_result" % role)
		r.phase = ShRules.PHASE_GAME_OVER
		r.winner = "fascista"
		r.win_reason = "hitler_chancellor"
		h._broadcast([])
		await _shot("sh_%s_game_over" % role)
		h.leave()
		App.home()
		await get_tree().create_timer(0.4).timeout


## Todas as cartas de papel do Secret Hitler lado a lado (pra conferir a arte).
func _sh_cards() -> void:
	var sc := Screen.new()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	for e in [["liberal", 0], ["liberal", 1], ["liberal", 2], ["liberal", 3], ["fascista", 0], ["fascista", 1], ["fascista", 2], ["hitler", 0]]:
		var c := ShArt.RoleCard.new(e[0], e[1])
		c.custom_minimum_size = Vector2(170, 255)
		grid.add_child(c)
	App.push(sc)
	await _shot("sh_cards")


const ITO_THEMES := "res://games/ito/data/temas.txt"
const SINT_THEMES := "res://games/sintonia/data/temas.txt"


## Ito: cada fase no celular do host, no tabuleiro e no celular só.
func _ito() -> void:
	App.push(load("res://app/screens/home_screen.gd").new())
	await _shot("ito_home")
	App.push(load("res://games/ito/screens/ito_menu.gd").new())
	await _shot("ito_menu")
	App.push(load("res://games/ito/screens/ito_how_to.gd").new())
	await _shot("ito_how_to")
	App.home()
	for role in ["player", "board"]:
		var h := PartyHost.new("ito", "Ito", ItoRules.new(ThemeBank.load_file(ITO_THEMES), 7), role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/ito/screens/ito_game.gd").new(h)
		App.push(game)
		var r: ItoRules = h.rules
		for n in ["Bruno", "Carla", "Davi"]:
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
		h._broadcast([])
		await _shot("ito_%s_lobby" % role)
		h.send({"type": "start"})
		await _shot("ito_%s_theme" % role)
		r.apply({"id": "d_Bruno", "host": false}, {"type": "pick_theme", "index": 0})
		var ids: Array = r.cards.keys()
		ids.sort_custom(func(a, b): return r.cards[a].n < r.cards[b].n)
		# Metade na fila, com uma troca, e palavras-chave.
		for i in 2:
			var c: Dictionary = r.cards[ids[i]]
			r.apply({"id": c.owner, "host": false}, {"type": "word", "card": c.id, "text": ["um gatinho", "uma vaca", "um leão", "um tubarão"][i]})
			r.apply({"id": c.owner, "host": false}, {"type": "place", "card": c.id, "to": 0})
		h._broadcast([])
		if role == "player":
			var mine: Array = r.cards.keys().filter(func(id): return r.cards[id].owner == h.local_id and id not in r.row)
			if not mine.is_empty():
				game._sel = mine[0]
				game._sel_new = true
				game._rebuild()
		await _shot("ito_%s_play" % role)
		for i in ids.size():
			var c: Dictionary = r.cards[ids[i]]
			if c.id not in r.row:
				r.apply({"id": c.owner, "host": false}, {"type": "place", "card": c.id, "to": r.row.size()})
		r.apply({"id": "d_Bruno", "host": false}, {"type": "move", "card": r.row[0], "to": 2})
		game._sel = ""
		h._broadcast([])
		await _shot("ito_%s_all_placed" % role)
		r.apply({"id": "d_Bruno", "host": false}, {"type": "reveal"})
		h._broadcast([{"type": "phase", "phase": "reveal"}])
		await _shot("ito_%s_reveal_start" % role)
		# O host vira carta por carta; a 3ª (a que foi trocada de lugar) sai fora de ordem.
		for k in 3:
			h.send({"type": "flip"})
			await get_tree().create_timer(0.25 if k == 2 else 0.8).timeout
		await _shot("ito_%s_reveal_mid_anim" % role)
		await get_tree().create_timer(0.6).timeout
		await _shot("ito_%s_reveal_mid" % role)
		while not r.all_shown():
			h.send({"type": "flip"})
			await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(1.2).timeout
		await _shot("ito_%s_reveal" % role)
		r.lives = 1
		r.best = 3
		r.apply({"id": "d_Bruno", "host": false}, {"type": "continue"})
		r.apply({"id": "d_Bruno", "host": false}, {"type": "pick_theme", "index": 1})
		for id in r.cards:
			r.apply({"id": r.cards[id].owner, "host": false}, {"type": "place", "card": id, "to": 0})
		r.apply({"id": "d_Bruno", "host": false}, {"type": "reveal"})
		while not r.all_shown():
			r.apply({"id": "", "host": true}, {"type": "flip"})
		r.apply({"id": "d_Bruno", "host": false}, {"type": "continue"})
		h._broadcast([])
		await _shot("ito_%s_game_over" % role)
		h.leave()
		App.home()
		await get_tree().create_timer(0.4).timeout
	# Celular só.
	var s := PartyLocal.new("ito", ItoRules.new(ThemeBank.load_file(ITO_THEMES), 3))
	var lg: Screen = load("res://games/ito/screens/ito_game.gd").new(s)
	App.push(lg)
	for n in ["Ana", "Bruno", "Carla"]:
		s.send({"type": "add_player", "name": n})
	await _shot("ito_local_lobby")
	s.send({"type": "start"})
	await _shot("ito_local_gate")
	lg._pass_open = true
	lg._rebuild()
	await _shot("ito_local_hand")
	lg._pass_open = false
	lg._pass_round = 1
	lg._rebuild()
	await _shot("ito_local_theme")
	s.send({"type": "pick_theme", "index": 0})
	var lr: ItoRules = s.rules
	var first: String = lr.cards.keys()[0]
	s.send({"type": "place", "card": first, "to": 0})
	await _shot("ito_local_play")
	lg.on_back()
	await get_tree().create_timer(0.3).timeout
	App.home()
	await get_tree().create_timer(0.4).timeout


## Sintonia: cada fase no celular do host, no tabuleiro e no celular só.
func _sintonia() -> void:
	App.push(load("res://games/sintonia/screens/sintonia_menu.gd").new())
	await _shot("sint_menu")
	App.push(load("res://games/sintonia/screens/sintonia_how_to.gd").new())
	await _shot("sint_how_to")
	App.home()
	for role in ["player", "board"]:
		var h := PartyHost.new("sintonia", "Sintonia", SintoniaRules.new(ThemeBank.load_file(SINT_THEMES), 5), role, "Ana")
		if h.open_room() != "":
			return
		var game: Screen = load("res://games/sintonia/screens/sintonia_game.gd").new(h)
		App.push(game)
		var r: SintoniaRules = h.rules
		for n in ["Bruno", "Carla", "Davi", "Elisa"]:
			r.apply({"id": "", "host": true}, {"type": "add_player", "id": "d_" + n, "name": n})
		h._broadcast([])
		await _shot("sint_%s_lobby" % role)
		h.send({"type": "start"})
		var me: String = h.local_id if role == "player" else "d_Bruno"
		var my_team: String = r.player(me).team
		var mate: String = r.team_members(my_team).filter(func(p): return p.id != me)[0].id
		r.turn_team = my_team
		r.psychic = me
		r.target = 68.0
		h._broadcast([])
		await _shot("sint_%s_pick" % role)
		r.apply({"id": me, "host": false}, {"type": "pick_theme", "index": 0})
		r.apply({"id": mate, "host": false}, {"type": "dial", "pos": 41})
		h._broadcast([])
		await _shot("sint_%s_dial_psychic" % role)
		r.psychic = mate
		r.apply({"id": me, "host": false}, {"type": "dial", "pos": 61.5})
		h._broadcast([])
		await _shot("sint_%s_dial_team" % role)
		r.apply({"id": me, "host": false}, {"type": "lock"})
		var rival: String = SintoniaRules.other(my_team)
		r.apply({"id": r.team_members(rival)[0].id, "host": false}, {"type": "side", "side": "right"})
		r.turn_team = rival
		h._broadcast([])
		await _shot("sint_%s_guess_bettor" % role)
		r.turn_team = my_team
		r.apply({"id": r.team_members(rival)[0].id, "host": false}, {"type": "lock_side"})
		h._broadcast([])
		await _shot("sint_%s_reveal" % role)
		r.scores = {"azul": 10, "vermelho": 7}
		r.winner = "azul"
		r.apply({"id": me, "host": false}, {"type": "continue"})
		h._broadcast([])
		await _shot("sint_%s_game_over" % role)
		h.leave()
		App.home()
		await get_tree().create_timer(0.4).timeout
	var s := PartyLocal.new("sintonia", SintoniaRules.new(ThemeBank.load_file(SINT_THEMES), 9))
	var lg: Screen = load("res://games/sintonia/screens/sintonia_game.gd").new(s)
	App.push(lg)
	s.send({"type": "set_config", "mode": "coop"})
	for n in ["Ana", "Bruno", "Carla"]:
		s.send({"type": "add_player", "name": n})
	await _shot("sint_local_lobby")
	s.send({"type": "start"})
	await _shot("sint_local_gate")
	lg._psy_open = true
	lg._rebuild()
	await _shot("sint_local_pick")
	s.send({"type": "pick_theme", "index": 0, "as": s.rules.psychic})
	await _shot("sint_local_hide")
	lg._psy_done = 0
	lg._rebuild()
	await _shot("sint_local_table")
	s.send({"type": "dial", "pos": 30})
	s.send({"type": "lock"})
	await _shot("sint_local_reveal")
	var lr: SintoniaRules = s.rules
	lr.coop_score = 17
	lr.cards_left = 1
	s.send({"type": "continue"})
	s.send({"type": "pick_theme", "index": 0, "as": lr.psychic})
	s.send({"type": "lock"})
	s.send({"type": "continue"})
	await _shot("sint_local_game_over")
	lg.on_back()
	await get_tree().create_timer(0.3).timeout
	App.home()
	await get_tree().create_timer(0.4).timeout
