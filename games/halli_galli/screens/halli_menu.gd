extends Screen
## Menu do Halli Galli: criar sala e entrar (Wi-Fi, o modo principal), aparelho na mesa, como jogar.

const HowTo := preload("res://games/halli_galli/screens/halli_how_to.gd")
const CreateRoom := preload("res://games/halli_galli/screens/halli_create_room.gd")
const TableGame := preload("res://games/halli_galli/screens/halli_table_game.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")


func _ready() -> void:
	var col := make_column()
	var head := make_header(col, "Halli Galli")
	head.add_child(UI.icon_button("book", func(): App.push(HowTo.new())))
	var art := UI.texture("halli_galli", 190)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	col.add_child(UI.caption("Cada um vira uma carta na sua vez. Deu exatamente 5 de uma fruta na mesa? Bata o sino antes de todo mundo!"))
	col.add_child(UI.spacer(6))
	col.add_child(_option("Criar sala", "Cada um no seu celular, pelo Wi-Fi", "wifi", AppButton.Variant.SUCCESS, func():
		App.push(CreateRoom.new())))
	col.add_child(_option("Entrar numa sala", "Alguém já criou? Entre por aqui", "enter", AppButton.Variant.ACCENT, func():
		App.push(JoinScreen.new())))
	col.add_child(_option("Na mesa", "Um aparelho só no meio, até %d pessoas em volta" % TableGame.max_players(), "tablet", AppButton.Variant.PRIMARY, func():
		App.push(TableGame.new())))


func _option(title_text: String, desc: String, icon_name: String, variant: int, on_press: Callable) -> Control:
	var v := UI.vbox(6)
	var b := UI.button(title_text, variant, on_press, icon_name)
	b.height = 84
	b.font_size = 26
	v.add_child(b)
	v.add_child(UI.caption(desc))
	return v
