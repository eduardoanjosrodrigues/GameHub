extends Screen
## Partida de Halli Galli pelo Wi-Fi: sala, jogo (cada celular mostra só a própria carta) e fim.

const MENU_PATH := "res://games/halli_galli/screens/halli_menu.gd"

var session: HalliSession
var v := {}
var _scroll: ScrollContainer
var _root: VBoxContainer
var _pv: HalliPlayerView
var _last_phase := ""
var _pause_overlay: Control
var _pause_key := ""
var _conn_overlay: Control
var _leaving := false
var _history_saved := false
## Virada mostrada antes da resposta do host: {"pre_up", "at"}.
var _pending := {}
var _shown_up := 0 # quantas cartas a minha pilha aberta tinha no último desenho
## QR da sala: do app (gamehub://) ou do navegador (página servida por este aparelho).
var _qr_web := false
var _swap: SeatSwap


func _init(p_session: HalliSession) -> void:
	super()
	session = p_session
	music = "menu"


func _ready() -> void:
	add_child(session)
	session.view_changed.connect(_on_view)
	session.error.connect(func(m): App.toast(m, Tokens.VERMELHO))
	session.rejected.connect(_on_rejected)
	session.connection_changed.connect(_on_connection)
	session.ended.connect(_on_ended)
	var mw := MaxWidth.new()
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
	_pv = HalliPlayerView.new()
	_pv.visible = false
	_pv.swiped.connect(_on_swipe)
	_pv.double_tapped.connect(_on_double_tap)
	add_child(_pv)
	var leave_btn := UI.icon_button("close", func(): on_back())
	leave_btn.position = Vector2(24, 20)
	leave_btn.name = "LeaveButton"
	_pv.add_child(leave_btn)
	if session.is_host:
		var swap_btn := UI.icon_button("phone", _open_swap)
		swap_btn.position = Vector2(24 + 76, 20)
		_pv.add_child(swap_btn)
	if session is HalliClient:
		_build_connecting()
		(session as HalliClient).connect_to_host()
	else:
		_on_view(session.view, [])


func on_back() -> bool:
	if is_instance_valid(_swap):
		_swap.close()
		return true
	var playing: bool = v.get("phase", "") == HalliRules.PHASE_PLAYING
	if playing or session.is_host:
		var body := "A partida vai acabar pra todo mundo." if session.is_host else "Você sai da partida."
		App.confirm("Sair da partida?", body, "Sair", _leave)
	else:
		_leave()
	return true


# --- Estado ----------------------------------------------------------------

func _on_view(nv: Dictionary, events: Array) -> void:
	if nv.is_empty():
		return
	v = nv
	var phase: String = v.phase
	if phase != _last_phase:
		_on_phase_changed(phase)
	match phase:
		HalliRules.PHASE_LOBBY:
			_build_lobby()
		HalliRules.PHASE_PLAYING:
			_update_play()
		HalliRules.PHASE_GAME_OVER:
			if _last_phase != phase:
				_build_game_over()
	_handle_events(events)
	_update_pause()
	if is_instance_valid(_swap):
		_swap.set_players(_swap_players())
	_last_phase = phase


func _on_phase_changed(phase: String) -> void:
	_pending = {}
	_shown_up = 0
	var playing := phase == HalliRules.PHASE_PLAYING
	_pv.visible = playing
	_scroll.visible = not playing
	music = "" if playing else "menu"
	Audio.music(music)
	if playing:
		_pv.top = -1
	if phase == HalliRules.PHASE_GAME_OVER and not _history_saved:
		_history_saved = true
		_save_history()
	if phase != HalliRules.PHASE_GAME_OVER:
		_history_saved = false


func _on_rejected(message: String) -> void:
	if not _pending.is_empty():
		_pending = {}
		_update_play()
	elif v.get("phase", "") != HalliRules.PHASE_PLAYING:
		App.toast(message, Tokens.VERMELHO)


func _me() -> Dictionary:
	return _player(v.get("you", ""))


func _player(id: String) -> Dictionary:
	for p in v.get("players", []):
		if p.id == id:
			return p
	return {}


func _process(_delta: float) -> void:
	if v.get("phase", "") != HalliRules.PHASE_PLAYING:
		return
	if not _pending.is_empty() and Time.get_ticks_msec() - int(_pending.at) > 1500:
		# O host não respondeu à virada: volta pro que ele disse por último.
		_pending = {}
		_update_play()
	if _pv.my_turn:
		var left: int = int(v.next_flip_at) - session.now_ms()
		_pv.ready_frac = clampf(1.0 - left / float(HalliRules.FLIP_COOLDOWN_MS), 0.0, 1.0)
	_pv.weak = session.weak_signal()


