extends Screen
## Criar sala no Wi-Fi: "Vou jogar" (com nome) ou "Este aparelho é o tabuleiro".

const GameScreen := preload("res://games/chapeu/screens/chapeu_game.gd")

var _name_edit: LineEdit
var _col: VBoxContainer


func _ready() -> void:
	_col = make_column()
	make_header(_col, "Criar sala")
	_col.add_child(UI.caption("Todo mundo precisa estar no mesmo Wi-Fi (ou no roteador do celular de quem cria a sala)."))

	var c := UI.card()
	var v := UI.vbox(16)
	c.add_child(v)
	v.add_child(UI.label("Vou jogar", 26, Tokens.TINTA, Fonts.title()))
	_name_edit = UI.line_edit("Seu nome", Settings.last_name, 20)
	_name_edit.text_submitted.connect(func(_t): _create("player"))
	v.add_child(_name_edit)
	v.add_child(UI.button("Criar sala e jogar", CartoonButton.Variant.SUCCESS, func(): _create("player"), "person"))
	_col.add_child(c)

	var t := UI.card()
	var tv := UI.vbox(12)
	t.add_child(tv)
	tv.add_child(UI.label("Este aparelho é o tabuleiro", 26, Tokens.TINTA, Fonts.title()))
	tv.add_child(UI.label("Ideal pra um tablet no meio da mesa: mostra placar, cronômetro e de quem é a vez. Ele não joga.", 17, Tokens.TINTA_SUAVE))
	tv.add_child(UI.button("Criar sala como tabuleiro", CartoonButton.Variant.PRIMARY, func(): _create("board"), "tablet"))
	_col.add_child(t)


func _create(role: String) -> void:
	var n := TextNorm.clean(_name_edit.text)
	if role == "player":
		if n == "":
			App.toast("Digite seu nome", Tokens.ROSA)
			_name_edit.grab_focus()
			return
		Settings.remember_name(n)
	var s := HostSession.new(role, n)
	var err := s.open_room()
	if err != "":
		s.free()
		App.toast(err, Tokens.ROSA)
		return
	App.replace(GameScreen.new(s))
