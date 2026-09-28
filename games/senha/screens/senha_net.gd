extends DesafioNetScreen
## Senha pelo Wi-Fi no celular (docs/PLANO_WORDLE_SENHA.md §4.4, §4.5).
##   Corrida: a sua grade, a paleta e as mini-grades dos outros (DesafioNetScreen).
##   Duelo: cria a senha do outro; depois ataca a dele e vê ao vivo os ataques contra a sua.

var _typed: Array = []
var _palette: PegPalette
var _send_btn: AppButton
var _clear_btn: AppButton
var _opp_board: PegBoard


func _menu_path() -> String:
	return "res://games/senha/screens/senha_menu.gd"


func _game_title() -> String:
	return "Senha"


func _icon() -> String:
	return "senha"


func _duel() -> bool:
	return v.get("config", {}).get("modo", "corrida") == "duelo"


func _look() -> String:
	return str(v.config.get("aparencia", "cores"))


func _fb() -> String:
	return str(v.config.get("retorno", "contagem"))


# --- Grades e entrada ------------------------------------------------------

func _new_board(kind: String) -> PegBoard:
	var b := PegBoard.new()
	b.pins = int(v.get("pins", 4))
	b.rows = SenhaLogic.TRIES
	b.look = _look()
	b.feedback_mode = _fb()
	b.hide_symbols = kind == "mini"
	b.compact = kind != "mine"
	b.max_peg = {"mini": 9.0, "result": 16.0, "mine": 28.0}[kind]
	if kind != "mine":
		b.custom_minimum_size.x = 120 if kind == "mini" else 230
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.slot_tapped.connect(func(i):
		if i < _typed.size():
			_typed.remove_at(i)
			_refresh_input())
	return b


func _make_board(kind: String) -> Control:
	return _new_board(kind)


func _set_board(board: Control, bv: Dictionary, active: bool) -> void:
	(board as PegBoard).set_state(bv.get("guesses", []), _typed if active else [], active)


func _make_input() -> Control:
	var box := UI.vbox(12)
	_palette = PegPalette.new()
	_palette.symbols = int(v.get("symbols", 6))
	_palette.look = _look()
	_palette.picked.connect(func(s):
		if _typed.size() < int(v.pins):
			_typed.append(s)
			_refresh_input())
	box.add_child(_palette)
	var row := UI.hbox(12)
	_clear_btn = UI.button("Apagar", AppButton.Variant.SECONDARY, func():
		if not _typed.is_empty():
			_typed.pop_back()
			_refresh_input(), "back")
	row.add_child(_clear_btn)
	_send_btn = UI.button("Enviar", AppButton.Variant.SUCCESS, _submit, "check")
	row.add_child(_send_btn)
	box.add_child(row)
	return box


func _can_play() -> bool:
	if v.phase == "create":
		return not v.codes_ready.get(_me(), false)
	if v.phase != "play" or v.me.get("done", false):
		return false
	return not (_duel() and v.config.duelo == "alternado" and v.turn != _me())


func _update_input(_done: bool) -> void:
	_refresh_input(false)


func _refresh_input(redraw_board := true) -> void:
	if not is_instance_valid(_palette):
		return
	var can := _can_play()
	_palette.disabled = not can or _pending or _typed.size() >= int(v.pins)
	_palette.blocked = _typed.duplicate() if not v.get("repeat", true) else []
	_palette.queue_redraw()
	_clear_btn.disabled = not can or _typed.is_empty()
	_send_btn.disabled = not can or _pending or _typed.size() < int(v.pins)
	if redraw_board and is_instance_valid(_my_board):
		if v.phase == "create":
			(_my_board as PegBoard).set_state([], _typed, true)
		else:
			_set_board(_my_board, v.me, can)


func _submit() -> void:
	if not _can_play() or _pending:
		return
	var why := SenhaLogic.check(_typed, str(v.config.nivel))
	if why != "":
		(_my_board as PegBoard).shake()
		App.toast(why, Tokens.VERMELHO)
		return
	_pending = true
	if v.phase == "create":
		session.send({"type": "set_code", "pins": _typed.duplicate()})
		return
	session.send({"type": "guess", "pins": _typed.duplicate(), "local_us": Time.get_ticks_usec()})
	_refresh_input(false)


func _guess_result(accepted: bool) -> void:
	if accepted:
		_typed = []
	elif is_instance_valid(_my_board):
		(_my_board as PegBoard).shake()


