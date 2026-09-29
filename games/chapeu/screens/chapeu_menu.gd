extends Screen
## Menu do Chapéu: passa-e-joga, criar sala, entrar, como jogar.

const HowTo := preload("res://games/chapeu/screens/how_to_screen.gd")
const CreateRoom := preload("res://games/chapeu/screens/create_room_screen.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")
const GameScreen := preload("res://games/chapeu/screens/chapeu_game.gd")


func _ready() -> void:
	var col := make_column()
	var head := make_header(col, "Chapéu")
	head.add_child(UI.icon_button("book", func(): App.push(HowTo.new())))
	var hat := UI.texture("chapeu", 190)
	hat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(hat)
	col.add_child(UI.caption("Cada um escreve palavras, tudo vai pro chapéu, e os times tentam adivinhar em 3 rodadas."))
	col.add_child(UI.spacer(6))
	col.add_child(_option("Passa-e-joga", "Um celular só, passando de mão em mão", "phone", AppButton.Variant.PRIMARY, func():
		App.push(GameScreen.new(LocalSession.new()))))
	col.add_child(_option("Criar sala", "Cada um no seu celular, pelo Wi-Fi", "wifi", AppButton.Variant.SUCCESS, func():
		App.push(CreateRoom.new())))
	col.add_child(_option("Entrar numa sala", "Alguém já criou? Entre por aqui", "enter", AppButton.Variant.ACCENT, func():
		App.push(JoinScreen.new())))


func _option(title_text: String, desc: String, icon_name: String, variant: int, on_press: Callable) -> Control:
	var v := UI.vbox(6)
	var b := UI.button(title_text, variant, on_press, icon_name)
	b.height = 84
	b.font_size = 26
	v.add_child(b)
	v.add_child(UI.caption(desc))
	return v
