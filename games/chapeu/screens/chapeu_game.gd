extends Screen
## Tela da partida do Chapéu. Mostra a fase atual conforme o papel deste aparelho:
## passa-e-joga (vê tudo), jogador no Wi-Fi (explicador, time da vez ou adversário) ou tabuleiro.

const MENU_PATH := "res://games/chapeu/screens/chapeu_menu.gd"

var session: ChapeuSession
var v := {}
var _scroll: ScrollContainer
var _root: VBoxContainer
var _width := Tokens.CONTENT_MAX_WIDTH
var _last_phase := ""
var _built := false

var _time_ms := 0.0
var _last_sec := -1
var _ring: TimerRing
var _word_label: Label
var _word_card: Control
var _stats_label: Label
var _score: Scoreboard
var _progress_label: Label

var _show_config := false
var _writer_revealed := false
var _writer_id := ""
var _word_edits: Array[LineEdit] = []
var _name_edit: LineEdit
var _history_saved := false
var _conn_overlay: Control
var _leaving := false
## QR da sala: do app (gamehub://) ou do navegador (página servida por este aparelho).
var _qr_web := false
var _swap: SeatSwap


func _init(p_session: ChapeuSession) -> void:
	super()
	session = p_session


func _ready() -> void:
	add_child(session)
	session.view_changed.connect(_on_view)
	session.time_changed.connect(_on_time)
	session.error.connect(func(m): App.toast(m, Tokens.VERMELHO))
	session.connection_changed.connect(_on_connection)
	session.ended.connect(_on_ended)
	if session.local_role == "board":
		_width = 1100.0
	var mw := MaxWidth.new(_width)
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
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(_root)
	if session is ClientSession:
		_build_connecting()
		(session as ClientSession).connect_to_host()
	else:
		_on_view(session.view, [])


func on_back() -> bool:
	if is_instance_valid(_swap):
		_swap.close()
		return true
	if _show_config:
		_show_config = false
		_rebuild()
		return true
	_ask_leave()
	return true


# --- Estado ----------------------------------------------------------------

func _on_view(new_view: Dictionary, events: Array) -> void:
	var old := v
	v = new_view
	if v.is_empty():
		return
	var phase: String = v.phase
	if phase != _last_phase:
		_on_phase_changed(phase)
	_time_ms = float(v.get("time_ms", ChapeuRules.TURN_MS))
	if is_instance_valid(_swap):
		_swap.set_players(_swap_players())
	if not _built or _needs_rebuild(old, v):
		_rebuild()
	else:
		_update()
	_handle_events(events)
	_last_phase = phase


func _on_phase_changed(phase: String) -> void:
	_show_config = false
	_last_sec = -1
	Audio.set_music_rate(1.0)
	match phase:
		ChapeuRules.PHASE_TURN:
			music = "turn"
		ChapeuRules.PHASE_WRITING:
			music = ""
		_:
			music = "menu"
	Audio.music(music)
	if phase == ChapeuRules.PHASE_GAME_OVER and not _history_saved:
		_history_saved = true
		_save_history()
	if phase != ChapeuRules.PHASE_GAME_OVER:
		_history_saved = false


func _needs_rebuild(old: Dictionary, nv: Dictionary) -> bool:
	if old.get("phase", "") != nv.phase:
		return true
	match nv.phase:
		ChapeuRules.PHASE_WRITING:
			if session.mode == "local":
				return _current_writer_id(nv) != _writer_id
			return (nv.you in nv.submitted) != (old.get("you", "") in old.get("submitted", []))
		ChapeuRules.PHASE_TURN:
			return old.get("paused") != nv.paused or old.get("pause_reason") != nv.pause_reason or old.get("explainer") != nv.explainer
		ChapeuRules.PHASE_LOBBY:
			if session.mode == "local" and not _show_config:
				return true
	return true


func _on_time(ms: int) -> void:
	_time_ms = float(ms)


func _process(delta: float) -> void:
	if v.is_empty() or v.phase != ChapeuRules.PHASE_TURN or v.paused:
		return
	_time_ms = maxf(0.0, _time_ms - delta * 1000.0)
	if _ring:
		_ring.remaining_ms = int(_time_ms)
	var sec := int(ceil(_time_ms / 1000.0))
	if sec != _last_sec:
		_last_sec = sec
		if sec <= 10 and sec > 0:
			Audio.sfx("tick", 1.0 + (10 - sec) * 0.03)
			if sec <= 5:
				Haptics.countdown_pulse()
		Audio.set_music_rate(1.12 if sec <= 10 else 1.0)