func _update_play() -> void:
	var me := _me()
	if me.is_empty():
		return
	var turn_p := _player(v.turn)
	_pv.color = HalliArt.player_color(int(me.color))
	_pv.player_name = me.name
	if _pending.is_empty():
		_pv.my_turn = v.turn == v.you and not me.out
		_pv.down = int(me.down)
		_pv.set_top(int(v.top), true, int(me.up) > _shown_up)
		_shown_up = int(me.up)
	elif int(me.up) != int(_pending.pre_up) or v.turn != v.you:
		# O host confirmou a virada (ou algo mudou a mesa): passa a valer o estado dele.
		_pending = {}
		_update_play()
		return
	if not _pending.is_empty():
		_pv.status_text = ""
		_pv.hint_text = "Toque duas vezes pra bater o sino"
	elif me.out:
		_pv.status_text = "Você saiu"
		_pv.hint_text = "Pode torcer pelos outros"
	elif _pv.my_turn and v.get("recycle", false):
		_pv.status_text = "Sua vez!"
		_pv.hint_text = "Ninguém tem monte: arraste pra desvirar a mesa"
	elif _pv.my_turn:
		_pv.status_text = "Sua vez!"
		_pv.hint_text = "Toque duas vezes pra bater o sino"
	elif int(me.down) == 0:
		_pv.status_text = "Sem monte"
		_pv.hint_text = "Sua carta ainda vale: bata o sino certo pra voltar"
	else:
		_pv.status_text = "Vez de %s" % turn_p.get("name", "...") if not turn_p.is_empty() else ""
		_pv.hint_text = "Toque duas vezes pra bater o sino"


func _update_pause() -> void:
	var paused: bool = v.get("phase", "") == HalliRules.PHASE_PLAYING and v.get("paused", false)
	var away: Array = v.get("players", []).filter(func(p): return not p.connected)
	var key := ",".join(away.map(func(p): return p.id)) if paused else ""
	if key == _pause_key:
		return
	_pause_key = key
	if _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null
	if not paused:
		return
	var names := ", ".join(away.map(func(p): return p.name))
	var buttons: Array = []
	if session.is_host:
		buttons.append(UI.button("Trocar aparelho", AppButton.Variant.PRIMARY, _open_swap, "phone"))
		for p in away:
			var pid: String = p.id
			buttons.append(UI.button("Continuar sem %s" % p.name, AppButton.Variant.DANGER, func():
				session.send({"type": "remove_player", "id": pid})))
	_pause_overlay = _overlay_card("Pausado", "Esperando %s voltar pra rede..." % names, buttons)
	if is_instance_valid(_swap):
		move_child(_swap, -1)


func _handle_events(events: Array) -> void:
	var you: String = v.get("you", "")
	for e in events:
		match e.get("type", ""):
			"turn":
				if e.player == you:
					Haptics.hg_turn()
					Audio.sfx("hg_turn")
			"bell":
				_on_bell(e, you)
			"back_in":
				if e.player == you:
					Haptics.hg_won()
					App.toast("Sua carta voltou: você está de novo no jogo!", Tokens.SALVIA)
				else:
					App.toast("%s voltou pro jogo" % e.get("name", ""))
			"recycle":
				App.toast("Ninguém tinha monte: cada um desvirou a sua pilha", Tokens.MOSTARDA)
			"undo_flip":
				if e.player == you:
					App.toast("Alguém bateu antes da sua carta: ela voltou pro monte")
			"out":
				if e.player == you:
					Haptics.hg_out()
					Audio.sfx("hg_out")
					_pv.show_banner("Você saiu", "Pode torcer pelos outros", Tokens.TINTA, 1.8)
				else:
					App.toast("%s saiu do jogo" % e.get("name", ""))
			"game_over":
				if e.winner == you:
					Haptics.hg_victory()
					Audio.sfx("win")
					Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.25), 70, Confetti.COLORS, 2.6)
				else:
					Audio.sfx("round")
			"player_joined":
				Audio.sfx("join")
			"player_left":
				Audio.sfx("leave")
			"player_connection":
				App.toast("%s %s" % [e.get("name", ""), "voltou" if e.get("connected") else "caiu da rede"])


