extends Screen
## Criar sala de Secret Hitler: "Vou jogar" (com nome) ou "Este aparelho é o tabuleiro".

const GameScreen := preload("res://games/secret_hitler/screens/sh_game.gd")

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
	_name_edit.text_submitted.connect(func(_t): _create("player"))
	v.add_child(_name_edit)
	v.add_child(UI.button("Criar sala e jogar", AppButton.Variant.SUCCESS, func(): _create("player"), "person"))
	col.add_child(c)
	var t := UI.card()
	var tv := UI.vbox(12)
	t.add_child(tv)
	tv.add_child(UI.label("Este aparelho é o tabuleiro", 26, Tokens.TINTA, Fonts.title()))
	tv.add_child(UI.label("Ideal pra um tablet no meio da mesa: mostra as leis, o governo e os votos. Ele não joga. Uma TV ou notebook também pode ser o tabuleiro, pelo navegador.", 17, Tokens.TINTA_SUAVE))
	tv.add_child(UI.button("Criar sala como tabuleiro", AppButton.Variant.PRIMARY, func(): _create("board"), "tablet"))
	col.add_child(t)


func _create(role: String) -> void:
	var n := TextNorm.clean(_name_edit.text)
	if role == "player":
		if n == "":
			App.toast("Digite seu nome", Tokens.VERMELHO)
			_name_edit.grab_focus()
			return
		Settings.remember_name(n)
	var s := ShHost.new(role, n)
	var err := s.open_room()
	if err != "":
		s.free()
		App.toast(err, Tokens.VERMELHO)
		return
	App.replace(GameScreen.new(s))
