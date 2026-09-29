class_name PartyMenu
extends Screen
## Menu da Sintonia e do Ito: um celular só, criar sala (jogando ou como tabuleiro), entrar, como jogar.
## Cada jogo estende e preenche `info`:
##   {id, name, icon, desc, local_desc, board_desc, rules: Callable -> regras novas,
##    game: caminho da tela de partida, how_to: caminho do Como jogar,
##    host: Callable(role, nome) -> sessão, se o jogo tiver host próprio (opcional),
##    cover: nome da capa (opcional)}
## Sem local_desc, o jogo não tem o modo de um celular só.

const JoinScreen := preload("res://app/screens/join_screen.gd")

var info := {}


func _ready() -> void:
	var col := make_column()
	var head := make_header(col, info.name)
	head.add_child(UI.icon_button("book", func(): App.push(load(info.how_to).new())))
	var cover: Texture2D = info.cover.call() if info.has("cover") else null
	if cover:
		col.add_child(AvalonArt.Banner.new(cover, 0.2))
	else:
		var ic := UI.texture(info.icon, 190)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
	col.add_child(UI.caption(info.desc))
	col.add_child(UI.spacer(6))
	if info.get("local_desc", "") != "":
		col.add_child(_option("Um celular só", info.local_desc, "phone", AppButton.Variant.PRIMARY, func():
			App.push(load(info.game).new(PartyLocal.new(info.id, info.rules.call())))))
	col.add_child(_option("Criar sala", "Cada um no seu celular, pelo app ou pelo navegador", "wifi", AppButton.Variant.SUCCESS, func():
		App.push(PartyCreateRoom.new(info))))
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
