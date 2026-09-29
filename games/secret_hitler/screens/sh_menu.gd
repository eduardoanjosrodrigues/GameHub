extends Screen
## Menu do Secret Hitler: criar sala (jogando ou como tabuleiro), entrar, como jogar.

const HowTo := preload("res://games/secret_hitler/screens/sh_how_to.gd")
const CreateRoom := preload("res://games/secret_hitler/screens/sh_create_room.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")


func _ready() -> void:
	var col := make_column()
	var head := make_header(col, "Secret Hitler")
	head.add_child(UI.icon_button("book", func(): App.push(HowTo.new())))
	var cover := ShArt.art_file("capa")
	if cover:
		col.add_child(AvalonArt.Banner.new(cover, 0.2))
	else:
		var ic := UI.texture("secret_hitler", 190)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
	col.add_child(UI.caption("Liberais contra fascistas, e um Hitler escondido na mesa. Ninguém sabe em quem confiar. De 5 a 10 pessoas."))
	col.add_child(UI.spacer(6))
	col.add_child(_option("Criar sala", "Cada um no seu celular, pelo app ou pelo navegador", "wifi", AppButton.Variant.SUCCESS, func():
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