func _handle_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"hit":
				Audio.sfx("hit")
				Haptics.hit()
				if _word_card and is_instance_valid(_word_card):
					Confetti.burst(self, _word_card.get_global_rect().get_center() - get_global_rect().position, 16)
			"skip":
				Audio.sfx("skip")
				Haptics.skip()
			"new_word":
				_animate_word()
			"time_up":
				Audio.sfx("buzzer")
				Haptics.time_up()
			"hat_empty":
				Audio.sfx("hat_empty")
			"turn_started":
				Audio.sfx("start")
			"player_joined":
				if session.mode == "wifi":
					Audio.sfx("join")
			"player_left":
				Audio.sfx("leave")
			"player_connection":
				App.toast("%s %s" % [e.get("name", ""), "voltou" if e.get("connected") else "caiu da rede"])
			"words_submitted":
				Audio.sfx("pop")
			"paused", "resumed":
				Audio.sfx("tap")
			"phase":
				if e.get("phase") == ChapeuRules.PHASE_ROUND_INTRO:
					Audio.sfx("round")
			"game_over":
				Audio.sfx("win")
				var winner: String = e.get("result", {}).get("winner", "")
				var colors := [Tokens.team_color(winner), Tokens.MOSTARDA, Tokens.SUPERFICIE] if winner != "" else Confetti.COLORS
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 60, colors, 2.6)


func _on_connection(state: String) -> void:
	if _conn_overlay:
		_conn_overlay.queue_free()
		_conn_overlay = null
	if state == "reconnecting":
		_conn_overlay = _overlay_card("Reconectando ao host...", "Não feche o app. Se a rede voltar, você volta pro mesmo lugar.", [])
	elif state == "connected":
		App.toast("Reconectado!", Tokens.SALVIA)


func _on_ended(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	App.toast(reason, Tokens.VERMELHO)
	_go_to_menu()


func _ask_leave() -> void:
	var in_game: bool = not v.is_empty() and v.phase != ChapeuRules.PHASE_LOBBY and v.phase != ChapeuRules.PHASE_GAME_OVER
	var body := "A partida em andamento vai acabar pra todo mundo." if session.is_host and session.mode == "wifi" else ""
	if in_game or (session.mode == "wifi" and session.is_host) or (session.mode == "local" and not v.is_empty() and not v.players.is_empty() and v.phase != ChapeuRules.PHASE_GAME_OVER):
		App.confirm("Sair da partida?", body, "Sair", _leave)
	else:
		_leave()


func _leave() -> void:
	_leaving = true
	session.leave()
	_go_to_menu()


func _go_to_menu() -> void:
	App.back_to(load(MENU_PATH))


# --- Montagem --------------------------------------------------------------

func _rebuild() -> void:
	var keep_scroll := _scroll.scroll_vertical if v.get("phase", "") == _last_phase else 0
	var name_focused := _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus()
	UI.clear(_root)
	_ring = null
	_word_label = null
	_word_card = null
	_stats_label = null
	_score = null
	_progress_label = null
	_name_edit = null
	_word_edits = []
	_built = true
	match v.phase:
		ChapeuRules.PHASE_LOBBY:
			if _show_config:
				_build_config()
			elif session.mode == "local":
				_build_local_lobby()
			else:
				_build_wifi_lobby()
		ChapeuRules.PHASE_WRITING:
			_build_writing()
		ChapeuRules.PHASE_ROUND_INTRO:
			_build_round_intro()
		ChapeuRules.PHASE_TURN_READY:
			_build_turn_ready()
		ChapeuRules.PHASE_TURN:
			_build_turn()
		ChapeuRules.PHASE_TURN_SUMMARY:
			_build_turn_summary()
		ChapeuRules.PHASE_ROUND_END:
			_build_round_end()
		ChapeuRules.PHASE_GAME_OVER:
			_build_game_over()
	if keep_scroll > 0:
		(func(): _scroll.scroll_vertical = keep_scroll).call_deferred()
	if name_focused and _name_edit:
		var ne := _name_edit
		(func(): if is_instance_valid(ne) and ne.is_inside_tree(): ne.grab_focus()).call_deferred()


func _update() -> void:
	match v.phase:
		ChapeuRules.PHASE_TURN:
			if _word_label:
				_word_label.text = v.word
			if _stats_label:
				_stats_label.text = _turn_stats_text()
			if _score:
				_score.set_scores(v.totals)
			if _ring:
				_ring.remaining_ms = int(_time_ms)
		ChapeuRules.PHASE_WRITING:
			if _progress_label:
				_progress_label.text = _writing_progress_text()


func _header(title_text: String) -> void:
	var row := UI.hbox(16)
	row.add_child(UI.icon_button("back", func(): on_back()))
	var t := UI.title(title_text, 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	if v.phase not in [ChapeuRules.PHASE_LOBBY, ChapeuRules.PHASE_WRITING]:
		var chip := UI.label("Rodada %d/3" % (int(v.round) + 1), 18, Tokens.TINTA_SUAVE, Fonts.body_bold())
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(chip)
	if _can_swap():
		row.add_child(UI.icon_button("phone", _open_swap))
	_root.add_child(row)


# --- Trocar aparelho (net/seat_transfer.gd) --------------------------------

func _can_swap() -> bool:
	return session.mode == "wifi" and (session.is_host or session.local_role == "board") and v.get("phase", "lobby") != "lobby"


func _swap_players() -> Array:
	var out: Array = []
	for p in v.get("players", []):
		if p.id != session.local_id:
			out.append({"id": p.id, "name": p.name, "connected": p.connected, "color": Tokens.team_color(str(p.get("team", "azul")))})
	return out


func _open_swap() -> void:
	if is_instance_valid(_swap):
		return
	_swap = SeatSwap.open(self, session, _swap_players(), str(v.get("host_ip", "")), str(v.get("room_code", "")), session.local_role == "board")


func _build_connecting() -> void:
	UI.clear(_root)
	_header("Entrando...")
	_root.add_child(UI.spacer(60))
	var hat := UI.texture("chapeu", 160)
	hat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(hat)
	hat.pivot_offset = Vector2(80, 80)
	var tw := hat.create_tween().set_loops()
	tw.tween_property(hat, "rotation", 0.2, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hat, "rotation", -0.2, 0.4).set_trans(Tween.TRANS_SINE)
	_root.add_child(UI.subtitle("Conectando à sala..."))
	_root.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _leave))


