extends Screen
## Halli Galli com um aparelho só no meio da mesa: preparação (nomes e baralhos), jogo e fim.

const MENU_PATH := "res://games/halli_galli/screens/halli_menu.gd"
const PHONE_MAX := 4

var session: HalliLocal
var v := {}
var _scroll: ScrollContainer
var _root: VBoxContainer
var _tv: HalliTableView
var _exit_btn: AppButton
var _name_edit: LineEdit
var _last_phase := ""
var _history_saved := false


func _init() -> void:
	super()
	session = HalliLocal.new()


func _ready() -> void:
	add_child(session)
	session.view_changed.connect(_on_view)
	session.rejected.connect(func(m): if v.get("phase", "") != HalliRules.PHASE_PLAYING: App.toast(m, Tokens.VERMELHO))
	var mw := MaxWidth.new()
	mw.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mw)
	_scroll = UI.scroll()
	mw.add_child(_scroll)
	var m := UI.margin(20, 20, 32)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(m)
	_root = UI.vbox(18)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(_root)
	_tv = HalliTableView.new()
	_tv.visible = false
	_tv.flip_requested.connect(_on_flip)
	_tv.bell_requested.connect(_on_bell)
	add_child(_tv)
	# Sair: botão pequeno no meio da tela, longe das áreas de toque de cada um.
	_exit_btn = UI.icon_button("pause", func(): on_back())
	_exit_btn.visible = false
	add_child(_exit_btn)
	_on_view(session.view, [])


## Até 6 no tablet, até 4 no celular (§2). No PC, libera 6 pra testar.
static func max_players() -> int:
	if not OS.has_feature("mobile"):
		return HalliRules.MAX_PLAYERS_TABLE
	var dpi := maxi(1, DisplayServer.screen_get_dpi())
	var s := DisplayServer.screen_get_size()
	var short_in := minf(s.x, s.y) / float(dpi)
	return HalliRules.MAX_PLAYERS_TABLE if short_in >= 3.4 else PHONE_MAX


func on_back() -> bool:
	if v.get("phase", "") == HalliRules.PHASE_PLAYING:
		App.confirm("Sair da partida?", "A partida em andamento vai acabar.", "Sair", _leave)
	else:
		_leave()
	return true


func _leave() -> void:
	App.back_to(load(MENU_PATH))


func _on_view(nv: Dictionary, events: Array) -> void:
	v = nv
	var phase: String = v.phase
	var playing := phase == HalliRules.PHASE_PLAYING
	if phase != _last_phase:
		_tv.visible = playing
		_scroll.visible = not playing
		_exit_btn.visible = playing
		music = "" if playing else "menu"
		Audio.music(music)
		if phase == HalliRules.PHASE_GAME_OVER and not _history_saved:
			_history_saved = true
			History.add(HalliResults.history_entry(v, "table"))
		if phase != HalliRules.PHASE_GAME_OVER:
			_history_saved = false
	match phase:
		HalliRules.PHASE_LOBBY:
			_build_setup()
		HalliRules.PHASE_PLAYING:
			_update_table()
		HalliRules.PHASE_GAME_OVER:
			if phase != _last_phase:
				_build_game_over()
	_handle_events(events)
	_last_phase = phase


func _process(_delta: float) -> void:
	if v.get("phase", "") == HalliRules.PHASE_PLAYING:
		_update_table()
		_exit_btn.position = (size - _exit_btn.size) / 2.0


func _update_table() -> void:
	var now := session.now_ms()
	var ready := clampf(1.0 - (int(v.next_flip_at) - now) / float(HalliRules.FLIP_COOLDOWN_MS), 0.0, 1.0)
	var zones: Array = []
	for p in v.players:
		zones.append({
			"id": p.id, "name": p.name, "color": p.color, "top": p.top, "up": p.up, "down": p.down,
			"out": p.out, "turn": p.id == v.turn, "ready": ready, "recycle": v.get("recycle", false),
		})
	_tv.set_zones(zones)


func _on_flip(id: String) -> void:
	if v.get("phase", "") != HalliRules.PHASE_PLAYING or id != v.turn:
		return
	if session.now_ms() < int(v.next_flip_at):
		return
	Audio.sfx("hg_flip")
	session.send({"type": "flip", "player": id})


func _on_bell(id: String, local_us: int) -> void:
	if v.get("phase", "") != HalliRules.PHASE_PLAYING:
		return
	var p := _player(id)
	if p.is_empty() or p.out:
		return
	Audio.sfx("hg_bell")
	Haptics.hg_bell_tap()
	session.send({"type": "bell", "player": id, "local_us": local_us})


func _player(id: String) -> Dictionary:
	for p in v.get("players", []):
		if p.id == id:
			return p
	return {}


func _handle_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"bell":
				if e.ok:
					Audio.sfx("hg_collect")
					var t := "+%d" % int(e.cards)
					if int(e.get("margin_ms", -1)) >= 0:
						t += " · %d ms" % int(e.margin_ms)
					_tv.banner(e.player, t, Tokens.SALVIA)
				else:
					Audio.sfx("hg_wrong")
					Haptics.hg_wrong()
					_tv.banner(e.player, "Errou! −%d" % int(e.cards), Tokens.VERMELHO)
			"back_in":
				_tv.banner(e.player, "Voltou!", Tokens.SALVIA)
			"out":
				Audio.sfx("hg_out")
				_tv.banner(e.player, "Saiu", Tokens.TINTA)
			"recycle":
				Audio.sfx("hg_flip")
				for p in v.players:
					if not p.out:
						_tv.banner(p.id, "Mesa desvirada", Tokens.MOSTARDA)
			"game_over":
				Audio.sfx("win")
				Haptics.hg_victory()
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 70, Confetti.COLORS, 2.6)


