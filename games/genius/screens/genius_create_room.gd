extends Screen
## Criar sala da Corrida do Genius: só com o nome (o Genius não tem tabuleiro).

var _name_edit: LineEdit


func _ready() -> void:
	var col := make_column()
	make_header(col, "Criar sala")
	col.add_child(UI.caption("Todo mundo precisa estar no mesmo Wi-Fi (ou no roteador do celular de quem cria a sala). Quem não tem o app entra pelo navegador."))
	var c := UI.card()
	var v := UI.vbox(16)
	c.add_child(v)
	v.add_child(UI.label("Vou jogar", 26, Tokens.TINTA, Fonts.title()))
	_name_edit = UI.line_edit("Seu nome", Settings.last_name, 20)
	_name_edit.text_submitted.connect(func(_t): _create())
	v.add_child(_name_edit)
	v.add_child(UI.button("Criar sala e jogar", AppButton.Variant.SUCCESS, _create, "person"))
	col.add_child(c)


func _create() -> void:
	var n := TextNorm.clean(_name_edit.text)
	if n == "":
		App.toast("Digite seu nome", Tokens.VERMELHO)
		_name_edit.grab_focus()
		return
	Settings.remember_name(n)
	var s := GeniusHost.new(n)
	var err := s.open_room()
	if err != "":
		s.free()
		App.toast(err, Tokens.VERMELHO)
		return
	App.replace(load("res://games/genius/screens/genius_game.gd").new(s))
