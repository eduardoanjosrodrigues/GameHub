class_name SeatSwap
extends ColorRect
## "Trocar aparelho": o host ou o tabuleiro escolhe alguém e mostra um QR que só serve pra vaga
## dessa pessoa (net/seat_transfer.gd). O aparelho que ler entra no lugar dela. Serve aos três jogos
## em rede: a sessão só precisa de request_seat(id) e do sinal seat_link(id, token).

var session: Node
var players: Array = [] # [{id, name, connected, color}]
var host_ip := ""
var room_code := ""
var _big := false
var _col: VBoxContainer
var _seat := ""
var _token := ""
var _web := true
var _was_connected := false


## players: quem pode ter a vaga trocada (sem o host). big: tela grande (tabuleiro).
static func open(parent: Control, p_session: Node, p_players: Array, p_host_ip: String, p_room_code: String, big := false) -> SeatSwap:
	var s := SeatSwap.new()
	s.session = p_session
	s.players = p_players
	s.host_ip = p_host_ip
	s.room_code = p_room_code
	s._big = big
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(s)
	return s


func _ready() -> void:
	# Fundo opaco: quem vem ler o QR no celular do host não pode ver o papel dele por trás.
	color = Tokens.PAPEL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sc := UI.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sc)
	var mw := MaxWidth.new(640.0)
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mw)
	var m := UI.margin(20, 40, 40)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.add_child(m)
	var c := UI.card(Tokens.SUPERFICIE, 24)
	m.add_child(c)
	_col = UI.vbox(14)
	c.add_child(_col)
	session.seat_link.connect(_on_link)
	session.error.connect(_on_error)
	_build_list()


## Estado novo da partida: atualiza a lista e fecha sozinho quando a pessoa volta no aparelho novo.
func set_players(p_players: Array) -> void:
	players = p_players
	if _seat == "":
		_build_list()
		return
	var p := _find(_seat)
	if p.is_empty():
		close()
	elif _token != "" and p.connected and not _was_connected:
		App.toast("%s entrou no aparelho novo." % p.name, Tokens.SALVIA)
		close()


func close() -> void:
	queue_free()


func _find(id: String) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}


func _build_list() -> void:
	UI.clear(_col)
	_col.add_child(UI.title("Trocar aparelho", 30))
	_col.add_child(UI.caption("A bateria de alguém acabou ou o celular travou? Escolha a pessoa e leia o QR com outro aparelho. Ele entra no lugar dela, com tudo que ela tinha."))
	for p in players:
		var row := UI.player_row(p.name, p.get("color", Tokens.AZUL), p.connected, "" if p.connected else "desconectado")
		var pid: String = p.id
		var pname: String = p.name
		var conn: bool = p.connected
		var b := UI.small_button("Trocar", AppButton.Variant.PRIMARY if not conn else AppButton.Variant.SECONDARY, func(): _pick(pid, pname, conn), "phone")
		b.custom_minimum_size.x = 140
		row.add_child(b)
		_col.add_child(row)
	_col.add_child(UI.button("Fechar", AppButton.Variant.SECONDARY, close))


func _pick(id: String, pname: String, connected: bool) -> void:
	if connected:
		App.confirm("Trocar o aparelho de %s?" % pname, "%s ainda está conectado. Quando o outro aparelho ler o QR, o de agora sai da partida." % pname, "Trocar", func(): _ask(id, connected), "Cancelar", false)
	else:
		_ask(id, connected)


func _ask(id: String, connected: bool) -> void:
	_seat = id
	_token = ""
	_was_connected = connected
	UI.clear(_col)
	_col.add_child(UI.title("Abrindo o QR...", 30))
	session.request_seat(id)


func _on_error(_message: String) -> void:
	# O host recusou (a tela do jogo já mostra o aviso): volta pra lista.
	if _seat != "" and _token == "":
		_seat = ""
		_build_list()


func _on_link(seat: String, token: String) -> void:
	if seat != _seat:
		return
	_token = token
	_build_qr()


func _web_url() -> String:
	return "http://%s:%d/?v=%s" % [host_ip, WebGateway.HTTP_PORT, _token]


func _build_qr() -> void:
	UI.clear(_col)
	var p := _find(_seat)
	_col.add_child(UI.title("Vaga de %s" % p.get("name", "?"), 32))
	_col.add_child(UI.segmented([["web", "Navegador"], ["app", "Tem o app"]], "web" if _web else "app", func(k):
		_web = k == "web"
		_build_qr()))
	var text := _web_url() if _web else DeepLink.make(room_code, _token)
	var qr := QrView.new(text, 340 if _big else 260)
	qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(qr)
	_col.add_child(UI.caption("Leia com a câmera do outro aparelho. %s O QR vale uma vez só, por 5 minutos." % (
		"Funciona em qualquer celular, até num que já está na partida." if _web else "Abre direto no app gamehub (Android).")))
	if _web:
		_col.add_child(UI.small_button("Copiar link", AppButton.Variant.SECONDARY, func():
			DisplayServer.clipboard_set(_web_url())
			App.toast("Link copiado.", Tokens.SALVIA)))
	_col.add_child(UI.button("Voltar", AppButton.Variant.SECONDARY, func():
		_seat = ""
		_token = ""
		_build_list()))
