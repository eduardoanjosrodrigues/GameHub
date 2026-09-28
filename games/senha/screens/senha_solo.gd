extends Screen
## Partida solo do Senha (docs/PLANO_WORDLE_SENHA.md §4.3): senha do dia de um nível, ou treino.
## O retorno e a aparência são escolha do jogador (no menu); como a senha é a mesma, mudar não
## afeta a sequência. A partida fica salva: saindo no meio, continua de onde parou.

var mode := "treino" # "dia" ou "treino"
var level := "medio"
var code: Array = []
var guesses: Array = [] # [[símbolos]]
var day := -1
var finished := false
var won := false
var typed: Array = []
var feedback_mode := "contagem"
var look := "cores"

var _board: PegBoard
var _palette: PegPalette
var _bottom: VBoxContainer
var _clock: Label
var _rng := RandomNumberGenerator.new()


func _init(p_mode: String, p_level: String) -> void:
	super()
	mode = p_mode
	level = p_level
	music = ""
	_rng.randomize()
	feedback_mode = DesafioStore.pref("senha_retorno", "contagem")
	look = DesafioStore.pref("senha_aparencia", "cores")


func _key() -> String:
	return "senha_%s_%s" % [mode, level]


func _lv() -> Dictionary:
	return SenhaLogic.level(level)


func _ready() -> void:
	_load_or_new()
	_build()


func _load_or_new() -> void:
	var today := Desafio.day_index()
	var g := DesafioStore.today_game(_key(), today) if mode == "dia" else DesafioStore.load_game(_key())
	if not g.is_empty() and not (mode == "treino" and g.get("finished", false)):
		code = SenhaLogic.ints(g.get("code", []))
		guesses = g.get("guesses", []).map(func(x): return SenhaLogic.ints(x))
		day = int(g.get("day", -1))
		finished = g.get("finished", false)
		won = g.get("won", false)
		if SenhaLogic.check(code, level) == "":
			return
	day = today if mode == "dia" else -1
	code = SenhaLogic.daily_code(today, level) if mode == "dia" else SenhaLogic.random_code(level, _rng)
	guesses = []
	finished = false
	won = false
	_save()


func _save() -> void:
	DesafioStore.save_game(_key(), {"day": day, "code": code, "guesses": guesses, "finished": finished, "won": won})


func _rows() -> Array:
	return guesses.map(func(g): return {"w": g, "c": SenhaLogic.feedback(g, code, feedback_mode)})


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var mw := MaxWidth.new()
	mw.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mw)
	var sc := UI.scroll()
	mw.add_child(sc)
	var m := UI.margin(16, 16, 24)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(m)
	var col := UI.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(col)
	var head := UI.hbox(12)
	head.add_child(UI.icon_button("back", func(): App.back()))
	var title := ("Senha do dia · " if mode == "dia" else "Treino · ") + str(_lv().name)
	var t := UI.title(title, 28, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	head.add_child(UI.icon_button("trophy", func(): App.push(load("res://games/senha/screens/senha_menu.gd").stats_screen())))
	col.add_child(head)
	var lv := _lv()
	col.add_child(UI.caption("%d pinos · %d símbolos · %s · retorno %s" % [lv.pins, lv.symbols, "pode repetir" if lv.repeat else "sem repetir", "por contagem" if feedback_mode == "contagem" else "por posição"]))
	_board = PegBoard.new()
	_board.pins = lv.pins
	_board.rows = SenhaLogic.TRIES
	_board.look = look
	_board.feedback_mode = feedback_mode
	_board.slot_tapped.connect(_on_slot)
	col.add_child(_board)
	_bottom = UI.vbox(12)
	col.add_child(_bottom)
	_palette = PegPalette.new()
	_palette.symbols = lv.symbols
	_palette.look = look
	_palette.picked.connect(_on_pick)
	_refresh()


func _process(_d: float) -> void:
	if _clock and is_instance_valid(_clock):
		_clock.text = "Próxima senha em %s" % Desafio.mmss(Desafio.seconds_to_midnight())


func _refresh() -> void:
	_board.set_state(_rows(), typed, not finished)
	_palette.blocked = typed.duplicate() if not _lv().repeat else []
	_palette.disabled = finished or typed.size() >= int(_lv().pins)
	_palette.queue_redraw()
	_build_bottom()


func _build_bottom() -> void:
	_clock = null
	for ch in _bottom.get_children():
		_bottom.remove_child(ch)
		if ch != _palette:
			ch.queue_free()
	if not finished:
		_bottom.add_child(_palette)
		var row := UI.hbox(12)
		var clear := UI.button("Apagar", AppButton.Variant.SECONDARY, func():
			if not typed.is_empty():
				typed.pop_back()
				_refresh(), "back")
		clear.disabled = typed.is_empty()
		row.add_child(clear)
		var send := UI.button("Enviar", AppButton.Variant.SUCCESS, _submit, "check")
		send.disabled = typed.size() < int(_lv().pins)
		row.add_child(send)
		_bottom.add_child(row)
		_bottom.add_child(UI.caption("Toque num pino da linha pra tirar."))
		return
	var c := UI.card(Tokens.tint(Tokens.SALVIA, 0.3) if won else Tokens.tint(Tokens.VERMELHO, 0.2), 20)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.title("Quebrou a senha!" if won else "Não foi dessa vez", 32))
	if won:
		v.add_child(UI.label("Em %d de %d tentativas." % [guesses.size(), SenhaLogic.TRIES], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UI.label("A senha era:", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		var reveal := PegBoard.new()
		reveal.pins = _lv().pins
		reveal.rows = 1
		reveal.look = look
		reveal.compact = true
		reveal.plain = true
		reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reveal.set_state([], code, true)
		v.add_child(reveal)
	if mode == "dia":
		var st := DesafioStore.stats(_key(), Desafio.day_index())
		v.add_child(UI.label("Sequência: %d · melhor: %d" % [st.streak, st.best], 17, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_clock = UI.label("", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(_clock)
	_bottom.add_child(c)
	var row := UI.hbox(12)
	if mode == "treino":
		row.add_child(UI.button("Jogar de novo", AppButton.Variant.SUCCESS, _again, "shuffle"))
	row.add_child(UI.button("Estatísticas", AppButton.Variant.SECONDARY, func(): App.push(load("res://games/senha/screens/senha_menu.gd").stats_screen()), "trophy"))
	_bottom.add_child(row)


func _again() -> void:
	DesafioStore.clear_game(_key())
	typed = []
	_load_or_new()
	_build()


func _on_pick(s: int) -> void:
	if finished or typed.size() >= int(_lv().pins):
		return
	typed.append(s)
	_refresh()


func _on_slot(i: int) -> void:
	if i < typed.size():
		typed.remove_at(i)
		Haptics.tap()
		_refresh()


func _submit() -> void:
	var why := SenhaLogic.check(typed, level)
	if why != "":
		_board.shake()
		App.toast(why, Tokens.VERMELHO)
		return
	guesses.append(typed.duplicate())
	typed = []
	var fb := SenhaLogic.feedback(guesses.back(), code, feedback_mode)
	if SenhaLogic.solved(fb, feedback_mode, int(_lv().pins)):
		finished = true
		won = true
	elif guesses.size() >= SenhaLogic.TRIES:
		finished = true
	if finished:
		DesafioStore.record(_key(), won, guesses.size(), day)
	_save()
	_refresh()
	_board.reveal_last()
	Audio.sfx("pop")
	if finished:
		if won:
			Audio.sfx("win")
			Haptics.hit()
		else:
			Audio.sfx("buzzer")
