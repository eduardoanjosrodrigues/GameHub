extends Screen
## Menu do Genius (docs/PLANO_GENIUS.md §3): solo, passa o aparelho, Corrida no Wi-Fi e como jogar.

const JoinScreen := preload("res://app/screens/join_screen.gd")


func _ready() -> void:
	var col := make_column()
	var head := make_header(col, "Genius")
	head.add_child(UI.icon_button("book", func(): App.push(load("res://games/genius/screens/genius_how_to.gd").new())))
	var ic := UI.texture("genius", 170)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var b := GeniusStore.best()
	col.add_child(UI.label("Seu recorde: %d cor%s" % [b, "" if b == 1 else "es"] if b > 0 else "O Genius toca as cores, você repete. A cada acerto, uma cor a mais.", 19, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.spacer(6))
	col.add_child(_option("Jogar", "Sozinho: até onde vai a sua memória?", "play", AppButton.Variant.PRIMARY, func():
		App.push(load("res://games/genius/screens/genius_solo.gd").new())))
	col.add_child(_option("Passa o aparelho", "Um celular só: cada um repete, e a sequência cresce pro próximo", "phone", AppButton.Variant.ACCENT, func():
		App.push(load("res://games/genius/screens/genius_game.gd").new(PartyLocal.new("genius", GeniusRules.new())))))
	col.add_child(_option("Criar sala", "Corrida: todos repetem a mesma sequência, cada um no seu celular ou no navegador", "wifi", AppButton.Variant.SUCCESS, func():
		App.push(load("res://games/genius/screens/genius_create_room.gd").new())))
	col.add_child(_option("Entrar numa sala", "Alguém já criou? Entre por aqui", "enter", AppButton.Variant.SECONDARY, func():
		App.push(JoinScreen.new())))


func _option(title_text: String, desc: String, icon_name: String, variant: int, on_press: Callable) -> Control:
	var v := UI.vbox(6)
	var btn := UI.button(title_text, variant, on_press, icon_name)
	btn.height = 84
	btn.font_size = 26
	v.add_child(btn)
	v.add_child(UI.caption(desc))
	return v
