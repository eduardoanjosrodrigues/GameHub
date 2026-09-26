extends Screen
## Partida de Avalon (docs/PLANO_AVALON.md §4). O mesmo arquivo serve o celular do jogador e o
## tabuleiro: a sala e os eventos são iguais; cada fase monta a visão de quem está olhando.

const MENU_PATH := "res://games/avalon/screens/avalon_menu.gd"

var session: AvalonSession
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


func _init(p_session: AvalonSession) -> void:
	super()
	session = p_session


func _ready() -> void:
	add_child(session)
	_board = session.local_role == "board"
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): App.toast(m, Tokens.VERMELHO))
	session.connection_changed.connect(_on_connection)
	session.ended.connect(_on_ended)
	var mesa := AvalonArt.art_file("mesa") if _board else null
	if mesa:
		# Fundo do tabuleiro: a mesa redonda bem clarinha, atrás de tudo.
		var bg := TextureRect.new()
		bg.texture = mesa
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bg.modulate.a = 0.12
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
	if session is AvalonClient:
		_build_connecting()
		(session as AvalonClient).connect_to_host()
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
		# Aparelho que acabou de assumir a vaga de alguém: a carta chega virada (quem emprestou não vê).
		_role_hidden = _last_phase == "" and session is AvalonClient and (session as AvalonClient).seat_token != ""
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
		_timer_label.text = "Tempo esgotado! Líder, feche o time." if s <= 0 else "Discussão: %d:%02d" % [s / 60, s % 60]


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
				Audio.sfx("hit" if e.approved else "skip")
				Haptics.hit()
			"quest_result":
				Audio.sfx("round" if e.ok else "buzzer")
				if e.ok:
					Haptics.hit()
				else:
					Haptics.time_up()
			"phase":
				if e.phase == "team" and v.get("leader", "") == v.get("you", "_") and not _board:
					Haptics.hg_turn()
					Audio.sfx("hg_turn")
				elif e.phase in ["vote", "quest"]:
					Audio.sfx("pop")
			"game_over":
				Audio.sfx("win")
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 50, [AvalonArt.side_color(e.winner == "bem"), Tokens.MOSTARDA, Tokens.SUPERFICIE], 2.4)


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


func _me() -> Dictionary:
	return _player(v.get("you", ""))


func _variant() -> int:
	return maxi(0, v.players.map(func(p): return p.id).find(v.you))


func _is_leader() -> bool:
	return not _board and v.get("leader", "") == v.get("you", "_")


func _can_continue() -> bool:
	return session.is_host or _board or _is_leader()


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
		var warn := UI.small_button("%s caiu · Trocar aparelho" % ", ".join(off.map(func(p): return p.name)), AppButton.Variant.DANGER, _open_swap, "phone")
		_root.add_child(warn)


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


