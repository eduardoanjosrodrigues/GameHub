class_name PartyGameScreen
extends Screen
## Base das telas de partida da Sintonia e do Ito (docs/PLANO_SINTONIA_ITO.md §6). O mesmo arquivo
## serve o celular do jogador, o tabuleiro e o celular só (passa-e-joga): a sala, a conexão, o QR, a
## troca de aparelho e as janelas por cima ficam aqui; cada jogo monta as suas fases.
##
## Movimento ao vivo (agulha da Sintonia): eventos em _live_events() não remontam a tela; o jogo
## atualiza só o que mudou em _live_update().

var session: PartySession
var v := {}
var _scroll: ScrollContainer
var _root: VBoxContainer
var _board := false
var _local := false
var _conn_overlay: Control
var _leaving := false
var _qr_web := false
var _timer_label: Label
var _timer_ms := -1.0
var _last_phase := ""
var _history_saved := false
var _swap: SeatSwap
var _panel: Control # janela por cima (palavra-chave, tema digitado, ver o número...)
var _add_edit: LineEdit


func _init(p_session: PartySession) -> void:
	super()
	session = p_session


# --- O que cada jogo define ------------------------------------------------

func _menu_path() -> String:
	return ""


func _game_title() -> String:
	return ""


func _icon() -> String:
	return ""


func _lobby_title() -> String:
	return "Sala"


## Fases depois da sala.
func _build_phase() -> void:
	pass


## Cartão da configuração da partida na sala.
func _config_card() -> Control:
	return UI.spacer()


func _live_events() -> Array:
	return []


## Atualiza só o que o movimento ao vivo mudou. false = remonta a tela.
func _live_update(_events: Array) -> bool:
	return false


func _game_events(_events: Array) -> void:
	pass


## Antes de remontar a tela (ex: zerar o estado local numa partida nova).
func _before_rebuild(_events: Array) -> void:
	pass


func _timer_text(s: int) -> String:
	return "Tempo esgotado!" if s <= 0 else "%d:%02d" % [s / 60, s % 60]


func _save_history() -> void:
	pass


# --- Ciclo -----------------------------------------------------------------

func _ready() -> void:
	add_child(session)
	_board = session.local_role == "board"
	_local = session.is_local()
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): App.toast(m, Tokens.VERMELHO))
	session.connection_changed.connect(_on_connection)
	session.ended.connect(_on_ended)
	var mw := MaxWidth.new(1100.0 if _board else Tokens.CONTENT_MAX_WIDTH)
	mw.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mw)
	_scroll = UI.scroll()
	mw.add_child(_scroll)
	var m := UI.margin(20, 20, 32)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(m)
	_root = UI.vbox(18)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(_root)
	if session is PartyClient:
		_build_connecting()
		(session as PartyClient).connect_to_host()
	else:
		_on_view(session.view, [])


func on_back() -> bool:
	if is_instance_valid(_swap):
		_swap.close()
		return true
	if _panel:
		_close_panel()
		return true
	var in_game: bool = v.get("phase", "lobby") not in ["lobby", "game_over"]
	if in_game or (session.is_host and not _local):
		App.confirm("Sair da partida?", "A partida vai acabar pra todo mundo." if session.is_host and not _local else "A partida acaba.", "Sair", _leave)
	else:
		_leave()
	return true


func _leave() -> void:
	_leaving = true
	session.leave()
	App.back_to(load(_menu_path()))


