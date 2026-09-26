extends Screen
## Início do hub: logo, grade de jogos, Histórico e Configurações.

const ChapeuMenu := preload("res://games/chapeu/screens/chapeu_menu.gd")
const SettingsScreen := preload("res://app/screens/settings_screen.gd")
const HistoryScreen := preload("res://app/screens/history_screen.gd")
const JoinScreen := preload("res://games/chapeu/screens/join_screen.gd")

## Catálogo de jogos. Os próximos entram aqui.
const GAMES := [
	{"id": "chapeu", "nome": "Chapéu", "desc": "Explique, resuma e faça mímica. Festa garantida!", "icone": "chapeu", "cor": Tokens.AZUL, "pronto": true},
	{"id": "em_breve_1", "nome": "Em breve", "desc": "Novo jogo chegando", "icone": "em_breve", "cor": Tokens.SUPERFICIE, "pronto": false},
	{"id": "em_breve_2", "nome": "Em breve", "desc": "Novo jogo chegando", "icone": "em_breve", "cor": Tokens.SUPERFICIE, "pronto": false},
]


func _ready() -> void:
	var col := make_column(true, 28, 22)
	var top := UI.hbox(12)
	top.add_child(UI.spacer(0, true))
	top.add_child(UI.icon_button("history", func(): App.push(HistoryScreen.new())))
	top.add_child(UI.icon_button("settings", func(): App.push(SettingsScreen.new())))
	col.add_child(top)
	col.add_child(Logo.new(80))
	col.add_child(UI.caption("Joguinhos pra jogar junto"))
	col.add_child(UI.spacer(4))

	var featured: Dictionary = GAMES[0]
	col.add_child(_featured_card(featured))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for i in range(1, GAMES.size()):
		grid.add_child(_small_card(GAMES[i]))
	col.add_child(grid)
	App.deep_link.connect(_on_deep_link)
	# Aberto por um QR antes da tela existir.
	var pending := App.take_pending_link()
	if pending != "":
		_on_deep_link.call_deferred(pending)


func _on_deep_link(code: String) -> void:
	if App.current() == self:
		App.take_pending_link()
		App.push(JoinScreen.new(code))


func _featured_card(g: Dictionary) -> Control:
	var c := UI.card(g.cor, 24)
	var v := UI.vbox(14)
	c.add_child(v)
	var row := UI.hbox(16)
	var ic := UI.texture(g.icone, 150)
	row.add_child(ic)
	var tv := UI.vbox(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(UI.label(g.nome, 44, Tokens.TINTA, Fonts.title_bold()))
	tv.add_child(UI.label(g.desc, 18, Tokens.TINTA, Fonts.body_bold()))
	row.add_child(tv)
	v.add_child(row)
	var play := UI.button("Jogar", AppButton.Variant.ACCENT, func(): App.push(ChapeuMenu.new()), "play")
	v.add_child(play)
	ic.pivot_offset = Vector2(75, 75)
	var tw := ic.create_tween().set_loops()
	tw.tween_property(ic, "rotation", deg_to_rad(-4), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ic, "rotation", deg_to_rad(4), 0.9).set_trans(Tween.TRANS_SINE)
	return c


func _small_card(g: Dictionary) -> Control:
	var c := UI.card(g.cor, 18)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var ic := UI.texture(g.icone, 84)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UI.label(g.nome, 22, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(g.desc, 14, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	if not g.pronto:
		c.modulate = Color(1, 1, 1, 0.7)
	return c