# --- Preparação ------------------------------------------------------------

func _header(title_text: String) -> void:
	var row := UI.hbox(16)
	row.add_child(UI.icon_button("back", func(): on_back()))
	var t := UI.title(title_text, 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	_root.add_child(row)


func _build_setup() -> void:
	var name_focused := _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus()
	UI.clear(_root)
	_header("Na mesa")
	var limit := max_players()
	var list: Array = v.players

	var add := UI.card()
	var av := UI.vbox(12)
	add.add_child(av)
	av.add_child(UI.label("Quem vai jogar?", 24, Tokens.TINTA, Fonts.title()))
	if list.size() < limit:
		var row := UI.hbox(12)
		_name_edit = UI.line_edit("Nome do jogador", "", 20)
		_name_edit.text_submitted.connect(func(_t): _add_player())
		row.add_child(_name_edit)
		row.add_child(UI.icon_button("plus", _add_player, AppButton.Variant.SUCCESS))
		av.add_child(row)
	av.add_child(UI.label("De 2 a %d jogadores. Na ordem em que vão sentar em volta do aparelho, começando por quem fica de frente pra parte de baixo da tela." % limit, 16, Tokens.TINTA_SUAVE))
	for i in list.size():
		var p: Dictionary = list[i]
		var prow := UI.player_row("%d. %s" % [i + 1, p.name], HalliArt.player_color(int(p.color)))
		var pid: String = p.id
		var up := UI.icon_button("up", func(): session.send({"type": "move_player", "id": pid, "dir": -1}))
		up.disabled = i == 0
		prow.add_child(up)
		prow.add_child(UI.icon_button("close", func(): session.send({"type": "remove_player", "id": pid})))
		av.add_child(prow)
	_root.add_child(add)

	if list.size() >= 2:
		_root.add_child(_seat_preview(list))

	var decks := int(v.config.decks)
	var dc := UI.card(Tokens.PAPEL, 20)
	var dv := UI.vbox(10)
	dc.add_child(dv)
	dv.add_child(UI.label("Baralhos", 22, Tokens.TINTA, Fonts.title()))
	dv.add_child(UI.stepper(decks, HalliRules.DECKS_RANGE.x, HalliRules.DECKS_RANGE.y, 1, func(x): session.send({"type": "set_config", "decks": x})))
	dv.add_child(UI.label("%d cartas no total" % (decks * 56), 17, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(dc)

	var why: String = v.can_start
	var b := UI.button("Começar", AppButton.Variant.SUCCESS, func(): session.send({"type": "start"}), "play")
	b.height = 84
	b.font_size = 26
	b.disabled = why != ""
	_root.add_child(b)
	if why != "":
		_root.add_child(UI.caption(why))
	if name_focused and _name_edit:
		_name_edit.grab_focus.call_deferred()


## Mini-mapa de onde cada um senta em volta da tela.
func _seat_preview(list: Array) -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Onde cada um senta", 22, Tokens.TINTA, Fonts.title()))
	var map := SeatMap.new()
	map.players = list
	map.custom_minimum_size = Vector2(0, 300)
	cv.add_child(map)
	return c


func _add_player() -> void:
	var n := TextNorm.clean(_name_edit.text)
	if n == "":
		_name_edit.grab_focus()
		return
	session.send({"type": "add_player", "name": n})


# --- Fim -------------------------------------------------------------------

func _build_game_over() -> void:
	UI.clear(_root)
	_scroll.scroll_vertical = 0
	var win := _player(v.winner)
	_root.add_child(UI.spacer(10))
	var bg: Color = HalliArt.player_color(int(win.color)) if not win.is_empty() else Tokens.MOSTARDA
	var c := UI.card(bg, 30)
	var cv := UI.vbox(10)
	c.add_child(cv)
	var trophy := UI.texture("trophy", 110, Tokens.TINTA)
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(trophy)
	var tl := UI.title("%s venceu!" % win.get("name", "") if not win.is_empty() else "Fim de jogo", 48)
	cv.add_child(tl)
	_root.add_child(c)
	_root.add_child(HalliResults.ranking_card(v))
	_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


## Desenho da tela com a área de cada jogador (mesma divisão da partida).
class SeatMap extends Control:
	var players: Array = []

	func _draw() -> void:
		var h := size.y
		var w := h * 720.0 / 1280.0
		var origin := Vector2((size.x - w) / 2.0, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tokens.PAPEL
		sb.border_color = Tokens.TINTA
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		draw_style_box(sb, Rect2(origin, Vector2(w, h)))
		var lay := HalliTableView.layout_for(players.size(), Vector2(w, h))
		var font := Fonts.body_bold()
		for i in lay.size():
			var r: Rect2 = lay[i].rect
			r.position += origin
			var col := HalliArt.player_color(int(players[i].color))
			var z := StyleBoxFlat.new()
			z.bg_color = Tokens.tint(col, 0.35)
			z.border_color = col
			z.set_border_width_all(2)
			z.set_corner_radius_all(10)
			draw_style_box(z, r.grow(-4))
			var txt: String = "%d. %s" % [i + 1, players[i].name]
			draw_set_transform(r.get_center(), lay[i].rot, Vector2.ONE)
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(-tw / 2.0, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tokens.TINTA)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
