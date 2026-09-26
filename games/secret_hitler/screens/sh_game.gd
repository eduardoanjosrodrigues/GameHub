extends Screen
## Partida de Secret Hitler (docs/PLANO_SECRET_HITLER.md §4). O mesmo arquivo serve o celular do
## jogador e o tabuleiro: a sala e os eventos são iguais; cada fase monta a visão de quem está olhando.

const MENU_PATH := "res://games/secret_hitler/screens/sh_menu.gd"
## Fases em que só o governo age: todo celular vibra e toca igual, pra não entregar quem é quem (§4.3).
const SECRET_PHASES := ["leg_president", "leg_chancellor", "veto", "power"]

var session: ShSession
var v := {}
var _scroll: ScrollContainer
var _root: VBoxContainer
var _board := false
var _conn_overlay: Control
var _leaving := false
var _qr_web := false
var _role_hidden := false
var _peek: Control
var _timer_label: Label
var _timer_ms := -1.0
var _last_phase := ""
var _history_saved := false
var _swap: SeatSwap


func _init(p_session: ShSession) -> void:
	super()
	session = p_session


func _ready() -> void:
	add_child(session)
	_board = session.local_role == "board"
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): App.toast(m, Tokens.VERMELHO))
	session.connection_changed.connect(_on_connection)
	session.ended.connect(_on_ended)
	var mesa := ShArt.art_file("mesa") if _board else null
	if mesa:
		# Fundo do tabuleiro: bem clarinho, atrás de tudo.
		var bg := TextureRect.new()
		bg.texture = mesa
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bg.modulate.a = 0.07
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
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
	if session is ShClient:
		_build_connecting()
		(session as ShClient).connect_to_host()
	else:
		_on_view(session.view, [])


func on_back() -> bool:
	if is_instance_valid(_swap):
		_swap.close()
		return true
	if _peek:
		_close_peek()
		return true
	var in_game: bool = v.get("phase", "lobby") not in ["lobby", "game_over"]
	if in_game or session.is_host:
		App.confirm("Sair da partida?", "A partida vai acabar pra todo mundo." if session.is_host else "Você sai da partida.", "Sair", _leave)
	else:
		_leave()
	return true


func _leave() -> void:
	_leaving = true
	session.leave()
	App.back_to(load(MENU_PATH))


func _on_ended(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	App.toast(reason, Tokens.VERMELHO)
	App.back_to(load(MENU_PATH))


func _on_connection(state: String) -> void:
	if _conn_overlay:
		_conn_overlay.queue_free()
		_conn_overlay = null
	if state == "reconnecting":
		_conn_overlay = _overlay("Reconectando ao host...", "Não feche o app. Se a rede voltar, você volta pro mesmo lugar.")
	elif state == "connected":
		App.toast("Reconectado!", Tokens.SALVIA)


# --- Estado ----------------------------------------------------------------

func _on_view(nv: Dictionary, events: Array) -> void:
	if nv.is_empty():
		return
	v = nv
	var phase: String = v.phase
	if phase != _last_phase:
		# Aparelho que acabou de assumir a vaga de alguém: a carta chega virada.
		_role_hidden = _last_phase == "" and session is ShClient and (session as ShClient).seat_token != ""
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
	_rebuild()
	_handle_events(events)
	_last_phase = phase


func _process(delta: float) -> void:
	if _timer_ms > 0:
		_timer_ms = maxf(0.0, _timer_ms - delta * 1000.0)
	if _timer_label and is_instance_valid(_timer_label) and _timer_ms >= 0:
		var s := int(ceil(_timer_ms / 1000.0))
		_timer_label.text = "Tempo esgotado! Presidente, indique." if s <= 0 else "Discussão: %d:%02d" % [s / 60, s % 60]


func _handle_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"player_joined":
				Audio.sfx("join")
			"player_left":
				Audio.sfx("leave")
			"player_connection":
				App.toast("%s %s" % [e.get("name", ""), "voltou" if e.get("connected") else "caiu da rede: o jogo espera"])
			"vote_result":
				Audio.sfx("hit" if e.elected else "skip")
				Haptics.hit()
			"policy":
				Audio.sfx("round" if e.policy == "L" else "buzzer")
				Haptics.hit()
			"not_hitler":
				App.toast("%s não é o Hitler." % _name(e.id), Tokens.SALVIA)
			"executed":
				Audio.sfx("buzzer")
				Haptics.time_up()
			"phase":
				if e.phase in SECRET_PHASES:
					# Igual pra todo mundo (§4.3).
					Haptics.tap()
					Audio.sfx("pop")
				elif e.phase == "nominate" and v.get("president", "") == v.get("you", "_") and not _board:
					Haptics.hg_turn()
					Audio.sfx("hg_turn")
				elif e.phase == "vote":
					Audio.sfx("pop")
			"game_over":
				Audio.sfx("win")
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 50, [ShArt.party_color(e.winner == "liberal"), Tokens.MOSTARDA, Tokens.SUPERFICIE], 2.4)


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