func _on_ended(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	App.toast(reason, Tokens.VERMELHO)
	App.back_to(load(_menu_path()))


func _on_connection(state: String) -> void:
	if _conn_overlay:
		_conn_overlay.queue_free()
		_conn_overlay = null
	if state == "reconnecting":
		_conn_overlay = _connection_overlay()
	elif state == "connected":
		App.toast("Reconectado!", Tokens.SALVIA)


func _on_view(nv: Dictionary, events: Array) -> void:
	if nv.is_empty():
		return
	var prev := v
	v = nv
	var phase: String = v.phase
	if phase != _last_phase:
		music = "menu" if phase in ["lobby", "game_over"] else ""
		Audio.music(music)
		if phase == "game_over" and not _history_saved:
			_history_saved = true
			_save_history()
		if phase != "game_over":
			_history_saved = false
	_timer_ms = float(v.get("timer_left_ms", -1))
	if is_instance_valid(_swap):
		_swap.set_players(_swap_players())
	_before_rebuild(events)
	var live: Array = _live_events()
	var only_live := not events.is_empty() and phase == _last_phase and events.all(func(e): return e.get("type", "") in live)
	if not (only_live and not prev.is_empty() and _live_update(events)):
		_rebuild()
	_base_events(events)
	_game_events(events)
	_last_phase = phase


func _process(delta: float) -> void:
	if _timer_ms > 0:
		_timer_ms = maxf(0.0, _timer_ms - delta * 1000.0)
	if _timer_label and is_instance_valid(_timer_label) and _timer_ms >= 0:
		_timer_label.text = _timer_text(int(ceil(_timer_ms / 1000.0)))


func _base_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"player_joined":
				Audio.sfx("join")
			"player_left":
				Audio.sfx("leave")
			"player_connection":
				App.toast("%s %s" % [e.get("name", ""), "voltou" if e.get("connected") else "caiu da rede"])


func _rebuild() -> void:
	var keep := _scroll.scroll_vertical if v.phase == _last_phase else 0
	UI.clear(_root)
	_timer_label = null
	if v.phase == "lobby":
		_build_lobby()
	else:
		_build_phase()
	(func(): _scroll.scroll_vertical = keep).call_deferred()


# --- Utilidades ------------------------------------------------------------

func _name(id: String) -> String:
	for p in v.get("players", []):
		if p.id == id:
			return p.name
	return "?"


func _player(id: String) -> Dictionary:
	for p in v.get("players", []):
		if p.id == id:
			return p
	return {}


func _names(ids: Array) -> String:
	return ", ".join(ids.map(func(i): return _name(i)))


func _color(id: String) -> Color:
	var p := _player(id)
	return HalliArt.player_color(int(p.get("color", 0)))


func _fs(phone: int, board: int) -> int:
	return board if _board else phone


func _me() -> String:
	return str(v.get("you", ""))


func _header(title_text: String) -> HBoxContainer:
	var row := UI.hbox(14)
	row.add_child(UI.icon_button("back", func(): on_back()))
	var t := UI.title(title_text, 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	if _can_swap():
		row.add_child(UI.icon_button("phone", _open_swap))
	_root.add_child(row)
	var off: Array = v.players.filter(func(p): return not p.connected and p.id != session.local_id)
	if _can_swap() and not off.is_empty():
		_root.add_child(UI.small_button("%s caiu · Trocar aparelho" % ", ".join(off.map(func(p): return p.name)), AppButton.Variant.DANGER, _open_swap, "phone"))
	return row


func _big(text: String, color := Tokens.SUPERFICIE, sub := "") -> Control:
	var c := UI.card(color, 26)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.title(text, _fs(32, 52)))
	if sub != "":
		cv.add_child(UI.label(sub, _fs(19, 28), Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	return c


func _timer_row() -> void:
	if int(v.get("timer_left_ms", -1)) >= 0:
		_timer_label = UI.label("", _fs(22, 32), Tokens.VERMELHO_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_timer_label)


func _players_list(extra: Callable) -> Control:
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	for p in v.players:
		cv.add_child(UI.player_row(p.name, HalliArt.player_color(int(p.color)), p.connected, extra.call(p)))
	return c


## Botões de fim: jogar de novo, voltar pra sala e sair.
func _end_buttons(again_hint: String) -> void:
	if _local:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption(again_hint))
		_root.add_child(UI.small_button("Mudar quem joga", AppButton.Variant.SECONDARY, func(): session.send({"type": "to_lobby"}), "people"))
		_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))
		return
	if session.is_host:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption(again_hint))
		_root.add_child(UI.small_button("Voltar pra sala", AppButton.Variant.SECONDARY, func(): session.send({"type": "to_lobby"}), "people"))
	elif not _board:
		_root.add_child(UI.caption("Se o host quiser, a próxima começa daqui."))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


# --- Sala ------------------------------------------------------------------

func _build_connecting() -> void:
	UI.clear(_root)
	_root.add_child(UI.spacer(80))
	var ic := UI.texture(_icon(), 170)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(ic)
	_root.add_child(UI.subtitle("Conectando à sala..."))
	_root.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _leave))


