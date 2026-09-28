extends Screen
## Partida solo do Wordle (docs/PLANO_WORDLE_SENHA.md §3.2): palavra do dia, treino, Dueto ou
## Quarteto. Cada palpite vale pra todas as grades que ainda não foram resolvidas. A partida fica
## salva: saindo no meio, continua de onde parou.

const WIN_WORDS := ["Genial!", "Magnífico!", "Impressionante!", "Muito bom!", "Boa!", "Ufa!"]

var mode := "treino"
var boards := 1
var tries := 6
var answers: Array = [] # sem acento
var guesses: Array = [] # sem acento
var hard := false
var day := -1
var finished := false
var won := false
var typed := ""

var _grids: Array = []
var _keyboard: WordKeyboard
var _bottom: VBoxContainer
var _clock: Label
var _busy := false # revelando: espera a animação antes de aceitar outro palpite
var _boards_box: Control
var _rng := RandomNumberGenerator.new()


func _init(p_mode: String) -> void:
	super()
	mode = p_mode
	music = ""
	var m: Dictionary = WordleLogic.MODES[mode]
	boards = m.boards
	tries = m.tries
	_rng.randomize()


func _key() -> String:
	return "wordle_" + mode


func _ready() -> void:
	_load_or_new()
	_build()


func _load_or_new() -> void:
	var today := Desafio.day_index()
	var g := DesafioStore.today_game(_key(), today) if mode == "dia" else DesafioStore.load_game(_key())
	if not g.is_empty() and not (mode != "dia" and g.get("finished", false)):
		answers = g.get("answers", [])
		guesses = g.get("guesses", [])
		hard = g.get("hard", false)
		day = int(g.get("day", -1))
		finished = g.get("finished", false)
		won = g.get("won", false)
		# O modo difícil só muda antes do 1º palpite (§3.3).
		if guesses.is_empty():
			hard = DesafioStore.pref("wordle_dificil", false)
		if answers.size() == boards and answers.all(func(a): return WordleWords.is_valid(a)):
			return
	day = today if mode == "dia" else -1
	if mode == "dia":
		answers = [WordleWords.norm(WordleWords.daily(today))]
	else:
		answers = WordleWords.random_training(_rng, today, boards).map(func(w): return WordleWords.norm(w))
	guesses = []
	hard = DesafioStore.pref("wordle_dificil", false)
	finished = false
	won = false
	_save()


func _save() -> void:
	DesafioStore.save_game(_key(), {"day": day, "answers": answers, "guesses": guesses, "hard": hard, "finished": finished, "won": won})


func _title() -> String:
	return {"dia": "Palavra do dia", "treino": "Treino", "dueto": "Dueto", "quarteto": "Quarteto"}[mode]


# --- Tela ------------------------------------------------------------------

func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var mw := MaxWidth.new()
	mw.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mw)
	var m := UI.margin(16, 16, 20)
	mw.add_child(m)
	var col := UI.vbox(12)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(col)
	var head := UI.hbox(12)
	head.add_child(UI.icon_button("back", func(): App.back()))
	var t := UI.title(_title() + (" · difícil" if hard else ""), 30, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	head.add_child(UI.icon_button("trophy", func(): App.push(load("res://games/wordle/screens/wordle_menu.gd").stats_screen())))
	col.add_child(head)
	_boards_box = _make_boards()
	_boards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_boards_box)
	_bottom = UI.vbox(12)
	col.add_child(_bottom)
	_keyboard = WordKeyboard.new()
	_keyboard.key.connect(_on_key)
	_refresh()
	resized.connect(_fit)
	_fit.call_deferred()


func _make_boards() -> Control:
	_grids = []
	for i in boards:
		var g := WordGrid.new(tries, 76.0, 8.0 if boards == 1 else 5.0)
		_grids.append(g)
	if boards == 1:
		var c := CenterContainer.new()
		c.add_child(_grids[0])
		_grids[0].custom_minimum_size.x = 420
		return c
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	for g in _grids:
		grid.add_child(g)
	var c := CenterContainer.new()
	c.add_child(grid)
	return c


## Tamanho das peças: cabe na largura e na altura que sobra sem rolar.
func _fit() -> void:
	if _grids.is_empty():
		return
	var avail_h := size.y - 16 - 20 - 64 - 12 * 3 - _bottom.get_combined_minimum_size().y
	var avail_w := minf(size.x, Tokens.CONTENT_MAX_WIDTH) - (32 if boards == 1 else 64)
	var grid_rows := 1 if boards <= 2 else 2
	var grid_cols := 1 if boards == 1 else 2
	var g0: WordGrid = _grids[0]
	var tile_h := (avail_h / grid_rows - 14 * (grid_rows - 1) - g0.gap * (tries - 1)) / tries
	var tile_w := ((avail_w - 18 * (grid_cols - 1)) / grid_cols - g0.gap * 4) / 5
	var t := clampf(minf(tile_h, tile_w), 18.0, 76.0)
	for g in _grids:
		g.max_tile = t
		g.custom_minimum_size.x = t * 5 + g.gap * 4
		g.custom_minimum_size.y = t * tries + g.gap * (tries - 1)
		g.queue_redraw()


func _process(_d: float) -> void:
	if _clock and is_instance_valid(_clock):
		_clock.text = "Próxima palavra em %s" % Desafio.mmss(Desafio.seconds_to_midnight())


## Onde cada grade foi resolvida (índice do palpite) ou -1.
func _solved_at(i: int) -> int:
	for k in guesses.size():
		if guesses[k] == answers[i]:
			return k
	return -1