func _variant() -> int:
	return maxi(0, v.players.map(func(p): return p.id).find(v.you))


func _me_alive() -> bool:
	return not _board and v.get("role", "") != "" and v.get("alive", true)


func _is_president() -> bool:
	return not _board and v.get("president", "") == v.get("you", "_")


func _is_chancellor() -> bool:
	return not _board and v.get("chancellor", "") == v.get("you", "_")


func _can_continue() -> bool:
	return session.is_host or _board or _is_president()


func _fs(phone: int, board: int) -> int:
	return board if _board else phone


func _header(title_text: String) -> void:
	var row := UI.hbox(14)
	row.add_child(UI.icon_button("back", func(): on_back()))
	var t := UI.title(title_text, 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	if not _board and v.get("role", "") != "" and v.phase not in ["lobby", "reveal"]:
		row.add_child(UI.small_button("Meu papel", AppButton.Variant.SECONDARY, _open_peek, "person"))
	if _can_swap():
		row.add_child(UI.icon_button("phone", _open_swap))
	_root.add_child(row)
	var off: Array = v.players.filter(func(p): return not p.connected and p.id != session.local_id)
	if _can_swap() and not off.is_empty():
		_root.add_child(UI.small_button("%s caiu · Trocar aparelho" % ", ".join(off.map(func(p): return p.name)), AppButton.Variant.DANGER, _open_swap, "phone"))
	if not _board and v.get("role", "") != "" and not v.get("alive", true) and v.phase != "game_over":
		_root.add_child(_big("Você foi executado", Tokens.tint(Tokens.TINTA, 0.25), "Não vota, não pode ser indicado e não pode falar do seu papel."))


func _track() -> void:
	var t := ShArt.PolicyTrack.new(_board)
	t.set_view(v)
	_root.add_child(t)
	var gov := "Presidente: %s" % _name(v.president) if v.president != "" else ""
	if v.chancellor != "" and v.phase not in ["nominate"]:
		gov += "  ·  Chanceler: %s" % _name(v.chancellor)
	if gov != "":
		_root.add_child(UI.label(gov, _fs(18, 26), Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	if not v.not_hitler.is_empty():
		_root.add_child(UI.label("Não são o Hitler: %s" % _names(v.not_hitler), _fs(16, 22), ShArt.LIBERAL_ESCURO, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))


func _players_block(extra: Callable) -> Control:
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	for p in v.players:
		cv.add_child(UI.player_row(p.name, HalliArt.player_color(int(p.color)), p.connected, extra.call(p)))
	return c


func _big(text: String, color := Tokens.SUPERFICIE, sub := "") -> Control:
	var c := UI.card(color, 26)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.title(text, _fs(34, 56)))
	if sub != "":
		cv.add_child(UI.label(sub, _fs(19, 28), Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	return c


func _picture(path: String, h: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = ShArt.tex(ShArt.ART + path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(0, h)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tr


## Lista de pessoas pra escolher (indicar, investigar, executar...). allowed: ids que podem.
func _choose(ids_allowed: Array, on_pick: Callable, why_not: Callable, variant := AppButton.Variant.SECONDARY) -> void:
	var c := UI.card()
	var cv := UI.vbox(10)
	c.add_child(cv)
	for p in v.players:
		if p.id == v.you or not p.alive:
			continue
		var pid: String = p.id
		var ok: bool = pid in ids_allowed
		var label: String = p.name if ok else "%s · %s" % [p.name, why_not.call(pid)]
		var b := UI.button(label, variant, func(): on_pick.call(pid))
		b.disabled = not ok
		cv.add_child(b)
	_root.add_child(c)


func _continue_button() -> void:
	if _can_continue():
		var b := UI.button("Continuar", AppButton.Variant.PRIMARY, func(): session.send({"type": "continue"}), "play")
		b.height = 76
		_root.add_child(b)
	else:
		_root.add_child(UI.caption("Esperando %s continuar..." % _name(v.president)))


# --- Trocar aparelho (net/seat_transfer.gd) --------------------------------

func _can_swap() -> bool:
	return (session.is_host or _board) and v.get("phase", "lobby") != "lobby"


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


# --- Montagem --------------------------------------------------------------

func _rebuild() -> void:
	var keep := _scroll.scroll_vertical if v.phase == _last_phase else 0
	UI.clear(_root)
	_timer_label = null
	match v.phase:
		"lobby":
			_build_lobby()
		"reveal":
			_build_reveal()
		"nominate":
			_build_nominate()
		"vote":
			_build_vote()
		"vote_result":
			_build_vote_result()
		"leg_president", "leg_chancellor", "veto":
			_build_legislative()
		"policy":
			_build_policy()
		"power":
			_build_power()
		"power_result":
			_build_power_result()
		"game_over":
			_build_game_over()
	(func(): _scroll.scroll_vertical = keep).call_deferred()


func _build_connecting() -> void:
	UI.clear(_root)
	_root.add_child(UI.spacer(80))
	var ic := UI.texture("secret_hitler", 170)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(ic)
	_root.add_child(UI.subtitle("Conectando à sala..."))
	_root.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _leave))


# --- Sala ------------------------------------------------------------------

func _build_lobby() -> void:
	_header("Sala do Secret Hitler")
	if session.is_host:
		_root.add_child(_qr_card())
	elif v.get("room_code", "") != "":
		_root.add_child(UI.caption("Sala %s · esperando todo mundo entrar" % RoomCode.pretty(v.room_code)))
	var pc := UI.card()
	var pv := UI.vbox(10)
	pc.add_child(pv)
	pv.add_child(UI.label("Ordem da mesa (%d)" % v.players.size(), 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		pv.add_child(UI.label("Deixe na ordem em que vocês estão sentados: a presidência passa de cima pra baixo.", 16, Tokens.TINTA_SUAVE))
	var list: Array = v.players
	for i in list.size():
		var p: Dictionary = list[i]
		var extra := "desconectado" if not p.connected else ("você" if p.id == v.you else "")
		var row := UI.player_row("%d. %s" % [i + 1, p.name], HalliArt.player_color(int(p.color)), p.connected, extra)
		if session.is_host:
			var pid: String = p.id
			var up := UI.icon_button("up", func(): session.send({"type": "move_player", "id": pid, "dir": -1}))
			up.disabled = i == 0
			var dn := UI.icon_button("down", func(): session.send({"type": "move_player", "id": pid, "dir": 1}))
			dn.disabled = i == list.size() - 1
			row.add_child(up)
			row.add_child(dn)
		pv.add_child(row)
	_root.add_child(pc)
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


func _config_card() -> Control:
	var cfg: Dictionary = v.config
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var n: int = v.players.size()
	if n >= 5:
		var f: int = int(v.fascist_count)
		cv.add_child(UI.label("Com %d jogadores: %d liberais, %d fascista%s e o Hitler. %s" % [n, n - f - 1, f, "" if f == 1 else "s",
			"O Hitler sabe quem é o fascista." if n <= 6 else "O Hitler não sabe quem são os fascistas."], 16, Tokens.TINTA_SUAVE))
	if session.is_host:
		cv.add_child(UI.setting_block("Cronômetro da discussão (min)", UI.stepper(int(cfg.timer_min), 0, 5, 1, func(x): session.send({"type": "set_config", "timer_min": x})), "0 = desligado. É só um aviso pro presidente indicar o chanceler."))
	else:
		cv.add_child(UI.label("Cronômetro: %s" % ("%d min" % cfg.timer_min if int(cfg.timer_min) > 0 else "desligado"), 17, Tokens.TINTA, Fonts.body_bold()))
	return c


# --- Papel -----------------------------------------------------------------

func _role_block(hide_button := true) -> Control:
	var box := UI.vbox(14)
	var card := ShArt.RoleCard.new(v.role, _variant())
	card.face_down = _role_hidden
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 470)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_role_hidden = not _role_hidden
			_rebuild())
	box.add_child(card)
	if _role_hidden:
		return box
	var lib := ShArt.is_liberal(v.role)
	var info := UI.card(Tokens.tint(ShArt.party_color(lib), 0.4), 20)
	var iv := UI.vbox(8)
	info.add_child(iv)
	var head := "Você é LIBERAL" if lib else ("Você é o HITLER (time fascista)" if v.role == "hitler" else "Você é FASCISTA")
	iv.add_child(UI.label(head, 24, ShArt.LIBERAL_ESCURO if lib else ShArt.FASCISTA_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	iv.add_child(UI.label(ShArt.ROLES[v.role].texto, 18, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	var knows: Array = v.knows
	if v.role == "fascista":
		var others: Array = knows.filter(func(k): return k.tag == "fascista").map(func(k): return k.id)
		var hitler: Array = knows.filter(func(k): return k.tag == "hitler").map(func(k): return k.id)
		if not others.is_empty():
			iv.add_child(UI.label("Os outros fascistas: %s" % _names(others), 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		iv.add_child(UI.label("O Hitler é: %s" % _names(hitler), 22, ShArt.FASCISTA_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	elif v.role == "hitler":
		if knows.is_empty():
			iv.add_child(UI.label("Você não sabe quem são os fascistas, mas eles sabem quem você é.", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		else:
			iv.add_child(UI.label("O fascista é: %s" % _names(knows.map(func(k): return k.id)), 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	for s in v.get("investigations", []):
		iv.add_child(UI.label("Você investigou: %s é %s" % [_name(s.id), "LIBERAL" if s.party == "liberal" else "FASCISTA"], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(info)
	if hide_button:
		box.add_child(UI.small_button("Esconder a carta", AppButton.Variant.SECONDARY, func():
			_role_hidden = true
			_rebuild()))
	return box


func _build_reveal() -> void:
	_header("Seu papel")
	var total: int = v.players.size()
	var done: int = v.ready.size()
	if _board:
		_root.add_child(_big("Cada um está vendo o seu papel", Tokens.MOSTARDA, "Olhe só o seu celular! %d de %d prontos" % [done, total]))
		_root.add_child(_players_block(func(p): return "pronto ✓" if p.id in v.ready else "vendo..."))
		return
	_root.add_child(UI.caption("Não mostre pra ninguém. Toque na carta pra esconder ou mostrar."))
	_root.add_child(_role_block())
	if v.you in v.ready:
		_root.add_child(UI.caption("Esperando os outros: %d de %d prontos" % [done, total]))
	else:
		var b := UI.button("Pronto, já vi", AppButton.Variant.SUCCESS, func(): session.send({"type": "ready"}), "check")
		b.height = 80
		_root.add_child(b)


func _open_peek() -> void:
	_close_peek()
	var shade := ColorRect.new()
	shade.color = Tokens.PAPEL
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_peek = shade
	var sc := UI.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(sc)
	var mw := MaxWidth.new()
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mw)
	var m := UI.margin(24, 40, 40)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.add_child(m)
	var col := UI.vbox(14)
	m.add_child(col)
	var was := _role_hidden
	_role_hidden = false
	col.add_child(_role_block(false))
	_role_hidden = was
	col.add_child(UI.button("Fechar", AppButton.Variant.PRIMARY, _close_peek))


func _close_peek() -> void:
	if _peek:
		_peek.queue_free()
		_peek = null


# --- Eleição ---------------------------------------------------------------

func _build_nominate() -> void:
	_header("Eleição")
	_track()
	if int(v.get("timer_left_ms", -1)) >= 0:
		_timer_label = UI.label("", _fs(22, 32), ShArt.FASCISTA_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_timer_label)
	if _is_president():
		_root.add_child(_big("Você é o candidato a presidente", Tokens.MOSTARDA, "Indique quem vai ser o chanceler."))
		_choose(v.eligible, func(pid: String):
			App.confirm("Indicar %s?" % _name(pid), "%s vai ser o candidato a chanceler. Todo mundo vota o governo." % _name(pid), "Indicar", func(): session.send({"type": "nominate", "id": pid}), "Cancelar", false),
			func(pid: String) -> String:
				return "último chanceler" if pid == v.last_chancellor else "último presidente")
		return
	_root.add_child(_big("%s é o candidato a presidente" % _name(v.president), Tokens.SUPERFICIE, "Escolhendo quem vai ser o chanceler..."))
	var blocked: Array = [v.last_president, v.last_chancellor].filter(func(x): return x != "")
	if not blocked.is_empty():
		_root.add_child(UI.caption("Não podem ser chanceler agora (último governo eleito): %s" % _names(blocked)))
	_root.add_child(UI.caption("Conversem! Em quem vocês confiam?"))


func _build_vote() -> void:
	_header("Votação")
	_track()
	_root.add_child(_big("Presidente %s\nChanceler %s" % [_name(v.president), _name(v.chancellor)], Tokens.SUPERFICIE, "Vocês aprovam esse governo?"))
	if _me_alive():
		if v.my_vote == null:
			var row := UI.hbox(14)
			row.add_child(_ballot(true))
			row.add_child(_ballot(false))
			_root.add_child(row)
			_root.add_child(UI.caption("Os votos aparecem todos juntos, com o nome de cada um, quando o último votar."))
		else:
			_root.add_child(_big("Você votou: %s" % ("Ja!" if v.my_vote else "Nein"), Tokens.tint(Tokens.SALVIA if v.my_vote else Tokens.VERMELHO, 0.4)))
	_root.add_child(_players_block(func(p): return "executado" if not p.alive else ("votou ✓" if p.id in v.voted else "pensando...")))


func _ballot(ja: bool) -> Control:
	var box := UI.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := _picture("voto_ja.svg" if ja else "voto_nein.svg", 220)
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	var fire := func():
		session.send({"type": "vote", "ja": ja})
		Haptics.tap()
	tr.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			fire.call())
	box.add_child(tr)
	var b := UI.button("Ja!" if ja else "Nein", AppButton.Variant.SUCCESS if ja else AppButton.Variant.TEAM_VERMELHO)
	b.height = 84
	b.font_size = 30
	b.pressed.connect(fire)
	box.add_child(b)
	box.add_child(UI.caption("sim" if ja else "não"))
	return box


func _build_vote_result() -> void:
	_header("Resultado do voto")
	_track()
	var h: Dictionary = v.history.back() if not v.history.is_empty() else {}
	var elected: bool = h.get("elected", false)
	var yes: int = v.last_votes.values().filter(func(x): return x).size()
	var sub := "%d Ja, %d Nein" % [yes, v.last_votes.size() - yes]
	if not elected:
		sub += ". A presidência passa. Eleições fracassadas: %d de 3." % int(v.tracker)
		if int(v.tracker) >= 3:
			sub += " Caos: a lei do topo entra direto!"
	elif v.chancellor in v.not_hitler:
		sub += ". %s não é o Hitler." % _name(v.chancellor)
	_root.add_child(_big("Governo eleito!" if elected else "Governo recusado", Tokens.tint(Tokens.SALVIA if elected else Tokens.VERMELHO, 0.4), sub))
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	for p in v.players:
		if not v.last_votes.has(p.id):
			continue
		var row := UI.player_row(p.name, HalliArt.player_color(int(p.color)), true, "")
		var tok := _picture("voto_ja.svg" if v.last_votes[p.id] else "voto_nein.svg", _fs(52, 76))
		tok.size_flags_horizontal = Control.SIZE_SHRINK_END
		tok.custom_minimum_size.x = _fs(42, 62)
		row.add_child(tok)
		cv.add_child(row)
	_root.add_child(c)
	_continue_button()


# --- Sessão legislativa ----------------------------------------------------

func _build_legislative() -> void:
	_header("Sessão legislativa")
	_track()
	var hand: Array = v.hand
	match v.phase:
		"leg_president":
			if _is_president() and not hand.is_empty():
				_root.add_child(_big("Descarte uma lei", Tokens.MOSTARDA, "As outras duas vão pro chanceler. Ninguém mais vê."))
				_policy_choice(hand, func(i: int):
					App.confirm("Descartar esta lei?", "A lei %s vai pro descarte, sem ninguém ver." % ("liberal" if hand[i] == "L" else "fascista"), "Descartar", func(): session.send({"type": "discard", "index": i}), "Cancelar", false))
				return
		"leg_chancellor":
			if _is_chancellor() and not hand.is_empty():
				_root.add_child(_big("Aprove uma lei", Tokens.MOSTARDA, "A outra vai pro descarte, sem ninguém ver."))
				_policy_choice(hand, func(i: int):
					App.confirm("Aprovar esta lei?", "A lei %s vai ser aprovada. Todo mundo vê." % ("liberal" if hand[i] == "L" else "fascista"), "Aprovar", func(): session.send({"type": "enact", "index": i}), "Cancelar", false))
				if v.veto_unlocked and not v.veto_refused:
					_root.add_child(UI.button("Pedir veto das duas", AppButton.Variant.DANGER, func():
						App.confirm("Pedir veto?", "Se o presidente aceitar, as duas leis vão pro descarte e o marcador de eleições sobe.", "Pedir veto", func(): session.send({"type": "veto"})), "close"))
				elif v.veto_refused:
					_root.add_child(UI.caption("O presidente recusou o veto: aprove uma das duas."))
				return
		"veto":
			if _is_president():
				_root.add_child(_big("O chanceler pediu veto", Tokens.MOSTARDA, "Aceitar descarta as duas leis e sobe o marcador de eleições."))
				var row := UI.hbox(14)
				var yes := UI.button("Aceitar o veto", AppButton.Variant.DANGER, func(): session.send({"type": "veto_answer", "accept": true}))
				yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var no := UI.button("Recusar", AppButton.Variant.PRIMARY, func(): session.send({"type": "veto_answer", "accept": false}))
				no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(yes)
				row.add_child(no)
				_root.add_child(row)
				return
			_root.add_child(_big("O chanceler pediu veto", Tokens.SUPERFICIE, "Esperando %s responder..." % _name(v.president)))
			return
	# Quem espera: a mesma tela pra todo mundo, sem pista de quem está com as leis (§4.3).
	_root.add_child(_big("O governo está decidindo a lei", Tokens.SUPERFICIE, "Presidente %s · Chanceler %s" % [_name(v.president), _name(v.chancellor)]))
	var backs := UI.hbox(12)
	backs.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var tr := _picture("verso_lei.svg", _fs(130, 200))
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size.x = _fs(92, 140)
		backs.add_child(tr)
	_root.add_child(backs)
	_root.add_child(UI.caption("Sem conversa agora: quem está com as leis não pode falar delas até a lei sair."))


func _policy_choice(hand: Array, on_pick: Callable) -> void:
	var row := UI.hbox(12)
	for i in hand.size():
		var box := UI.vbox(6)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tr := _picture("lei_liberal.svg" if hand[i] == "L" else "lei_fascista.svg", 220)
		tr.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		tr.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				on_pick.call(idx))
		box.add_child(tr)
		box.add_child(UI.label("Liberal" if hand[i] == "L" else "Fascista", 18, ShArt.LIBERAL_ESCURO if hand[i] == "L" else ShArt.FASCISTA_ESCURO, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(box)
	_root.add_child(row)
	_root.add_child(UI.caption("Toque na lei."))


func _build_policy() -> void:
	_header("Nova lei")
	var lp: Dictionary = v.last_policy
	if lp.get("vetoed", false):
		_root.add_child(_big("Veto aceito", Tokens.tint(Tokens.TINTA, 0.2), "Nenhuma lei entrou. Eleições fracassadas: %d de 3." % int(v.tracker)))
	else:
		var lib: bool = lp.get("policy", "") == "L"
		var title := "Lei %s aprovada" % ("liberal" if lib else "fascista")
		var sub := "Caos: 3 eleições fracassadas, a lei do topo entrou direto, sem poder." if lp.get("chaos", false) else ""
		_root.add_child(_big(title, Tokens.tint(ShArt.party_color(lib), 0.4), sub))
		var tr := _picture("lei_liberal.svg" if lib else "lei_fascista.svg", _fs(240, 360))
		_root.add_child(tr)
	if v.power != "":
		_root.add_child(_big("Poder do presidente: %s" % ShArt.POWER_NAMES.get(v.power, v.power), Tokens.MOSTARDA, ShArt.POWER_INFO.get(v.power, "")))
	_track()
	_continue_button()


# --- Poderes ---------------------------------------------------------------

func _build_power() -> void:
	var pname: String = ShArt.POWER_NAMES.get(v.power, v.power)
	_header(pname)
	_track()
	if not _is_president():
		_root.add_child(_big("%s está usando o poder" % _name(v.president), Tokens.SUPERFICIE, "%s: %s" % [pname, ShArt.POWER_INFO.get(v.power, "")]))
		return
	match v.power:
		"peek":
			_root.add_child(_big("As 3 leis do topo", Tokens.MOSTARDA, "Da de cima pra de baixo. Só você vê. Conte (ou minta) o que quiser."))
			var row := UI.hbox(12)
			for c in v.peek:
				var tr := _picture("lei_liberal.svg" if c == "L" else "lei_fascista.svg", 200)
				row.add_child(tr)
			_root.add_child(row)
			var b := UI.button("Visto", AppButton.Variant.PRIMARY, func(): session.send({"type": "power"}), "check")
			b.height = 76
			_root.add_child(b)
		"investigate":
			_root.add_child(_big("Investigue alguém", Tokens.MOSTARDA, "Você vê, só no seu celular, o partido da pessoa."))
			var ok: Array = v.players.filter(func(p): return p.alive and p.id != v.you and p.id not in v.investigated).map(func(p): return p.id)
			_choose(ok, func(pid: String):
				App.confirm("Investigar %s?" % _name(pid), "Só você vai ver o partido.", "Investigar", func(): session.send({"type": "power", "id": pid}), "Cancelar", false),
				func(_pid: String) -> String: return "já investigado")
		"special_election":
			_root.add_child(_big("Eleição especial", Tokens.MOSTARDA, "Escolha quem vai ser o próximo candidato a presidente. Depois, a ordem volta ao normal."))
			var ok2: Array = v.players.filter(func(p): return p.alive and p.id != v.you).map(func(p): return p.id)
			_choose(ok2, func(pid: String):
				App.confirm("%s como próximo candidato?" % _name(pid), "", "Escolher", func(): session.send({"type": "power", "id": pid}), "Cancelar", false),
				func(_pid: String) -> String: return "")
		"execution":
			_root.add_child(_big("Execução", Tokens.tint(ShArt.FASCISTA, 0.4), "Escolha quem vai ser executado. Se for o Hitler, os liberais vencem."))
			var ok3: Array = v.players.filter(func(p): return p.alive and p.id != v.you).map(func(p): return p.id)
			_choose(ok3, func(pid: String):
				App.confirm("Executar %s?" % _name(pid), "Não dá pra voltar atrás.", "Executar", func(): session.send({"type": "power", "id": pid})),
				func(_pid: String) -> String: return "", AppButton.Variant.DANGER)


func _build_power_result() -> void:
	var pname: String = ShArt.POWER_NAMES.get(v.power, v.power)
	_header(pname)
	var who := _name(v.president)
	var target := _name(v.power_target)
	match v.power:
		"investigate":
			if _is_president():
				var seen: Array = v.investigations.filter(func(s): return s.id == v.power_target)
				var lib: bool = not seen.is_empty() and seen.back().party == "liberal"
				_root.add_child(_big("%s é %s" % [target, "LIBERAL" if lib else "FASCISTA"], Tokens.tint(ShArt.party_color(lib), 0.45), "Só você vê isso. Conte (ou minta) o que quiser."))
				_root.add_child(_picture("partido_liberal.svg" if lib else "partido_fascista.svg", 260))
			else:
				_root.add_child(_big("%s investigou %s" % [who, target], Tokens.SUPERFICIE, "Só %s viu o partido." % who))
		"peek":
			_root.add_child(_big("%s espiou o baralho" % who, Tokens.SUPERFICIE, "Viu as 3 leis do topo."))
		"special_election":
			_root.add_child(_big("Eleição especial", Tokens.SUPERFICIE, "%s escolheu %s como próximo candidato a presidente." % [who, target]))
		"execution":
			if v.power_target == v.you:
				_root.add_child(_big("Você foi executado", Tokens.tint(Tokens.TINTA, 0.25), "Não conte seu papel. Você continua vendo a partida."))
			else:
				_root.add_child(_big("%s executou %s" % [who, target], Tokens.tint(ShArt.FASCISTA, 0.35), "%s não era o Hitler. O papel não é revelado." % target))
	_track()
	_continue_button()


# --- Fim -------------------------------------------------------------------

func _build_game_over() -> void:
	var lib_won: bool = v.winner == "liberal"
	_root.add_child(UI.spacer(8))
	_root.add_child(_big("Os %s venceram!" % ("liberais" if lib_won else "fascistas"), Tokens.tint(ShArt.party_color(lib_won), 0.45), ShArt.REASONS.get(v.win_reason, "")))
	_track()
	var c := UI.card()
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Quem era quem", 22, Tokens.TINTA, Fonts.title()))
	var roles: Dictionary = v.all_roles
	for p in v.players:
		var r: String = roles.get(p.id, "")
		var extra := ShArt.role_name(r) + ("" if p.alive else " · executado")
		cv.add_child(UI.player_row(p.name, ShArt.party_color(ShArt.is_liberal(r)) if r != "hitler" else Tokens.TINTA, true, extra))
	_root.add_child(c)
	_root.add_child(_history_card())
	if session.is_host:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption("Mesma mesa, papéis novos."))
	elif not _board:
		_root.add_child(UI.caption("Se o host quiser, a próxima começa daqui."))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


## Cada governo: quem, os votos e, no fim, o que recebeu e descartou (§3.7).
func _history_card() -> Control:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("O que aconteceu", 22, Tokens.TINTA, Fonts.title()))
	var n := 0
	for h in v.history:
		if h.get("chaos", false):
			cv.add_child(UI.label("Caos: entrou uma lei %s direto do baralho." % ("liberal" if h.get("policy", "") == "L" else "fascista"), 16, Tokens.TINTA_SUAVE, Fonts.body_bold()))
			continue
		n += 1
		var votes: Dictionary = h.get("votes", {})
		var yes := votes.values().filter(func(x): return x).size()
		var line := "%d. %s e %s · %d Ja, %d Nein" % [n, _name(h.president), _name(h.chancellor), yes, votes.size() - yes]
		if not h.get("elected", false):
			line += " · recusado"
		cv.add_child(UI.label(line, 17, Tokens.TINTA, Fonts.body_bold()))
		if h.has("drawn"):
			var d := "   Presidente recebeu %s, descartou %s" % [_cards(h.drawn), _cards([h.get("discarded_p", "")])]
			if h.has("passed"):
				d += "; chanceler recebeu %s" % _cards(h.passed)
			if h.get("vetoed", false):
				d += "; vetaram"
			elif h.has("policy"):
				d += "; aprovou %s" % _cards([h.policy])
			cv.add_child(UI.label(d, 15, Tokens.TINTA_SUAVE))
	if n == 0:
		cv.add_child(UI.label("Nenhum governo.", 16, Tokens.TINTA_SUAVE))
	return c


func _cards(list: Array) -> String:
	return " ".join(list.map(func(x): return "L" if x == "L" else "F"))


func _save_history() -> void:
	var roles: Dictionary = v.get("all_roles", {})
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "secret_hitler",
		"game_name": "Secret Hitler",
		"mode": "wifi",
		"winner_side": v.winner,
		"reason": v.win_reason,
		"players": v.players.map(func(p): return {"name": p.name, "role": roles.get(p.id, "")}),
	})


func _overlay(title_text: String, body: String) -> Control:
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
	cv.add_child(UI.title(title_text, 32))
	cv.add_child(UI.label(body, 18, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.button("Sair da partida", AppButton.Variant.SECONDARY, _leave))
	return shade