func _secret_widget() -> Control:
	return _code_view(v.secret if v.secret != null else [], 26.0)


func _code_view(code: Array, peg: float) -> Control:
	var b := PegBoard.new()
	b.pins = int(v.get("pins", 4))
	b.rows = 1
	b.compact = true
	b.plain = true
	b.look = _look()
	b.max_peg = peg
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size.x = peg * 2.0 * b.pins * 1.18
	b.set_state([], code, true)
	var c := CenterContainer.new()
	c.add_child(b)
	return c


# --- Fases -----------------------------------------------------------------

func _live_events() -> Array:
	return super() + ["code_set"]


func _live_update(events: Array) -> bool:
	if v.phase == "create" and is_instance_valid(_my_board):
		for e in events:
			if e.get("type", "") == "code_set" and e.id == _me():
				_pending = false
		_rebuild()
		return true
	if not _duel():
		return super(events)
	if v.phase != "play" or not is_instance_valid(_my_board):
		return false
	_update_duel(events)
	return true


func _before_rebuild(events: Array) -> void:
	super(events)
	for e in events:
		if e.get("type", "") == "started":
			_typed = []


func _build_phase() -> void:
	if v.phase == "create":
		_build_create()
	elif _duel() and v.phase == "play":
		_build_duel()
	elif _duel() and v.phase == "game_over":
		_build_duel_end()
	else:
		super()