func _board_rows(i: int) -> Array:
	var upto := _solved_at(i)
	var out: Array = []
	for k in guesses.size():
		if upto >= 0 and k > upto:
			break
		out.append({"w": WordleWords.display(guesses[k]), "n": guesses[k], "c": WordleLogic.score(guesses[k], answers[i])})
	return out


func _refresh() -> void:
	var colors: Array = []
	for i in boards:
		var rows := _board_rows(i)
		var done := _solved_at(i) >= 0
		var g: WordGrid = _grids[i]
		g.dim = done and boards > 1 and not finished
		g.set_state(rows, typed if not done and not finished else "", not done and not finished)
		colors.append(null if done and boards > 1 else WordleLogic.key_colors(rows))
	_keyboard.set_colors(colors)
	_build_bottom()


func _build_bottom() -> void:
	_clock = null
	for ch in _bottom.get_children():
		_bottom.remove_child(ch)
		if ch != _keyboard:
			ch.queue_free()
	if not finished:
		_bottom.add_child(_keyboard)
		return
	var c := UI.card(Tokens.tint(Tokens.SALVIA, 0.3) if won else Tokens.tint(Tokens.VERMELHO, 0.2), 20)
	var v := UI.vbox(10)
	c.add_child(v)
	if won:
		v.add_child(UI.title(WIN_WORDS[mini(guesses.size() - 1 - (tries - 6), WIN_WORDS.size() - 1)] if boards == 1 else "Resolveu todas!", 34))
		v.add_child(UI.label("Em %d de %d tentativas." % [guesses.size(), tries], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UI.title("Não foi dessa vez", 32))
		var missed: Array = []
		for i in boards:
			if _solved_at(i) < 0:
				missed.append(WordleWords.display(answers[i]).to_upper())
		v.add_child(UI.label(("A palavra era %s." if missed.size() == 1 else "Faltaram: %s.") % ", ".join(missed), 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	if mode == "dia":
		var st := DesafioStore.stats("wordle_dia", Desafio.day_index())
		v.add_child(UI.label("Sequência: %d · melhor: %d" % [st.streak, st.best], 17, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_clock = UI.label("", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(_clock)
	_bottom.add_child(c)
	var row := UI.hbox(12)
	if mode != "dia":
		var again := UI.button("Jogar de novo", AppButton.Variant.SUCCESS, _again, "shuffle")
		row.add_child(again)
	var st_b := UI.button("Estatísticas", AppButton.Variant.SECONDARY, func(): App.push(load("res://games/wordle/screens/wordle_menu.gd").stats_screen()), "trophy")
	row.add_child(st_b)
	_bottom.add_child(row)
	_fit.call_deferred()


func _again() -> void:
	DesafioStore.clear_game(_key())
	typed = ""
	_load_or_new()
	_build()


# --- Digitação -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or not is_visible_in_tree():
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_on_key("enter")
	elif k.keycode == KEY_BACKSPACE:
		_on_key("back")
	elif k.unicode > 0:
		var ch := WordleWords.norm(String.chr(k.unicode))
		if ch.length() == 1:
			_on_key(ch)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _on_key(k: String) -> void:
	if finished or _busy:
		return
	match k:
		"back":
			typed = typed.left(typed.length() - 1)
		"enter":
			_submit()
			return
		_:
			if typed.length() < WordleWords.LENGTH:
				typed += k
	_refresh_typing()


func _refresh_typing() -> void:
	for i in boards:
		var g: WordGrid = _grids[i]
		if _solved_at(i) < 0:
			g.set_state(g.guesses, typed, true)


func _reject(msg: String) -> void:
	for i in boards:
		if _solved_at(i) < 0:
			_grids[i].shake()
	Haptics.skip()
	App.toast(msg, Tokens.VERMELHO)


func _submit() -> void:
	if typed.length() < WordleWords.LENGTH:
		_reject("Faltam letras")
		return
	if not WordleWords.is_valid(typed):
		_reject("Palavra não aceita")
		return
	if hard:
		# No Dueto/Quarteto, o modo difícil segue as dicas da primeira grade ainda aberta.
		for i in boards:
			if _solved_at(i) < 0:
				var why := WordleLogic.hard_violation(typed, _board_rows(i))
				if why != "":
					_reject(why)
					return
				break
	guesses.append(typed)
	typed = ""
	var all_solved := true
	for i in boards:
		all_solved = all_solved and _solved_at(i) >= 0
	var out := guesses.size() >= tries
	if all_solved or out:
		finished = true
		won = all_solved
		DesafioStore.record(_key(), won, guesses.size(), day)
	_save()
	# Revela a linha nova em cada grade que recebeu o palpite.
	var reveal_grids: Array = []
	for i in boards:
		var s := _solved_at(i)
		if s < 0 or s == guesses.size() - 1:
			reveal_grids.append(i)
	var keep_finished := finished
	finished = false # mostra o teclado até a animação acabar
	for i in boards:
		var rows := _board_rows(i)
		var g: WordGrid = _grids[i]
		g.set_state(rows, "", false)
		if i in reveal_grids:
			g.reveal_last()
	Audio.sfx("pop")
	_busy = true
	var wait: float = (_grids[0] as WordGrid).reveal_seconds()
	get_tree().create_timer(wait).timeout.connect(func():
		_busy = false
		finished = keep_finished
		_refresh()
		if finished:
			if won:
				Audio.sfx("win")
				Haptics.hit()
			else:
				Audio.sfx("buzzer"))