func _on_bell(e: Dictionary, you: String) -> void:
	var who := _player(e.player)
	var name: String = who.get("name", "")
	var margin := int(e.get("margin_ms", -1))
	var margin_txt := " · por %d ms" % margin if margin >= 0 else ""
	if e.ok:
		var what := HalliArt.fruit_phrase(int(e.get("fruit", -1)))
		if e.player == you:
			Haptics.hg_won()
			Audio.sfx("hg_collect")
			_pv.show_banner("+%d cartas!" % int(e.cards), what + margin_txt, Tokens.SALVIA)
			Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.42), 36, [Tokens.MOSTARDA, Tokens.SALVIA, Tokens.SUPERFICIE])
		else:
			_pv.show_banner("%s levou" % name, what + margin_txt, HalliArt.player_color(int(who.get("color", 0))))
	else:
		if e.player == you:
			Haptics.hg_wrong()
			Audio.sfx("hg_wrong")
			_pv.show_banner("Errou!", "A mesa voltou pros donos · −%d %s" % [int(e.cards), "carta" if int(e.cards) == 1 else "cartas"], Tokens.VERMELHO)
		elif you in e.get("to", []):
			Haptics.hg_received()
			App.toast("%s errou: sua carta voltou pro monte e você ganhou +%d" % [name, int(e.get("got", {}).get(you, 1))])
		else:
			App.toast("%s errou: as cartas voltaram pro monte" % name)


# --- Gestos ----------------------------------------------------------------

func _can_act() -> bool:
	var me := _me()
	return v.get("phase", "") == HalliRules.PHASE_PLAYING and not v.paused and not me.is_empty() and not me.out


func _on_swipe() -> void:
	if not _can_act() or not _pending.is_empty():
		return
	var recycle: bool = v.get("recycle", false)
	if v.turn != v.you or session.now_ms() < int(v.next_flip_at) or (int(v.next) < 0 and not recycle):
		Haptics.hg_not_turn()
		return
	Haptics.hg_flip()
	Audio.sfx("hg_flip")
	if recycle:
		# A carta do monte desvirado só o host sabe: espera a resposta.
		session.send({"type": "flip"})
		return
	# Mostra a carta na hora; o host confirma em seguida (§5.2).
	_pending = {"pre_up": int(_me().up), "at": Time.get_ticks_msec()}
	_pv.set_top(int(v.next), true, true)
	_shown_up = int(_me().up) + 1
	_pv.down = maxi(0, _pv.down - 1)
	_pv.my_turn = false
	session.send({"type": "flip"})
	_update_play()


func _on_double_tap(local_us: int) -> void:
	if not _can_act():
		return
	Haptics.hg_bell_tap()
	Audio.sfx("hg_bell")
	session.send({"type": "bell", "local_us": local_us})


# --- Conexão ---------------------------------------------------------------

func _on_connection(state: String) -> void:
	if _conn_overlay:
		_conn_overlay.queue_free()
		_conn_overlay = null
	if state == "reconnecting":
		_conn_overlay = _overlay_card("Reconectando ao host...", "Não feche o app. Se a rede voltar, você volta com as mesmas cartas.", [])
	elif state == "connected":
		App.toast("Reconectado!", Tokens.SALVIA)


func _on_ended(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	App.toast(reason, Tokens.VERMELHO)
	App.back_to(load(MENU_PATH))


func _leave() -> void:
	_leaving = true
	session.leave()
	App.back_to(load(MENU_PATH))


# --- Montagem --------------------------------------------------------------

func _header(title_text: String) -> void:
	var row := UI.hbox(16)
	row.add_child(UI.icon_button("back", func(): on_back()))
	var t := UI.title(title_text, 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	_root.add_child(row)


# --- Trocar aparelho (net/seat_transfer.gd) --------------------------------

func _can_swap() -> bool:
	return session.is_host and v.get("phase", "lobby") != "lobby"


func _swap_players() -> Array:
	var out: Array = []
	for p in v.get("players", []):
		if p.id != session.local_id:
			out.append({"id": p.id, "name": p.name, "connected": p.connected, "color": HalliArt.player_color(int(p.color))})
	return out


func _open_swap() -> void:
	if is_instance_valid(_swap):
		return
	_swap = SeatSwap.open(self, session, _swap_players(), str(v.get("host_ip", "")), str(v.get("room_code", "")), false)


func _build_connecting() -> void:
	UI.clear(_root)
	_header("Entrando...")
	_root.add_child(UI.spacer(60))
	var bell := UI.texture("halli_galli", 170)
	bell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(bell)
	bell.pivot_offset = Vector2(85, 85)
	var tw := bell.create_tween().set_loops()
	tw.tween_property(bell, "rotation", 0.15, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bell, "rotation", -0.15, 0.3).set_trans(Tween.TRANS_SINE)
	_root.add_child(UI.subtitle("Conectando à sala..."))
	_root.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _leave))