func _build_create() -> void:
	_header("Duelo")
	var opp := _name(str(v.opponent))
	var ready: bool = v.codes_ready.get(_me(), false)
	if ready:
		_root.add_child(_big("Senha criada!", Tokens.tint(Tokens.SALVIA, 0.3), "Esperando %s criar a senha pra você..." % opp))
		_root.add_child(UI.label("A sua senha:", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(_code_view(v.my_code, 26.0))
		_my_board = null
		return
	_root.add_child(_big("Crie a senha de %s" % opp, Tokens.MOSTARDA, "%s vai tentar quebrar. Não deixe ninguém ver!" % opp))
	var lv := SenhaLogic.level(str(v.config.nivel))
	_root.add_child(UI.caption("%d pinos · %d símbolos · %s" % [lv.pins, lv.symbols, "pode repetir" if lv.repeat else "sem repetir"]))
	var b := _new_board("mine")
	b.rows = 1
	b.compact = true
	_my_board = b
	_root.add_child(b)
	_root.add_child(_make_input())
	_send_btn.text = "Pronto"
	b.set_state([], _typed, true)
	_refresh_input(false)
	if v.codes_ready.get(str(v.opponent), false):
		_root.add_child(UI.caption("%s já criou a sua." % opp))


func _turn_text() -> String:
	if v.config.duelo != "alternado":
		return "Os dois ao mesmo tempo: quebre primeiro!"
	if v.turn == _me():
		return "Sua vez!"
	return "Vez de %s..." % _name(str(v.turn))


func _build_duel() -> void:
	_header("Duelo")
	_timer_row()
	_status = UI.label(_turn_text(), 24, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_status)
	var opp := _name(str(v.opponent))
	_root.add_child(UI.label("Você quebrando a senha de %s" % opp, 17, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_my_board = _new_board("mine")
	_root.add_child(_my_board)
	_root.add_child(_make_input())
	var c := UI.card(Tokens.PAPEL, 18)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("%s atacando a sua senha" % opp, 17, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(_code_view(v.my_code, 16.0))
	_opp_board = _new_board("result")
	var cc := CenterContainer.new()
	cc.add_child(_opp_board)
	cv.add_child(cc)
	_root.add_child(c)
	_update_duel([])


func _update_duel(events: Array) -> void:
	for e in events:
		if e.get("id", "") != _me():
			continue
		match e.type:
			"rejected":
				_pending = false
				_guess_result(false)
				App.toast(e.msg, Tokens.VERMELHO)
			"guess":
				_pending = false
				_guess_result(true)
				(_my_board as PegBoard).reveal_last()
				Audio.sfx("pop")
	for e in events:
		if e.get("type", "") == "turn" and e.id == _me():
			Haptics.tap()
			Audio.sfx("tap")
	_status.text = _turn_text()
	if v.me.get("solved", false):
		_status.text = "Quebrou! " + ("Última chance de %s..." % _name(str(v.opponent)) if v.config.duelo == "alternado" else "")
	_set_board(_my_board, v.me, _can_play())
	_opp_board.set_state(v.opp_board.get("guesses", []), [], false)
	_refresh_input(false)


func _build_duel_end() -> void:
	_header("Fim do duelo")
	var w := str(v.winner)
	var title := "Empate!" if w == "" else ("Você venceu!" if w == _me() else "%s venceu!" % _name(w))
	var sub := "Tempo esgotado." if v.get("time_up", false) else ""
	_root.add_child(_big(title, Tokens.tint(Tokens.SALVIA, 0.35) if w == _me() or w == "" else Tokens.tint(Tokens.VERMELHO, 0.2), sub))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	for p in v.players:
		var box := UI.vbox(6)
		var bv: Dictionary = v.boards.get(p.id, {})
		box.add_child(UI.label("%s: %s" % [p.name, "quebrou em %d" % bv.guesses.size() if bv.get("solved", false) else "não quebrou"], 17, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		var target_owner := ""
		for q in v.players:
			if q.id != p.id:
				target_owner = q.id
		box.add_child(UI.label("Senha de %s:" % _name(target_owner), 15, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(_code_view(v.codes.get(target_owner, []), 14.0))
		var b := _new_board("result")
		box.add_child(b)
		b.set_state(bv.get("guesses", []), [], false)
		flow.add_child(box)
	_root.add_child(flow)
	_end_buttons("Os dois criam senhas novas.")


func _config_lines() -> Array:
	var cfg: Dictionary = v.config
	var lv := SenhaLogic.level(str(cfg.nivel))
	var out: Array = ["Modo: %s" % (SenhaNetRules.MODES[cfg.modo] + (" · " + SenhaNetRules.DUEL_TYPES[cfg.duelo] if cfg.modo == "duelo" else ""))]
	out.append("Nível: %s · retorno %s · %s" % [lv.name, "por contagem" if cfg.retorno == "contagem" else "por posição", SenhaLogic.LOOKS[cfg.aparencia].to_lower()])
	if cfg.modo == "duelo":
		out.append("Tempo: %s" % ("sem limite" if int(cfg.tempo_min) == 0 else "%d min" % cfg.tempo_min))
	else:
		out.append_array(_race_lines())
	return out


func _host_config(cv: VBoxContainer, cfg: Dictionary) -> void:
	cv.add_child(UI.setting_block("Modo", UI.segmented([["corrida", "Corrida"], ["duelo", "Duelo"]], cfg.modo, func(k): session.send({"type": "set_config", "modo": k})),
		"Duelo: 2 jogadores, cada um cria a senha do outro." if cfg.modo == "duelo" else "Todos tentam a mesma senha sorteada."))
	if cfg.modo == "duelo":
		cv.add_child(UI.setting_block("Duelo", UI.segmented([["alternado", "Alternado"], ["tempo", "Modo tempo"]], cfg.duelo, func(k): session.send({"type": "set_config", "duelo": k})),
			"Um palpite por vez; se quem começou acertar, o outro tem a última chance." if cfg.duelo == "alternado" else "Os dois ao mesmo tempo: vence quem quebrar primeiro."))
	cv.add_child(UI.setting_block("Nível", UI.segmented(SenhaLogic.LEVEL_ORDER.map(func(k): return [k, SenhaLogic.LEVELS[k].name]), cfg.nivel, func(k): session.send({"type": "set_config", "nivel": k}))))
	cv.add_child(UI.setting_block("Retorno", UI.segmented([["contagem", "Contagem"], ["posicao", "Por posição"]], cfg.retorno, func(k): session.send({"type": "set_config", "retorno": k}))))
	cv.add_child(UI.setting_block("Aparência", UI.segmented([["cores", "Cores"], ["numeros", "Números"]], cfg.aparencia, func(k): session.send({"type": "set_config", "aparencia": k}))))
	if cfg.modo == "duelo":
		cv.add_child(_time_block(cfg))
	else:
		super(cv, cfg)


func _save_history() -> void:
	if not _duel():
		super()
		return
	var w := str(v.winner)
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "senha",
		"game_name": "Senha",
		"mode": "wifi",
		"summary": "Duelo: empate" if w == "" else "Duelo: venceu %s" % _name(w),
		"players": v.players.map(func(p): return {"name": p.name}),
	})