# --- Lobby -----------------------------------------------------------------

func _build_local_lobby() -> void:
	_header("Passa-e-joga")
	var add := UI.card()
	var av := UI.vbox(12)
	add.add_child(av)
	av.add_child(UI.label("Quem vai jogar?", 24, Tokens.TINTA, Fonts.title()))
	var row := UI.hbox(12)
	_name_edit = UI.line_edit("Nome do jogador", "", 20)
	_name_edit.text_submitted.connect(func(_t): _add_local_player())
	row.add_child(_name_edit)
	row.add_child(UI.icon_button("plus", _add_local_player, AppButton.Variant.SUCCESS))
	av.add_child(row)
	av.add_child(UI.label("De 4 a 12 jogadores, pelo menos 2 em cada time. Toque em ⇄ pra trocar de time.", 16, Tokens.TINTA_SUAVE))
	_root.add_child(add)
	_root.add_child(_teams_block(true))
	_root.add_child(_config_summary())
	_start_button()


func _add_local_player() -> void:
	var n := TextNorm.clean(_name_edit.text)
	if n == "":
		_name_edit.grab_focus()
		return
	session.send({"type": "add_player", "name": n})


func _build_wifi_lobby() -> void:
	_header("Sala")
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
			var wqr := QrView.new(web_url, 300 if session.local_role == "board" else 240)
			wqr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rv.add_child(wqr)
			rv.add_child(UI.label("Aponte a câmera pro QR: o jogo abre no navegador, sem instalar nada. Ou digite no navegador:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.label(web_url.trim_prefix("http://").trim_suffix("/"), 40, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.small_button("Copiar endereço", AppButton.Variant.SECONDARY, func():
				DisplayServer.clipboard_set(web_url)
				App.toast("Endereço copiado. Mande pra quem vai jogar.", Tokens.SALVIA)))
		elif code != "":
			var qr := QrView.new(DeepLink.make(code), 300 if session.local_role == "board" else 240)
			qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rv.add_child(qr)
			rv.add_child(UI.label("Aponte a câmera pro QR ou, no app, toque em Entrar numa sala:", 16, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
			rv.add_child(UI.label(RoomCode.pretty(code), 56, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		if not (_qr_web and web_url != ""):
			rv.add_child(UI.label("IP: %s" % v.get("host_ip", ""), 15, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(rc)
	elif code != "":
		_root.add_child(UI.caption("Sala %s · esperando todo mundo entrar" % RoomCode.pretty(code)))
	_root.add_child(_teams_block(false))
	_root.add_child(_config_summary())
	if session.is_host:
		_start_button()
	else:
		_root.add_child(UI.caption("Esperando o host começar a partida..."))


func _rebuild_lobby() -> void:
	_rebuild()


## Os dois times com seus jogadores.
func _teams_block(local_edit: bool) -> Control:
	var wide := session.local_role == "board" and size.x > 1000
	var box: BoxContainer = UI.hbox(16) if wide else UI.vbox(16)
	var me: Dictionary = _me()
	for team in ChapeuRules.TEAMS:
		var c := UI.card(Tokens.SUPERFICIE, 20)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := UI.vbox(10)
		c.add_child(tv)
		var members: Array = v.players.filter(func(p): return p.team == team)
		var head := UI.hbox(10)
		var dot := Avatar.new("", Tokens.team_color(team), 28)
		head.add_child(dot)
		var hl := UI.label("%s (%d)" % [Tokens.team_name(team), members.size()], 22, Tokens.TINTA, Fonts.title())
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(hl)
		tv.add_child(head)
		if members.is_empty():
			tv.add_child(UI.label("Ninguém ainda", 17, Tokens.TINTA_SUAVE))
		for p in members:
			var extra := "você" if not me.is_empty() and p.id == me.id else ""
			if not p.connected:
				extra = "desconectado"
			var prow := UI.player_row(p.name, Tokens.team_color(team), p.connected, extra)
			if local_edit:
				var pid: String = p.id
				var other: String = "vermelho" if team == "azul" else "azul"
				prow.add_child(UI.icon_button("shuffle", func(): session.send({"type": "set_team", "id": pid, "team": other})))
				prow.add_child(UI.icon_button("close", func(): session.send({"type": "remove_player", "id": pid})))
			tv.add_child(prow)
		if not local_edit and not me.is_empty() and me.team != team:
			var variant := AppButton.Variant.TEAM_AZUL if team == "azul" else AppButton.Variant.TEAM_VERMELHO
			var t: String = team
			tv.add_child(UI.small_button("Entrar no %s" % Tokens.team_name(team), variant, func(): session.send({"type": "set_team", "team": t})))
		box.add_child(c)
	return box


func _config_summary() -> Control:
	var cfg: Dictionary = v.config
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var lines: Array[String] = []
	match cfg.source:
		"jogadores":
			lines.append("Palavras dos jogadores: %d por pessoa" % cfg.words_per_player)
		"lista":
			lines.append("Lista pronta: %d palavras" % cfg.list_count)
		"mistura":
			lines.append("Mistura: %d por pessoa + %d da lista" % [cfg.words_per_player, cfg.list_count])
	if cfg.source != "jogadores":
		var names: Array = []
		for t in v.themes:
			if t.id in cfg.themes:
				names.append(t.nome)
		lines.append("Temas: " + (", ".join(names) if not names.is_empty() else "nenhum"))
	if session.mode == "wifi":
		lines.append("Adversário vê a palavra: %s" % ("sim" if cfg.opponent_sees_word else "não"))
	lines.append("60 s por vez · pular custa 1 ponto · 3 rodadas")
	cv.add_child(UI.label("\n".join(lines), 17, Tokens.TINTA, Fonts.body()))
	if session.is_host:
		cv.add_child(UI.small_button("Configurar", AppButton.Variant.SECONDARY, func():
			_show_config = true
			_rebuild(), "settings"))
	return c


func _start_button() -> void:
	var why: String = v.can_start
	var b := UI.button("Começar partida", AppButton.Variant.SUCCESS, func(): session.send({"type": "start"}), "play")
	b.height = 84
	b.font_size = 26
	b.disabled = why != ""
	_root.add_child(b)
	if why != "":
		_root.add_child(UI.caption(why))


func _build_config() -> void:
	var row := UI.hbox(16)
	row.add_child(UI.icon_button("back", func():
		_show_config = false
		_rebuild()))
	var t := UI.title("Configurar", 32, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	_root.add_child(row)
	var cfg: Dictionary = v.config
	var c := UI.card()
	var cv := UI.vbox(26)
	c.add_child(cv)
	cv.add_child(UI.setting_block("De onde vêm as palavras?", UI.segmented(ChapeuText.SOURCES, cfg.source, func(k): _set_cfg({"source": k}))))
	if cfg.source != "lista":
		cv.add_child(UI.setting_block("Palavras por jogador", UI.stepper(int(cfg.words_per_player), ChapeuRules.WORDS_PER_PLAYER_RANGE.x, ChapeuRules.WORDS_PER_PLAYER_RANGE.y, 1, func(x): _set_cfg({"words_per_player": x}))))
	if cfg.source != "jogadores":
		cv.add_child(UI.setting_block("Palavras da lista pronta", UI.stepper(int(cfg.list_count), ChapeuRules.LIST_COUNT_RANGE.x, ChapeuRules.LIST_COUNT_RANGE.y, 5, func(x): _set_cfg({"list_count": x}))))
		var themes := UI.vbox(10)
		for th in v.themes:
			var on: bool = th.id in cfg.themes
			var b := UI.small_button("%s (%d)" % [th.nome, th.count], AppButton.Variant.PRIMARY if on else AppButton.Variant.SECONDARY, Callable(), "check" if on else "")
			b.selected = on
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var id: String = th.id
			b.pressed.connect(func():
				var list: Array = cfg.themes.duplicate()
				if id in list:
					list.erase(id)
				else:
					list.append(id)
				_set_cfg({"themes": list}))
			themes.add_child(b)
		cv.add_child(UI.setting_block("Temas", themes))
	if session.mode == "wifi":
		cv.add_child(UI.setting_block("Time adversário vê a palavra", UI.toggle(cfg.opponent_sees_word, func(on): _set_cfg({"opponent_sees_word": on})), "Pra fiscalizar quem explica. Seu time nunca vê."))
	_root.add_child(c)
	_root.add_child(UI.caption("Fixo: 60 segundos por vez, pular custa 1 ponto, 3 rodadas (Descrever, Uma palavra, Mímica)."))
	_root.add_child(UI.button("Pronto", AppButton.Variant.SUCCESS, func():
		_show_config = false
		_rebuild(), "check"))


func _set_cfg(values: Dictionary) -> void:
	var a := values.duplicate()
	a.type = "set_config"
	session.send(a)


# --- Escrever palavras -----------------------------------------------------

func _current_writer_id(view: Dictionary) -> String:
	for p in view.players:
		if p.id not in view.submitted:
			return p.id
	return ""


func _writing_progress_text() -> String:
	return "%d de %d já escreveram" % [v.submitted.size(), v.players.size()]


func _build_writing() -> void:
	_header("Palavras")
	var n := int(v.config.words_per_player)
	if session.mode == "local":
		_writer_id = _current_writer_id(v)
		var p: Dictionary = _player(_writer_id)
		if p.is_empty():
			return
		if not _writer_revealed:
			var c := UI.card(Tokens.team_color(p.team), 28)
			var cv := UI.vbox(16)
			c.add_child(cv)
			cv.add_child(UI.label("Passe o celular para", 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
			var av := Avatar.new(p.name, Tokens.SUPERFICIE, 110)
			av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cv.add_child(av)
			cv.add_child(UI.title(p.name, 48))
			cv.add_child(UI.label("Só %s pode olhar a próxima tela." % p.name, 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			_root.add_child(c)
			_root.add_child(UI.button("Sou %s, escrever" % p.name, AppButton.Variant.SUCCESS, func():
				_writer_revealed = true
				_rebuild(), "check"))
			_progress_label = UI.caption(_writing_progress_text())
			_root.add_child(_progress_label)
			return
		_root.add_child(UI.subtitle("%s, escreva %d %s" % [p.name, n, "palavra" if n == 1 else "palavras"]))
		_word_form(n, func(words):
			_writer_revealed = false
			session.send({"type": "submit_words", "id": _writer_id, "words": words}), "Pronto, esconder")
		return

	var mine: bool = v.you in v.submitted
	if session.local_role == "player" and not mine:
		_root.add_child(UI.subtitle("Escreva %d %s em segredo" % [n, "palavra" if n == 1 else "palavras"]))
		_root.add_child(UI.caption("Nomes de famosos, objetos, filmes... o que quiser! Ninguém vai ver quem escreveu."))
		_word_form(n, func(words): session.send({"type": "submit_words", "words": words}), "Enviar pro chapéu")
	else:
		var c := UI.card()
		var cv := UI.vbox(12)
		c.add_child(cv)
		if session.local_role == "player":
			cv.add_child(UI.title("Pronto!", 40))
			cv.add_child(UI.caption("Suas palavras estão no chapéu. Esperando os outros..."))
		else:
			cv.add_child(UI.title("Escrevendo palavras...", 40))
		_progress_label = UI.label(_writing_progress_text(), 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		cv.add_child(_progress_label)
		_root.add_child(c)
	_root.add_child(_writers_list())


func _writers_list() -> Control:
	var c := UI.card()
	var cv := UI.vbox(10)
	c.add_child(cv)
	for p in v.players:
		var done: bool = p.id in v.submitted
		cv.add_child(UI.player_row(p.name, Tokens.team_color(p.team), p.connected, "pronto ✓" if done else "escrevendo..."))
	return c


func _word_form(n: int, on_done: Callable, done_text: String) -> void:
	var c := UI.card()
	var cv := UI.vbox(12)
	c.add_child(cv)
	for i in n:
		var e := UI.line_edit("Palavra %d" % (i + 1), "", ChapeuRules.MAX_WORD_LEN)
		cv.add_child(e)
		_word_edits.append(e)
	for i in n:
		var idx := i
		_word_edits[i].text_submitted.connect(func(_t):
			if idx + 1 < _word_edits.size():
				_word_edits[idx + 1].grab_focus()
			else:
				_submit_words(on_done))
	_root.add_child(c)
	_root.add_child(UI.button(done_text, AppButton.Variant.SUCCESS, func(): _submit_words(on_done), "check"))
	_root.add_child(UI.spacer(260)) # espaço pro teclado
	if not _word_edits.is_empty():
		var first: LineEdit = _word_edits[0]
		# Adiado: a tela pode ser remontada antes (o campo sai da árvore).
		(func(): if is_instance_valid(first) and first.is_inside_tree(): first.grab_focus()).call_deferred()


func _submit_words(on_done: Callable) -> void:
	var words: Array = []
	for e in _word_edits:
		var w := TextNorm.clean(e.text)
		if w == "":
			App.toast("Preencha todas as palavras", Tokens.VERMELHO)
			e.grab_focus()
			return
		words.append(w)
	DisplayServer.virtual_keyboard_hide()
	on_done.call(words)


# --- Rodada ----------------------------------------------------------------

func _build_round_intro() -> void:
	_header("Chapéu")
	var info: Dictionary = ChapeuText.round_info(v.round_key)
	var c := UI.card(info.cor, 28)
	var cv := UI.vbox(12)
	c.add_child(cv)
	cv.add_child(UI.label("Rodada %d de 3" % (int(v.round) + 1), 22, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	var ic := UI.texture(info.icone, 150 if session.local_role != "board" else 220)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(ic)
	cv.add_child(UI.title(info.nome, 56 if session.local_role != "board" else 80))
	cv.add_child(UI.label(info.regra, 22 if session.local_role != "board" else 30, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	c.pivot_offset = Vector2(_width / 2.0, 200)
	c.scale = Vector2(0.8, 0.8)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_root.add_child(UI.caption("%d palavras no chapéu" % v.word_count))
	if int(v.round) > 0:
		_root.add_child(Scoreboard.new(v.totals, session.local_role == "board"))
	if session.is_host:
		_root.add_child(UI.button("Começar rodada", AppButton.Variant.SUCCESS, func(): session.send({"type": "next"}), "play"))
	else:
		_root.add_child(UI.caption("Esperando o host..."))


func _build_turn_ready() -> void:
	_header("Chapéu")
	var team: String = v.team_turn
	var me := _me()
	var explainer := _player(v.explainer)
	var is_board := session.local_role == "board"
	var banner := UI.card(Tokens.team_color(team), 24)
	var bv := UI.vbox(6)
	banner.add_child(bv)
	bv.add_child(UI.label("Vez do", 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	bv.add_child(UI.title(Tokens.team_name(team), 60 if not is_board else 90))
	bv.add_child(UI.label(ChapeuText.round_info(v.round_key).curta, 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(banner)
	var carrying: bool = v.carry_ms > 0 and not explainer.is_empty()
	var can_choose: bool = not carrying and (session.mode == "local" or session.is_host or (not me.is_empty() and me.team == team))

	if not explainer.is_empty():
		var c := UI.card()
		var cv := UI.vbox(14)
		c.add_child(cv)
		var av := Avatar.new(explainer.name, Tokens.team_color(team), 96)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(av)
		var i_explain: bool = session.mode == "wifi" and not me.is_empty() and me.id == explainer.id
		if session.mode == "local":
			cv.add_child(UI.label("Passe o celular para", 22, Tokens.TINTA_SUAVE, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
			cv.add_child(UI.title(explainer.name, 48))
		elif i_explain:
			cv.add_child(UI.title("Você vai explicar!", 44))
		else:
			cv.add_child(UI.title("%s vai explicar" % explainer.name, 40))
		if carrying:
			cv.add_child(UI.label("Continua com o tempo que sobrou: %d s" % int(ceil(v.carry_ms / 1000.0)), 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(c)
		if session.mode == "local" or i_explain:
			var b := UI.button("Começar!", AppButton.Variant.SUCCESS, func(): session.send({"type": "start_turn"}), "play")
			b.height = 96
			b.font_size = 32
			_root.add_child(b)
		elif not is_board:
			_root.add_child(UI.caption("Esperando %s começar..." % explainer.name))
		if can_choose:
			_root.add_child(UI.label("Trocar quem explica:", 18, Tokens.TINTA_SUAVE, Fonts.body_bold()))
			_root.add_child(_explainer_choices(team, true))
	else:
		if can_choose and not is_board:
			_root.add_child(UI.subtitle("Quem vai explicar?"))
			_root.add_child(_explainer_choices(team, false))
		elif can_choose and is_board:
			_root.add_child(UI.subtitle("O %s está escolhendo quem explica..." % Tokens.team_name(team)))
			_root.add_child(_explainer_choices(team, false))
		else:
			_root.add_child(UI.subtitle("O %s está escolhendo quem explica..." % Tokens.team_name(team)))
	_root.add_child(Scoreboard.new(v.totals, is_board))


func _explainer_choices(team: String, small: bool) -> Control:
	var box := UI.vbox(10)
	var members: Array = v.players.filter(func(p): return p.team == team)
	for p in members:
		var label: String = "%s  ·  explicou %d×" % [p.name, p.explained] if p.explained > 0 else p.name
		if not p.connected:
			label = "%s (desconectado)" % p.name
		var variant := AppButton.Variant.SECONDARY if small else (AppButton.Variant.TEAM_AZUL if team == "azul" else AppButton.Variant.TEAM_VERMELHO)
		var b := UI.small_button(label, variant) if small else UI.button(label, variant)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not p.connected or p.id == v.explainer
		var pid: String = p.id
		b.pressed.connect(func(): session.send({"type": "choose_explainer", "id": pid}))
		box.add_child(b)
	return box


# --- Vez -------------------------------------------------------------------

func _turn_stats_text() -> String:
	return "Acertos: %d  ·  Pulos: %d" % [v.turn_hits, v.turn_skips]


func _build_turn() -> void:
	var me := _me()
	var team: String = v.team_turn
	var explainer := _player(v.explainer)
	var info: Dictionary = ChapeuText.round_info(v.round_key)
	var is_board := session.local_role == "board"
	var i_explain: bool = session.mode == "local" or (not me.is_empty() and me.id == v.explainer)

	# Topo: regra da rodada + pausa
	var top := UI.hbox(12)
	var chip := UI.card(info.cor, 12)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(UI.label("%s: %s" % [info.nome, info.curta], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(chip)
	if i_explain and not v.paused:
		top.add_child(UI.icon_button("pause", func(): session.send({"type": "pause"})))
	if _can_swap():
		top.add_child(UI.icon_button("phone", _open_swap))
	_root.add_child(top)

	if v.paused:
		_build_paused(explainer, i_explain)
		return

	_ring = TimerRing.new(220 if not is_board else 360)
	_ring.total_ms = int(v.turn_ms)
	_ring.remaining_ms = int(_time_ms)
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if i_explain and not is_board:
		_ring.custom_minimum_size = Vector2(170, 170)
		_ring.diameter = 170
		_root.add_child(UI.spacer(6))
		_root.add_child(_ring)
		_word_card = UI.card(Tokens.SUPERFICIE, 28)
		_word_card.custom_minimum_size.y = 220
		var wc := CenterContainer.new()
		_word_card.add_child(wc)
		_word_label = UI.label(v.word, Tokens.FS_WORD, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_word_label.custom_minimum_size.x = _width - 140
		wc.add_child(_word_label)
		_root.add_child(_word_card)
		_stats_label = UI.label(_turn_stats_text(), 20, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_stats_label)
		var row := UI.hbox(16)
		var skip := UI.button("Pular", AppButton.Variant.DANGER, func(): session.send({"type": "skip"}), "skip")
		skip.height = 110
		skip.font_size = 28
		skip.sound = ""
		var hit := UI.button("Acertou!", AppButton.Variant.SUCCESS, func(): session.send({"type": "hit"}), "check")
		hit.height = 110
		hit.font_size = 28
		hit.sound = ""
		row.add_child(skip)
		row.add_child(hit)
		_root.add_child(row)
		_root.add_child(UI.caption("Pular custa 1 ponto"))
		return

	if is_board:
		_score = Scoreboard.new(v.totals, true, team)
		_root.add_child(_score)
		_root.add_child(_ring)
		_root.add_child(UI.title("%s está explicando" % explainer.get("name", ""), 48))
		_root.add_child(UI.label(info.regra, 26, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_stats_label = UI.label(_turn_stats_text(), 24, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_stats_label)
		return

	var my_team: bool = not me.is_empty() and me.team == team
	_root.add_child(_ring)
	if my_team:
		var c := UI.card(Tokens.team_color(team), 28)
		var cv := UI.vbox(8)
		c.add_child(cv)
		cv.add_child(UI.title("Adivinhe!", 64))
		cv.add_child(UI.label("%s está explicando" % explainer.get("name", ""), 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(c)
	else:
		_root.add_child(UI.subtitle("Vez do %s" % Tokens.team_name(team)))
		_root.add_child(UI.caption("%s está explicando. Fica de olho!" % explainer.get("name", "")))
		if v.config.opponent_sees_word:
			_word_card = UI.card(Tokens.PAPEL, 20)
			var wv := UI.vbox(4)
			_word_card.add_child(wv)
			wv.add_child(UI.label("A palavra é", 16, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			_word_label = UI.label(v.word, 40, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
			wv.add_child(_word_label)
			_root.add_child(_word_card)
	_stats_label = UI.label(_turn_stats_text(), 20, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_stats_label)
	_score = Scoreboard.new(v.totals, false, team)
	_root.add_child(_score)


func _build_paused(explainer: Dictionary, i_explain: bool) -> void:
	var c := UI.card(Tokens.MOSTARDA, 28)
	var cv := UI.vbox(14)
	c.add_child(cv)
	var disconnected: bool = v.pause_reason == "disconnect"
	if disconnected:
		cv.add_child(UI.title("Esperando %s voltar..." % explainer.get("name", ""), 36))
		cv.add_child(UI.label("A conexão caiu. O tempo está parado.", 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		cv.add_child(UI.title("Pausado", 56))
		cv.add_child(UI.label("Restam %d s" % int(ceil(_time_ms / 1000.0)), 24, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	if not disconnected and i_explain:
		var b := UI.button("Continuar", AppButton.Variant.SUCCESS, func(): session.send({"type": "resume"}), "play")
		b.height = 96
		_root.add_child(b)
	elif disconnected and session.is_host:
		_root.add_child(UI.button("Encerrar a vez de %s" % explainer.get("name", ""), AppButton.Variant.DANGER, func(): session.send({"type": "end_turn"})))
	elif not disconnected:
		_root.add_child(UI.caption("%s pausou o jogo." % explainer.get("name", "")))
	_root.add_child(Scoreboard.new(v.totals, session.local_role == "board", v.team_turn))


func _animate_word() -> void:
	if _word_label == null or not is_instance_valid(_word_label):
		return
	_word_label.text = v.word
	var card := _word_card
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.85, 0.85)
	card.rotation = deg_to_rad(randf_range(-4, 4))
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", 0.0, 0.25)


# --- Resultados ------------------------------------------------------------

func _build_turn_summary() -> void:
	_header("Chapéu")
	var team: String = v.team_turn
	var explainer := _player(v.explainer)
	var me := _me()
	var c := UI.card(Tokens.team_color(team), 28)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.title("O chapéu esvaziou!" if v.turn_round_over else "Tempo esgotado!", 44))
	var saldo: int = int(v.turn_hits) - int(v.turn_skips)
	cv.add_child(UI.label("%s%d pro %s" % ["+" if saldo >= 0 else "", saldo, Tokens.team_name(team)], 34, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.label("%d acertos · %d pulos" % [v.turn_hits, v.turn_skips], 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	if not v.hit_words.is_empty():
		var wc := UI.card()
		var wv := UI.vbox(8)
		wc.add_child(wv)
		wv.add_child(UI.label("Acertaram", 20, Tokens.TINTA, Fonts.title()))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for w in v.hit_words:
			var chip := UI.card(Tokens.PAPEL, 12)
			var wl := UI.label(w, 18, Tokens.TINTA, Fonts.body_bold())
			wl.autowrap_mode = TextServer.AUTOWRAP_OFF
			chip.add_child(wl)
			flow.add_child(chip)
		wv.add_child(flow)
		_root.add_child(wc)
	if v.turn_round_over and v.carry_ms > 0 and not explainer.is_empty():
		_root.add_child(UI.caption("%s começa a próxima rodada com %d s." % [explainer.name, int(ceil(v.carry_ms / 1000.0))]))
	_root.add_child(Scoreboard.new(v.totals, session.local_role == "board"))
	var can_next: bool = session.is_host or (not me.is_empty() and me.id == v.explainer)
	if can_next:
		_root.add_child(UI.button("Continuar", AppButton.Variant.PRIMARY, func(): session.send({"type": "next"}), "play"))
	else:
		_root.add_child(UI.caption("Esperando %s continuar..." % explainer.get("name", "")))


func _build_round_end() -> void:
	_header("Chapéu")
	var r := int(v.round)
	var info: Dictionary = ChapeuText.round_info(v.round_key)
	var pts: Array = v.scores[r]
	var round_winner := ""
	if pts[0] != pts[1]:
		round_winner = "azul" if pts[0] > pts[1] else "vermelho"
	var c := UI.card(info.cor, 28)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Fim da rodada %d" % (r + 1), 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.title(info.nome, 48))
	cv.add_child(UI.label("Rodada empatada!" if round_winner == "" else "Rodada do %s!" % Tokens.team_name(round_winner), 26, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.label("Azul %d  ×  %d Vermelho" % [pts[0], pts[1]], 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	_root.add_child(UI.label("Placar geral", 22, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(Scoreboard.new(v.totals, session.local_role == "board"))
	if session.is_host:
		var last := r >= ChapeuRules.ROUNDS.size() - 1
		_root.add_child(UI.button("Ver resultado" if last else "Próxima rodada", AppButton.Variant.SUCCESS, func(): session.send({"type": "next"}), "trophy" if last else "play"))
	else:
		_root.add_child(UI.caption("Esperando o host..."))


func _build_game_over() -> void:
	var res: Dictionary = v.result
	var winner: String = res.get("winner", "")
	_root.add_child(UI.spacer(10))
	var c := UI.card(Tokens.team_color(winner) if winner != "" else Tokens.MOSTARDA, 30)
	var cv := UI.vbox(10)
	c.add_child(cv)
	var trophy := UI.texture("trophy", 110, Tokens.TINTA)
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(trophy)
	cv.add_child(UI.title("Empate!" if winner == "" else "%s venceu!" % Tokens.team_name(winner), 50))
	cv.add_child(UI.label(ChapeuText.CRITERIA.get(res.get("criterion", ""), ""), 19, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	trophy.pivot_offset = Vector2(55, 55)
	var tw := trophy.create_tween().set_loops()
	tw.tween_property(trophy, "position:y", trophy.position.y - 10, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(trophy, "position:y", trophy.position.y, 0.45).set_trans(Tween.TRANS_SINE)
	_root.add_child(Scoreboard.new(res.get("totals", {}), session.local_role == "board", winner))

	var table := UI.card()
	var tv := UI.vbox(10)
	table.add_child(tv)
	var rw: Dictionary = res.get("rounds_won", {})
	tv.add_child(UI.label("Rodadas vencidas: Azul %d × %d Vermelho" % [rw.get("azul", 0), rw.get("vermelho", 0)], 18, Tokens.TINTA, Fonts.body_bold()))
	var scores: Array = res.get("scores", [])
	for i in scores.size():
		var row := UI.hbox(10)
		var nm := UI.label(ChapeuText.round_info(ChapeuRules.ROUNDS[i]).nome, 19, Tokens.TINTA, Fonts.body_bold())
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		for t in 2:
			var l := UI.label(str(scores[i][t]), 22, Tokens.TEAM_DARK[ChapeuRules.TEAMS[t]], Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
			l.custom_minimum_size.x = 64
			row.add_child(l)
		tv.add_child(row)
	_root.add_child(table)
	if session.is_host:
		_root.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, func(): session.send({"type": "rematch"}), "shuffle"))
		_root.add_child(UI.caption("Mesmos times e mesma configuração, palavras novas."))
	_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, _leave, "home"))


func _save_history() -> void:
	var res: Dictionary = v.get("result", {})
	if res.is_empty():
		return
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "chapeu",
		"game_name": "Chapéu",
		"mode": session.mode,
		"winner": res.get("winner", ""),
		"criterion": res.get("criterion", ""),
		"totals": res.get("totals", {}),
		"scores": res.get("scores", []),
		"players": v.players.map(func(p): return {"name": p.name, "team": p.team}),
	})


# --- Utilidades ------------------------------------------------------------

func _me() -> Dictionary:
	return _player(v.get("you", ""))


func _player(id: String) -> Dictionary:
	if id == "" or v.is_empty():
		return {}
	for p in v.players:
		if p.id == id:
			return p
	return {}


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