func _track() -> void:
	var t := AvalonArt.QuestTrack.new(_board)
	t.set_view(v)
	_root.add_child(t)
	var info := UI.label("Líder: %s  ·  Missão %d  ·  %d do mal na mesa" % [_name(v.leader), int(v.quest) + 1, int(v.evil_count)], 18 if not _board else 26, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(info)
	if v.get("lady_on", false) and v.lady != "":
		_root.add_child(UI.label("Dama do Lago: %s" % _name(v.lady), 16 if not _board else 22, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))


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
	cv.add_child(UI.title(text, 38 if not _board else 60))
	if sub != "":
		cv.add_child(UI.label(sub, 19 if not _board else 28, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	return c


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
		"team":
			_build_team()
		"vote":
			_build_vote()
		"vote_result":
			_build_vote_result()
		"quest":
			_build_quest()
		"quest_result":
			_build_quest_result()
		"lady":
			_build_lady()
		"assassin":
			_build_assassin()
		"game_over":
			_build_game_over()
	(func(): _scroll.scroll_vertical = keep).call_deferred()


func _build_connecting() -> void:
	UI.clear(_root)
	_root.add_child(UI.spacer(80))
	var ic := UI.texture("avalon", 170)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(ic)
	_root.add_child(UI.subtitle("Conectando à sala..."))
	_root.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _leave))


# --- Sala ------------------------------------------------------------------

func _build_lobby() -> void:
	_header("Sala do Avalon")
	if session.is_host:
		_root.add_child(_qr_card())
	elif v.get("room_code", "") != "":
		_root.add_child(UI.caption("Sala %s · esperando todo mundo entrar" % RoomCode.pretty(v.room_code)))

	var pc := UI.card()
	var pv := UI.vbox(10)
	pc.add_child(pv)
	pv.add_child(UI.label("Ordem da mesa (%d)" % v.players.size(), 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		pv.add_child(UI.label("Deixe na ordem em que vocês estão sentados: a liderança passa de cima pra baixo.", 16, Tokens.TINTA_SUAVE))
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
	var edit := session.is_host
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	var n: int = v.players.size()
	var evil: int = int(v.evil_count)
	cv.add_child(UI.label("Personagens", 22, Tokens.TINTA, Fonts.title()))
	if n >= 5:
		cv.add_child(UI.label("Com %d jogadores: %d do bem e %d do mal. As vagas que sobram viram servos leais e lacaios." % [n, n - evil, evil], 16, Tokens.TINTA_SUAVE))
	for r in AvalonRules.SPECIALS:
		var on: bool = r in cfg.roles
		var row := UI.hbox(12)
		var em := TextureRect.new()
		em.texture = AvalonArt.emblem(r)
		em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		em.custom_minimum_size = Vector2(40, 40)
		em.modulate = AvalonArt.side_color(AvalonArt.is_good(r)) if on else Tokens.TEXTO_DESABILITADO
		row.add_child(em)
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(AvalonArt.role_name(r), 19, Tokens.TINTA if on else Tokens.TINTA_SUAVE, Fonts.body_bold()))
		tv.add_child(UI.label(AvalonArt.SPECIAL_INFO[r], 15, Tokens.TINTA_SUAVE))
		row.add_child(tv)
		if edit:
			var rr: String = r
			row.add_child(UI.toggle(on, func(_x): session.send({"type": "set_config", "toggle": rr})))
		else:
			row.add_child(UI.label("sim" if on else "não", 17, Tokens.TINTA, Fonts.body_bold()))
		cv.add_child(row)
	var lady_hint := "Com 7 ou mais: depois das missões 2, 3 e 4, quem tem a Dama vê o lado de alguém."
	if edit:
		cv.add_child(UI.setting_block("Dama do Lago", UI.toggle(cfg.lady, func(on): session.send({"type": "set_config", "lady": on})), lady_hint))
		cv.add_child(UI.setting_block("Cronômetro da discussão (min)", UI.stepper(int(cfg.timer_min), 0, 5, 1, func(x): session.send({"type": "set_config", "timer_min": x})), "0 = desligado. É só um aviso pro líder fechar o time."))
	else:
		cv.add_child(UI.label("Dama do Lago: %s · Cronômetro: %s" % ["sim" if cfg.lady else "não", "%d min" % cfg.timer_min if int(cfg.timer_min) > 0 else "desligado"], 17, Tokens.TINTA, Fonts.body_bold()))
	return c


# --- Papel -----------------------------------------------------------------

func _role_block(hide_button := true) -> Control:
	var box := UI.vbox(14)
	var card := AvalonArt.RoleCard.new(v.role, _variant())
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
	var good := AvalonArt.is_good(v.role)
	var info := UI.card(Tokens.tint(AvalonArt.side_color(good), 0.4), 20)
	var iv := UI.vbox(8)
	info.add_child(iv)
	iv.add_child(UI.label("Você é do %s" % ("BEM" if good else "MAL"), 24, AvalonArt.BEM_ESCURO if good else AvalonArt.MAL_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	iv.add_child(UI.label(AvalonArt.ROLES[v.role].texto, 18, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	var knows: Array = v.knows
	if not knows.is_empty():
		var ids: Array = knows.map(func(k): return k.id)
		var text := ""
		match v.role:
			"merlin":
				text = "Estes são do mal: %s" % _names(ids)
			"percival":
				text = "Um destes é Merlin e o outro é Morgana: %s" % _names(ids)
			_:
				text = "Seus parceiros do mal: %s" % _names(ids)
		iv.add_child(UI.label(text, 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	elif v.role == "oberon":
		iv.add_child(UI.label("Você não sabe quem são os outros do mal.", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	for s in v.get("lady_seen", []):
		iv.add_child(UI.label("Dama do Lago: %s é do %s" % [_name(s.id), "mal" if s.evil else "bem"], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
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
	shade.color = Color(Tokens.TINTA, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_peek = shade
	var sc := UI.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(sc)
	var m := UI.margin(24, 40, 40)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(m)
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


# --- Time e votos ----------------------------------------------------------

func _build_team() -> void:
	_header("Montar o time")
	_track()
	var need: int = v.quest_sizes[int(v.quest)]
	if int(v.get("timer_left_ms", -1)) >= 0:
		_timer_label = UI.label("", 22 if not _board else 32, AvalonArt.MAL_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_timer_label)
	if _is_leader():
		_root.add_child(_big("Você é o líder!", Tokens.MOSTARDA, "Escolha %d pessoas pra missão %d (pode ser você)." % [need, int(v.quest) + 1]))
		var c := UI.card()
		var cv := UI.vbox(10)
		c.add_child(cv)
		for p in v.players:
			var on: bool = p.id in v.team
			var pid: String = p.id
			var b := UI.button(p.name + (" (você)" if p.id == v.you else ""), AppButton.Variant.PRIMARY if on else AppButton.Variant.SECONDARY, func():
				var t: Array = v.team.duplicate()
				if pid in t:
					t.erase(pid)
				elif t.size() < need:
					t.append(pid)
				else:
					App.toast("A missão leva %d pessoas. Desmarque alguém." % need)
					return
				session.send({"type": "select_team", "ids": t}), "check" if on else "")
			b.selected = on
			cv.add_child(b)
		_root.add_child(c)
		var send := UI.button("Enviar pra votação (%d/%d)" % [v.team.size(), need], AppButton.Variant.SUCCESS, func(): session.send({"type": "propose"}), "play")
		send.height = 80
		send.disabled = v.team.size() != need
		_root.add_child(send)
		return
	_root.add_child(_big("%s está montando o time" % _name(v.leader), Tokens.SUPERFICIE, "Missão %d · %d pessoas" % [int(v.quest) + 1, need]))
	_root.add_child(_team_card("Escolhidos até agora", v.team, need))
	_root.add_child(UI.caption("Conversem! Quem vocês confiam pra essa missão?"))


func _team_card(title_text: String, ids: Array, need := 0) -> Control:
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label(title_text + (" (%d/%d)" % [ids.size(), need] if need > 0 else ""), 20 if not _board else 30, Tokens.TINTA, Fonts.title()))
	if ids.is_empty():
		cv.add_child(UI.label("Ninguém ainda", 17, Tokens.TINTA_SUAVE))
	for id in ids:
		var p := _player(id)
		cv.add_child(UI.player_row(p.get("name", "?"), HalliArt.player_color(int(p.get("color", 0))), p.get("connected", true)))
	return c


func _build_vote() -> void:
	_header("Votação")
	_track()
	_root.add_child(_team_card("Time proposto por %s" % _name(v.leader), v.team))
	if not _board and v.get("role", "") != "":
		if v.my_vote == null:
			_root.add_child(UI.subtitle("Você aprova esse time?"))
			var row := UI.hbox(14)
			row.add_child(_vote_button(true))
			row.add_child(_vote_button(false))
			_root.add_child(row)
			_root.add_child(UI.caption("Os votos aparecem todos juntos quando o último votar."))
		else:
			_root.add_child(_big("Você votou: %s" % ("Aprovar" if v.my_vote else "Rejeitar"), Tokens.tint(AvalonArt.BEM if v.my_vote else AvalonArt.MAL, 0.5)))
	_root.add_child(_players_block(func(p): return "votou ✓" if p.id in v.voted else "pensando..."))


func _vote_button(approve: bool) -> Control:
	var b := UI.button("Aprovar" if approve else "Rejeitar", AppButton.Variant.TEAM_AZUL if approve else AppButton.Variant.TEAM_VERMELHO, func(): session.send({"type": "vote", "approve": approve}), "check" if approve else "close")
	b.height = 110
	b.font_size = 28
	return b


func _build_vote_result() -> void:
	_header("Resultado do voto")
	_track()
	var h: Dictionary = v.history.back() if not v.history.is_empty() else {}
	var approved: bool = h.get("approved", false)
	var yes: int = v.last_votes.values().filter(func(x): return x).size()
	var sub := "%d aprovaram, %d rejeitaram" % [yes, v.last_votes.size() - yes]
	if not approved and int(v.rejects) >= 5:
		sub += ". Quinta recusa: o mal vence!"
	elif not approved:
		sub += ". A liderança passa. Recusas: %d de 5." % int(v.rejects)
	_root.add_child(_big("Time aprovado!" if approved else "Time rejeitado", Tokens.tint(AvalonArt.BEM if approved else AvalonArt.MAL, 0.45), sub))
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	for p in v.players:
		var row := UI.player_row(p.name, HalliArt.player_color(int(p.color)), true, "")
		var yes_vote: bool = v.last_votes.get(p.id, false)
		var tok := TextureRect.new()
		tok.texture = AvalonArt.tex(AvalonArt.ART + ("voto_aprovar.svg" if yes_vote else "voto_rejeitar.svg"))
		tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tok.custom_minimum_size = Vector2(48, 48) if not _board else Vector2(72, 72)
		row.add_child(tok)
		if p.id in h.get("team", []):
			var tl := UI.label("no time", 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
			tl.autowrap_mode = TextServer.AUTOWRAP_OFF
			tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(tl)
		cv.add_child(row)
	_root.add_child(c)
	_continue_button()


func _continue_button() -> void:
	if _can_continue():
		var b := UI.button("Continuar", AppButton.Variant.PRIMARY, func(): session.send({"type": "continue"}), "play")
		b.height = 76
		_root.add_child(b)
	else:
		_root.add_child(UI.caption("Esperando %s continuar..." % _name(v.leader)))


# --- Missão ----------------------------------------------------------------

func _build_quest() -> void:
	_header("Missão %d" % (int(v.quest) + 1))
	_track()
	var in_team: bool = v.get("you", "") in v.team and not _board
	if in_team and v.my_card == null:
		_root.add_child(_big("Você está na missão", Tokens.MOSTARDA, "Escolha sua carta em segredo."))
		var good: bool = not v.evil
		var row := UI.hbox(16)
		row.add_child(_quest_card_button(true, true))
		row.add_child(_quest_card_button(false, not good))
		_root.add_child(row)
		if good:
			_root.add_child(UI.caption("Servos leais de Arthur só jogam Sucesso."))
		elif int(v.quest) == 3 and v.two_fails:
			_root.add_child(UI.caption("Nesta missão são precisas 2 Falhas pra derrubar."))
		return
	if in_team:
		_root.add_child(_big("Carta jogada: %s" % ("Sucesso" if v.my_card else "Falha"), Tokens.tint(AvalonArt.BEM if v.my_card else AvalonArt.MAL, 0.45), "Esperando o resto do time..."))
	else:
		_root.add_child(_big("O time está na missão", Tokens.SUPERFICIE, _names(v.team)))
	_root.add_child(_players_block(func(p): return ("jogou ✓" if p.id in v.played else "escolhendo...") if p.id in v.team else ""))


func _quest_card_button(success: bool, enabled: bool) -> Control:
	var box := UI.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := TextureRect.new()
	tr.texture = AvalonArt.tex(AvalonArt.ART + ("missao_sucesso.svg" if success else "missao_falha.svg"))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(0, 280)
	tr.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.3)
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	var fire := func():
		if not enabled:
			Haptics.skip()
			App.confirm("Contra as regras", "Os servos leais de Arthur só podem jogar Sucesso. Só quem é do mal pode jogar Falha.", "Entendi", func(): pass, "Fechar", false)
			return
		session.send({"type": "quest_card", "success": success})
		Haptics.tap()
	tr.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			fire.call())
	box.add_child(tr)
	var b := UI.button("Sucesso" if success else "Falha", AppButton.Variant.TEAM_AZUL if success else AppButton.Variant.TEAM_VERMELHO)
	b.pressed.connect(fire)
	if not enabled:
		b.modulate = Color(1, 1, 1, 0.45)
	box.add_child(b)
	return box


func _build_quest_result() -> void:
	var lq: Dictionary = v.last_quest
	_header("Missão %d" % (int(lq.get("quest", 0)) + 1))
	_track()
	var ok: bool = lq.get("ok", true)
	var fails := int(lq.get("fails", 0))
	var sub := "Nenhuma falha" if fails == 0 else ("%d falha%s" % [fails, "" if fails == 1 else "s"])
	if ok and fails > 0:
		sub += " (eram precisas 2)"
	_root.add_child(_big("Missão cumprida!" if ok else "A missão falhou!", Tokens.tint(AvalonArt.BEM if ok else AvalonArt.MAL, 0.45), sub))
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	var cards: Array = lq.get("cards", [])
	for i in cards.size():
		var tr := TextureRect.new()
		tr.texture = AvalonArt.tex(AvalonArt.ART + ("missao_sucesso.svg" if cards[i] else "missao_falha.svg"))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(110, 156) if not _board else Vector2(170, 240)
		tr.modulate.a = 0.0
		flow.add_child(tr)
		# As cartas viram uma a uma.
		var tw := tr.create_tween()
		tw.tween_interval(0.35 * i + 0.2)
		tw.tween_property(tr, "modulate:a", 1.0, 0.25)
	_root.add_child(flow)
	_continue_button()


# --- Dama e assassinato ----------------------------------------------------

func _build_lady() -> void:
	_header("Dama do Lago")
	_track()
	var holder: String = v.lady
	var target: String = v.get("lady_target", "")
	var me_holder: bool = not _board and holder == v.get("you", "_")
	var dama := AvalonArt.art_file("roles/dama_do_lago")
	if dama:
		_root.add_child(AvalonArt.Picture.new(dama, Vector2(240, 360) if _board else Vector2(160, 240), Color("#1E7F86")))
	if target == "":
		if me_holder:
			_root.add_child(_big("A Dama do Lago está com você", Tokens.tint(Color("#1E7F86"), 0.4), "Escolha alguém pra ver, só no seu celular, se é do bem ou do mal."))
			for p in v.players:
				if p.id == holder or p.id in v.lady_used:
					continue
				var pid: String = p.id
				_root.add_child(UI.button(p.name, AppButton.Variant.SECONDARY, func(): session.send({"type": "lady_examine", "id": pid})))
			_root.add_child(UI.caption("Quem já teve a Dama não pode ser examinado."))
		else:
			_root.add_child(_big("%s está com a Dama do Lago" % _name(holder), Tokens.tint(Color("#1E7F86"), 0.4), "Escolhendo quem examinar..."))
		return
	if me_holder:
		var seen: Array = v.lady_seen.filter(func(s): return s.id == target)
		var evil: bool = not seen.is_empty() and seen.back().evil
		_root.add_child(_big("%s é do %s" % [_name(target), "MAL" if evil else "BEM"], Tokens.tint(AvalonArt.MAL if evil else AvalonArt.BEM, 0.5), "Só você vê isso. Conte (ou minta) o que quiser."))
		var b := UI.button("Passar a Dama pra %s" % _name(target), AppButton.Variant.PRIMARY, func(): session.send({"type": "continue"}), "play")
		b.height = 76
		_root.add_child(b)
	else:
		_root.add_child(_big("%s examinou %s" % [_name(holder), _name(target)], Tokens.tint(Color("#1E7F86"), 0.4), "A Dama vai passar pra %s." % _name(target)))
		if session.is_host or _board:
			_root.add_child(UI.small_button("Continuar por %s" % _name(holder), AppButton.Variant.SECONDARY, func(): session.send({"type": "continue"})))


func _build_assassin() -> void:
	_header("Assassinato")
	_track()
	var my_role: String = v.get("role", "")
	if not _board and my_role == "assassino":
		_root.add_child(_big("O bem venceu 3 missões...", Tokens.tint(AvalonArt.MAL, 0.45), "Mas você ainda pode virar o jogo: quem é Merlin?"))
		var evil_ids: Array = v.evil_team.map(func(e): return e.id)
		_root.add_child(UI.caption("Do mal: %s. Conversem antes de escolher." % _names(evil_ids)))
		for p in v.players:
			if p.id in evil_ids:
				continue
			var pid: String = p.id
			var pname: String = p.name
			_root.add_child(UI.button(pname, AppButton.Variant.TEAM_VERMELHO, func():
				App.confirm("Assassinar %s?" % pname, "Se %s for Merlin, o mal vence. Não dá pra voltar atrás." % pname, "Assassinar", func(): session.send({"type": "assassinate", "id": pid}))))
		return
	if not _board and v.get("evil", false):
		var evil_ids2: Array = v.evil_team.map(func(e): return e.id)
		_root.add_child(_big("Ajude o Assassino", Tokens.tint(AvalonArt.MAL, 0.45), "Do mal: %s. Quem vocês acham que é Merlin?" % _names(evil_ids2)))
		return
	_root.add_child(_big("O bem venceu 3 missões!", Tokens.tint(AvalonArt.BEM, 0.45), "Mas o Assassino ainda pode adivinhar quem é Merlin. Os maus estão conversando..."))


# --- Fim -------------------------------------------------------------------

func _build_game_over() -> void:
	var good_won: bool = v.winner == "bem"
	_root.add_child(UI.spacer(8))
	_root.add_child(_big("O %s venceu!" % ("bem" if good_won else "mal"), Tokens.tint(AvalonArt.side_color(good_won), 0.45), AvalonArt.REASONS.get(v.win_reason, "")))
	_track()
	var c := UI.card()
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Quem era quem", 22, Tokens.TINTA, Fonts.title()))
	var roles: Dictionary = v.all_roles
	for p in v.players:
		var r: String = roles.get(p.id, "")
		var extra := AvalonArt.role_name(r)
		if p.id == v.assassin_target:
			extra += " · alvo do Assassino"
		var row := UI.player_row(p.name, AvalonArt.side_color(AvalonArt.is_good(r)), true, extra)
		cv.add_child(row)
	_root.add_child(c)
	if session.is_host:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption("Mesma mesa, papéis novos."))
	elif not _board:
		_root.add_child(UI.caption("Se o host quiser, a próxima começa daqui."))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


func _save_history() -> void:
	var roles: Dictionary = v.get("all_roles", {})
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "avalon",
		"game_name": "Avalon",
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