func _build_lobby() -> void:
	var keep := _scroll.scroll_vertical
	UI.clear(_root)
	_header("Sala do Halli Galli")
	var code: String = v.get("room_code", "")
	if session.is_host:
		var rc := UI.card(Tokens.SUPERFICIE, 24)
		var rv := UI.vbox(12)
		rc.add_child(rv)
		rv.add_child(UI.label("Chame a galera!", 26, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
		var web_url := Net.web_url()
		if web_url != "":
			rv.add_child(UI.segmented([["app", "Tem o app"], ["web", "Navegador (iPhone)"]], "web" if _qr_web else "app", func(k):
				_qr_web = k == "web"
				_rebuild_lobby()))
		if _qr_web and web_url != "":
			var wqr := QrView.new(web_url, 240)
			wqr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rv.add_child(wqr)
			rv.add_child(UI.label("Aponte a câmera pro QR: o jogo abre no navegador, sem instalar nada. Ou digite no navegador:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.label(web_url.trim_prefix("http://").trim_suffix("/"), 40, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.small_button("Copiar endereço", AppButton.Variant.SECONDARY, func():
				DisplayServer.clipboard_set(web_url)
				App.toast("Endereço copiado. Mande pra quem vai jogar.", Tokens.SALVIA)))
		elif code != "":
			var qr := QrView.new(DeepLink.make(code), 240)
			qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rv.add_child(qr)
			rv.add_child(UI.label("Aponte a câmera pro QR ou, no app, toque em Entrar numa sala:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.label(RoomCode.pretty(code), 56, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		if not (_qr_web and web_url != ""):
			rv.add_child(UI.label("IP: %s" % v.get("host_ip", ""), 15, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(rc)
	elif code != "":
		_root.add_child(UI.caption("Sala %s · esperando todo mundo entrar" % RoomCode.pretty(code)))

	var pc := UI.card()
	var pv := UI.vbox(10)
	pc.add_child(pv)
	pv.add_child(UI.label("Ordem da mesa (%d)" % v.players.size(), 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		pv.add_child(UI.label("Deixe na ordem em que vocês estão sentados: a vez passa de cima pra baixo.", 16, Tokens.TINTA_SUAVE))
	var list: Array = v.players
	for i in list.size():
		var p: Dictionary = list[i]
		var extra := "você" if p.id == v.you else ""
		if not p.connected:
			extra = "desconectado"
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

	var decks := int(v.config.decks)
	var dc := UI.card(Tokens.PAPEL, 20)
	var dv := UI.vbox(10)
	dc.add_child(dv)
	dv.add_child(UI.label("Baralhos", 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		dv.add_child(UI.stepper(decks, HalliRules.DECKS_RANGE.x, HalliRules.DECKS_RANGE.y, 1, func(x): session.send({"type": "set_config", "decks": x})))
	var per := decks * 56 / maxi(1, list.size())
	dv.add_child(UI.label("%d %s · %d cartas · uns %d pra cada" % [decks, "baralho" if decks == 1 else "baralhos", decks * 56, per], 17, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(dc)

	_root.add_child(_tip_card())
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
	(func(): _scroll.scroll_vertical = keep).call_deferred()


func _rebuild_lobby() -> void:
	_build_lobby()


func _tip_card() -> Control:
	var c := UI.card(Tokens.MOSTARDA, 20)
	var h := UI.hbox(14)
	c.add_child(h)
	h.add_child(UI.texture("phone", 44, Tokens.TINTA))
	var l := UI.label("Deixe o celular deitado na mesa, na sua frente: ele é a sua carta. Arraste pra virar na sua vez e toque duas vezes em qualquer lugar pra bater o sino.", 17, Tokens.TINTA, Fonts.body_bold())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return c


func _build_game_over() -> void:
	UI.clear(_root)
	_scroll.scroll_vertical = 0
	var you: String = v.you
	var win := _player(v.winner)
	_root.add_child(UI.spacer(10))
	var bg: Color = HalliArt.player_color(int(win.color)) if not win.is_empty() else Tokens.MOSTARDA
	var c := UI.card(bg, 30)
	var cv := UI.vbox(10)
	c.add_child(cv)
	var trophy := UI.texture("trophy", 110, Tokens.TINTA)
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(trophy)
	var headline := "Você venceu!" if v.winner == you else ("%s venceu!" % win.get("name", "") if not win.is_empty() else "Fim de jogo")
	var tl := UI.title(headline, 48)
	cv.add_child(tl)
	_root.add_child(c)
	_root.add_child(HalliResults.ranking_card(v))
	if session.is_host:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption("Mesma ordem, baralho novo."))
	else:
		_root.add_child(UI.caption("Se o host quiser, a próxima começa daqui."))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


func _save_history() -> void:
	History.add(HalliResults.history_entry(v, session.mode))


func _overlay_card(title_text: String, body: String, buttons: Array) -> Control:
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
	for b in buttons:
		cv.add_child(b)
	cv.add_child(UI.button("Sair da partida", AppButton.Variant.SECONDARY, _leave))
	return shade
