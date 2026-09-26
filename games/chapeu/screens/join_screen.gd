extends Screen
## Entrar numa sala: salas achadas na rede, código da sala ou IP, e dica do QR.

const GameScreen := preload("res://games/chapeu/screens/chapeu_game.gd")

var _prefill_code := ""
var _name_edit: LineEdit
var _code_edit: LineEdit
var _rooms_box: VBoxContainer
var _scanner: LanDiscovery
var _as_board := false
var _board_btn: CartoonButton
var _connecting := false


func _init(code := "") -> void:
	super()
	_prefill_code = code


func _ready() -> void:
	var col := make_column()
	make_header(col, "Entrar numa sala")

	var nc := UI.card()
	var nv := UI.vbox(12)
	nc.add_child(nv)
	nv.add_child(UI.label("Seu nome", 22, Tokens.TINTA, Fonts.title()))
	_name_edit = UI.line_edit("Como te chamam?", Settings.last_name, 20)
	nv.add_child(_name_edit)
	_board_btn = UI.small_button("Entrar como tabuleiro (não joga)", CartoonButton.Variant.SECONDARY, _toggle_board, "tablet")
	nv.add_child(_board_btn)
	col.add_child(nc)

	var rc := UI.card()
	var rv := UI.vbox(12)
	rc.add_child(rv)
	var head := UI.hbox(10)
	head.add_child(UI.texture("wifi", 32, Tokens.TINTA))
	var hl := UI.label("Salas na sua rede", 22, Tokens.TINTA, Fonts.title())
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	rv.add_child(head)
	_rooms_box = UI.vbox(10)
	rv.add_child(_rooms_box)
	col.add_child(rc)

	var cc := UI.card()
	var cv := UI.vbox(12)
	cc.add_child(cv)
	cv.add_child(UI.label("Código da sala", 22, Tokens.TINTA, Fonts.title()))
	cv.add_child(UI.label("Aparece na tela de quem criou a sala. Também dá pra digitar o IP.", 16, Tokens.TINTA_SUAVE))
	var row := UI.hbox(12)
	_code_edit = UI.line_edit("ABC-123", RoomCode.pretty(_prefill_code), 15)
	_code_edit.text_submitted.connect(func(_t): _join_by_code())
	row.add_child(_code_edit)
	var go := UI.small_button("Entrar", CartoonButton.Variant.SUCCESS, _join_by_code)
	go.custom_minimum_size.x = 130
	row.add_child(go)
	cv.add_child(row)
	col.add_child(cc)

	var qc := UI.card(Tokens.LIMA)
	var qr := UI.hbox(14)
	qc.add_child(qr)
	qr.add_child(UI.texture("qr", 48, Tokens.TINTA))
	qr.add_child(UI.label("Tem QR code na tela do host? Aponte a câmera do seu celular pra ele: o gamehub abre direto na sala.", 17, Tokens.TINTA, Fonts.body_bold()))
	qr.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(qc)

	col.add_child(UI.label("Não achou a sala? Algumas redes (hotel, empresa) bloqueiam um celular de falar com o outro. Tente usar o roteador do celular de quem criou a sala.", 15, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))

	_scanner = LanDiscovery.scanner()
	add_child(_scanner)
	_scanner.rooms_changed.connect(_show_rooms)
	_show_rooms([])
	if _prefill_code != "" and Settings.last_name != "":
		_join_by_code.call_deferred()


func _toggle_board() -> void:
	_as_board = not _as_board
	_board_btn.selected = _as_board
	_board_btn.variant = CartoonButton.Variant.PRIMARY if _as_board else CartoonButton.Variant.SECONDARY
	_board_btn.text = "Entrando como tabuleiro" if _as_board else "Entrar como tabuleiro (não joga)"


func _show_rooms(rooms: Array) -> void:
	UI.clear(_rooms_box)
	if rooms.is_empty():
		_rooms_box.add_child(UI.label("Procurando salas...", 18, Tokens.TINTA_SUAVE, Fonts.body_bold()))
		return
	for r in rooms:
		var b := UI.button("%s  ·  %d jogadores" % [r.get("nome", "Sala"), int(r.get("jogadores", 0))], CartoonButton.Variant.PRIMARY)
		b.font_size = 20
		var ip: String = r.ip
		b.pressed.connect(func(): _join(ip))
		_rooms_box.add_child(b)


func _join_by_code() -> void:
	var raw := _code_edit.text.strip_edges()
	var ip := raw if raw.is_valid_ip_address() else RoomCode.decode(raw)
	if ip == "":
		App.toast("Código inválido. Confira as letras.", Tokens.ROSA)
		return
	_join(ip)


func _join(ip: String) -> void:
	if _connecting:
		return
	var n := TextNorm.clean(_name_edit.text)
	if n == "" and not _as_board:
		App.toast("Digite seu nome", Tokens.ROSA)
		_name_edit.grab_focus()
		return
	if n != "":
		Settings.remember_name(n)
	_connecting = true
	App.toast("Entrando na sala...")
	if _scanner:
		_scanner.queue_free()
		_scanner = null
	var s := ClientSession.new(ip, n, "board" if _as_board else "player")
	App.replace(GameScreen.new(s))