func _build_lobby() -> void:
	_header("%s · um celular" % _game_title() if _local else _lobby_title())
	if _local:
		_root.add_child(_add_player_card())
	elif session.is_host:
		_root.add_child(_qr_card())
	elif v.get("room_code", "") != "":
		_root.add_child(UI.caption("Sala %s · esperando todo mundo entrar" % RoomCode.pretty(v.room_code)))
	_root.add_child(_players_card())
	_root.add_child(_config_card())
	if session.is_host:
		var why: String = v.can_start
		var b := UI.button("Começar partida", AppButton.Variant.SUCCESS, func(): session.send({"type": "start"}), "play")
		b.height = 84
		b.font_size = 26
		b.disabled = why != ""
		_root.add_child(b)
		if why != "":
			_root.add_child(UI.caption(why))
	else:
		_root.add_child(UI.caption("Esperando o host começar a partida..."))


## Lista de quem está na sala; o host arruma a ordem da mesa. Cada jogo pode trocar (times).
func _players_card() -> Control:
	var pc := UI.card()
	var pv := UI.vbox(10)
	pc.add_child(pv)
	pv.add_child(UI.label("Na mesa (%d)" % v.players.size(), 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		pv.add_child(UI.label("Deixe na ordem em que vocês estão sentados.", 16, Tokens.TINTA_SUAVE))
	var list: Array = v.players
	for i in list.size():
		var p: Dictionary = list[i]
		var extra := "desconectado" if not p.connected else ("você" if p.id == _me() else "")
		var row := UI.player_row("%d. %s" % [i + 1, p.name], HalliArt.player_color(int(p.color)), p.connected, extra)
		if session.is_host:
			_order_buttons(row, p.id, i, list.size())
		pv.add_child(row)
	if list.is_empty():
		pv.add_child(UI.caption("Ninguém ainda."))
	return pc


func _order_buttons(row: Control, pid: String, i: int, n: int) -> void:
	var up := UI.icon_button("up", func(): session.send({"type": "move_player", "id": pid, "dir": -1}))
	up.disabled = i == 0
	var dn := UI.icon_button("down", func(): session.send({"type": "move_player", "id": pid, "dir": 1}))
	dn.disabled = i == n - 1
	row.add_child(up)
	row.add_child(dn)
	if _local:
		row.add_child(UI.icon_button("trash", func(): session.send({"type": "remove_player", "id": pid})))


## Celular só: digitar os nomes de quem vai jogar.
func _add_player_card() -> Control:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(12)
	c.add_child(cv)
	cv.add_child(UI.label("Quem vai jogar?", 22, Tokens.TINTA, Fonts.title()))
	cv.add_child(UI.label("Um celular só: ele passa de mão em mão só na hora do segredo e depois fica no meio da mesa.", 16, Tokens.TINTA_SUAVE))
	var row := UI.hbox(10)
	_add_edit = UI.line_edit("Nome", "", 20)
	_add_edit.text_submitted.connect(func(_t): _add_local_player())
	row.add_child(_add_edit)
	var b := UI.icon_button("plus", _add_local_player, AppButton.Variant.SUCCESS)
	row.add_child(b)
	cv.add_child(row)
	return c


func _add_local_player() -> void:
	var n := TextNorm.clean(_add_edit.text)
	if n == "":
		App.toast("Digite o nome", Tokens.VERMELHO)
		return
	session.send({"type": "add_player", "name": n})
	(func():
		if is_instance_valid(_add_edit) and _add_edit.is_inside_tree():
			_add_edit.grab_focus()).call_deferred()


func _qr_card() -> Control:
	var code: String = v.get("room_code", "")
	var rc := UI.card(Tokens.SUPERFICIE, 24)
	var rv := UI.vbox(12)
	rc.add_child(rv)
	rv.add_child(UI.label("Chame a galera!", 26, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	var web_url := Net.web_url()
	if web_url != "":
		rv.add_child(UI.segmented([["app", "Tem o app"], ["web", "Navegador (iPhone)"]], "web" if _qr_web else "app", func(k):
			_qr_web = k == "web"
			_rebuild()))
	var qsize := 320 if _board else 240
	if _qr_web and web_url != "":
		var wqr := QrView.new(web_url, qsize)
		wqr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rv.add_child(wqr)
		rv.add_child(UI.label("Aponte a câmera pro QR: o jogo abre no navegador. Ou digite no navegador:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
		rv.add_child(UI.label(web_url.trim_prefix("http://").trim_suffix("/"), 40, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		rv.add_child(UI.small_button("Copiar endereço", AppButton.Variant.SECONDARY, func():
			DisplayServer.clipboard_set(web_url)
			App.toast("Endereço copiado. Mande pra quem vai jogar.", Tokens.SALVIA)))
		rv.add_child(UI.label("Uma TV ou notebook também pode abrir o endereço e entrar como tabuleiro.", 15, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	elif code != "":
		var qr := QrView.new(DeepLink.make(code), qsize)
		qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rv.add_child(qr)
		rv.add_child(UI.label("Aponte a câmera pro QR ou, no app, toque em Entrar numa sala:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
		rv.add_child(UI.label(RoomCode.pretty(code), 56, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		rv.add_child(UI.label("IP: %s" % v.get("host_ip", ""), 15, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	return rc


func _timer_setting(cfg: Dictionary, hint: String) -> Control:
	if session.is_host:
		return UI.setting_block("Cronômetro (min)", UI.stepper(int(cfg.timer_min), 0, 5, 1, func(x): session.send({"type": "set_config", "timer_min": x})), hint)
	return UI.label("Cronômetro: %s" % ("%d min" % cfg.timer_min if int(cfg.timer_min) > 0 else "desligado"), 17, Tokens.TINTA, Fonts.body_bold())


# --- Trocar aparelho (net/seat_transfer.gd) --------------------------------

func _can_swap() -> bool:
	return not _local and (session.is_host or _board) and v.get("phase", "lobby") != "lobby"


func _swap_players() -> Array:
	var out: Array = []
	for p in v.get("players", []):
		if p.id != session.local_id:
			out.append({"id": p.id, "name": p.name, "connected": p.connected, "color": HalliArt.player_color(int(p.color))})
	return out


func _open_swap() -> void:
	if is_instance_valid(_swap):
		return
	_swap = SeatSwap.open(self, session, _swap_players(), str(v.get("host_ip", "")), str(v.get("room_code", "")), _board)


# --- Janelas por cima ------------------------------------------------------

## Abre uma janela opaca por cima da partida e devolve a coluna pra montar o conteúdo.
## Ela não some quando a partida remonta (ex: alguém mexeu na fila enquanto você escrevia).
func _open_panel() -> VBoxContainer:
	_close_panel()
	var shade := ColorRect.new()
	shade.color = Tokens.PAPEL
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = shade
	var sc := UI.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(sc)
	var mw := MaxWidth.new()
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mw)
	var m := UI.margin(24, 40, 40)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.add_child(m)
	var col := UI.vbox(16)
	m.add_child(col)
	return col


func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null


## Pede um ou mais textos (palavra-chave, tema digitado). on_ok recebe a lista de textos.
func _prompt(title_text: String, hint: String, fields: Array, on_ok: Callable, max_len := 40) -> void:
	var col := _open_panel()
	col.add_child(UI.title(title_text, 32))
	if hint != "":
		col.add_child(UI.caption(hint))
	var edits: Array = []
	for f in fields:
		var e := UI.line_edit(f[0], f[1], max_len)
		col.add_child(e)
		edits.append(e)
	var submit := func():
		var vals: Array = edits.map(func(e): return TextNorm.clean(e.text))
		_close_panel()
		on_ok.call(vals)
	for e in edits:
		e.text_submitted.connect(func(_t): submit.call())
	col.add_child(UI.button("Salvar", AppButton.Variant.SUCCESS, submit, "check"))
	col.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _close_panel))
	(func():
		if not edits.is_empty() and is_instance_valid(edits[0]) and edits[0].is_inside_tree():
			edits[0].grab_focus()).call_deferred()


## Celular só: "Passe o celular para Fulano" antes de mostrar um segredo.
func _gate(who: String, what: String, on_open: Callable) -> void:
	_root.add_child(UI.spacer(30))
	var c := UI.card(Tokens.MOSTARDA, 28)
	var cv := UI.vbox(12)
	c.add_child(cv)
	cv.add_child(UI.label("Passe o celular para", 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.title(who, 52))
	cv.add_child(UI.label(what, 18, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	var b := UI.button("Sou %s, pode mostrar" % who, AppButton.Variant.PRIMARY, on_open, "person")
	b.height = 84
	_root.add_child(b)
	_root.add_child(UI.caption("Os outros não olham!"))


func _connection_overlay() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(Tokens.TINTA, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var c := UI.card(Tokens.SUPERFICIE, 28)
	c.custom_minimum_size.x = min(520.0, size.x - 48.0)
	center.add_child(c)
	var cv := UI.vbox(16)
	c.add_child(cv)
	cv.add_child(UI.title("Reconectando ao host...", 32))
	cv.add_child(UI.label("Não feche o app. Se a rede voltar, você volta pro mesmo lugar.", 18, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.button("Sair da partida", AppButton.Variant.SECONDARY, _leave))
	return shade
