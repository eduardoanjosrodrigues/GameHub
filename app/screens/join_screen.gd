extends Screen
## Entrar numa sala de qualquer jogo: salas achadas na rede, código da sala ou IP, e dica do QR.
## Pelo código ou QR não dá pra saber o jogo antes; aí pergunta pra sala (RoomProbe).

const ChapeuGame := preload("res://games/chapeu/screens/chapeu_game.gd")
const HalliGame := preload("res://games/halli_galli/screens/halli_wifi_game.gd")
const AvalonGame := preload("res://games/avalon/screens/avalon_game.gd")
const ShGame := preload("res://games/secret_hitler/screens/sh_game.gd")
const GAME_NAMES := {"chapeu": "Chapéu", "halli": "Halli Galli", "avalon": "Avalon", "secret_hitler": "Secret Hitler", "sintonia": "Sintonia", "ito": "Ito", "quem_foi": "Quem Foi?"}
## Jogos de tema (docs/PLANO_SINTONIA_ITO.md): mesma sessão, tela de cada um.
const PARTY_GAMES := {"sintonia": "res://games/sintonia/screens/sintonia_game.gd", "ito": "res://games/ito/screens/ito_game.gd"}

var _prefill_code := ""
var _seat_token := ""
var _name_edit: LineEdit
var _code_edit: LineEdit
var _rooms_box: VBoxContainer
var _scanner: LanDiscovery
var _as_board := false
var _board_btn: AppButton
var _connecting := false


## seat_token: veio de um QR "Trocar aparelho": entra direto na vaga de alguém, sem pedir nome.
func _init(code := "", seat_token := "") -> void:
	super()
	_prefill_code = code
	_seat_token = seat_token


func _ready() -> void:
	var col := make_column()
	make_header(col, "Entrar numa sala")

	var nc := UI.card()
	var nv := UI.vbox(12)
	nc.add_child(nv)
	nv.add_child(UI.label("Seu nome", 22, Tokens.TINTA, Fonts.title()))
	_name_edit = UI.line_edit("Como te chamam?", Settings.last_name, 20)
	nv.add_child(_name_edit)
	_board_btn = UI.small_button("Entrar como tabuleiro (não joga)", AppButton.Variant.SECONDARY, _toggle_board, "tablet")
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
	var go := UI.small_button("Entrar", AppButton.Variant.SUCCESS, _join_by_code)
	go.custom_minimum_size.x = 130
	row.add_child(go)
	cv.add_child(row)
	col.add_child(cc)

	var qc := UI.card(Tokens.MOSTARDA)
	var qr := UI.hbox(14)
	qc.add_child(qr)
	qr.add_child(UI.texture("qr", 48, Tokens.TINTA))
	qr.add_child(UI.label("Tem QR code na tela do host? Aponte a câmera do seu celular pra ele: o gamehub abre direto na sala.", 17, Tokens.TINTA, Fonts.body_bold()))
	qr.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(qc)

	col.add_child(UI.label("Não achou a sala? Algumas redes (hotel, empresa) bloqueiam um celular de falar com o outro. Tente usar o roteador do celular de quem criou a sala.", 15, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))

	_start_scanner()
	if _prefill_code != "" and _seat_token != "":
		_join_by_code.call_deferred()
	elif _prefill_code != "" and Settings.last_name != "":
		_join_by_code.call_deferred()


func _start_scanner() -> void:
	_scanner = LanDiscovery.scanner()
	add_child(_scanner)
	_scanner.rooms_changed.connect(_show_rooms)
	_show_rooms([])


func _toggle_board() -> void:
	_as_board = not _as_board
	_board_btn.selected = _as_board
	_board_btn.variant = AppButton.Variant.PRIMARY if _as_board else AppButton.Variant.SECONDARY
	_board_btn.text = "Entrando como tabuleiro" if _as_board else "Entrar como tabuleiro (não joga)"


func _show_rooms(rooms: Array) -> void:
	UI.clear(_rooms_box)
	if rooms.is_empty():
		_rooms_box.add_child(UI.label("Procurando salas...", 18, Tokens.TINTA_SUAVE, Fonts.body_bold()))
		return
	for r in rooms:
		var game: String = str(r.get("jogo", "chapeu"))
		var b := UI.button("%s  ·  %s  ·  %d" % [GAME_NAMES.get(game, "?"), r.get("nome", "Sala"), int(r.get("jogadores", 0))], AppButton.Variant.PRIMARY)
		b.font_size = 20
		var ip: String = r.ip
		b.pressed.connect(func(): _join(ip, game))
		_rooms_box.add_child(b)


func _join_by_code() -> void:
	var raw := _code_edit.text.strip_edges()
	var ip := raw if raw.is_valid_ip_address() else RoomCode.decode(raw)
	if ip == "":
		App.toast("Código inválido. Confira as letras.", Tokens.VERMELHO)
		return
	_join(ip)


func _join(ip: String, game := "") -> void:
	if _connecting:
		return
	var n := TextNorm.clean(_name_edit.text)
	if n == "" and not _as_board and _seat_token == "":
		App.toast("Digite seu nome", Tokens.VERMELHO)
		_name_edit.grab_focus()
		return
	if n != "" and _seat_token == "":
		Settings.remember_name(n)
	_connecting = true
	App.toast("Entrando na sala...")
	if _scanner:
		_scanner.queue_free()
		_scanner = null
	if game != "":
		_open(ip, game, n)
		return
	var probe := RoomProbe.new(ip)
	probe.found.connect(func(g): _open(ip, g, n))
	probe.failed.connect(func():
		_connecting = false
		App.toast("Não consegui falar com a sala. Confira se vocês estão no mesmo Wi-Fi.", Tokens.VERMELHO)
		_start_scanner())
	add_child(probe)


func _open(ip: String, game: String, n: String) -> void:
	match game:
		"halli":
			if _as_board:
				_connecting = false
				App.toast("O Halli Galli não tem tabuleiro: entre como jogador.", Tokens.VERMELHO)
				return
			var hc := HalliClient.new(ip, n)
			hc.seat_token = _seat_token
			App.replace(HalliGame.new(hc))
		"avalon":
			var ac := AvalonClient.new(ip, n, "player" if _seat_token != "" or not _as_board else "board")
			ac.seat_token = _seat_token
			App.replace(AvalonGame.new(ac))
		"secret_hitler":
			var sc := ShClient.new(ip, n, "player" if _seat_token != "" or not _as_board else "board")
			sc.seat_token = _seat_token
			App.replace(ShGame.new(sc))
		"quem_foi":
			var qc := QuemFoiClient.new(ip, n, "player" if _seat_token != "" or not _as_board else "board")
			qc.seat_token = _seat_token
			App.replace(load("res://games/quem_foi/screens/quem_foi_game.gd").new(qc))
		"sintonia", "ito":
			var pc := PartyClient.new(game, ip, n, "player" if _seat_token != "" or not _as_board else "board")
			pc.seat_token = _seat_token
			App.replace(load(PARTY_GAMES[game]).new(pc))
		_:
			var cc := ClientSession.new(ip, n, "player" if _seat_token != "" or not _as_board else "board")
			cc.seat_token = _seat_token
			App.replace(ChapeuGame.new(cc))
