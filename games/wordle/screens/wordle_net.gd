extends DesafioNetScreen
## Corrida do Wordle no celular (docs/PLANO_WORDLE_SENHA.md §5): a sua grade, o teclado e as
## mini-grades dos outros só com as cores.

var _typed := ""
var _keyboard: WordKeyboard


func _menu_path() -> String:
	return "res://games/wordle/screens/wordle_menu.gd"


func _game_title() -> String:
	return "Wordle"


func _icon() -> String:
	return "wordle"


func _make_board(kind: String) -> Control:
	var mini := kind == "mini"
	var g := WordGrid.new(6, {"mini": 20.0, "result": 34.0, "mine": 64.0}[kind], {"mini": 3.0, "result": 4.0, "mine": 7.0}[kind])
	g.hide_letters = mini
	if kind != "mine":
		g.custom_minimum_size.x = 110 if mini else 186
		return g
	var c := CenterContainer.new()
	g.custom_minimum_size.x = 380
	c.add_child(g)
	c.set_meta("grid", g)
	return c


func _reveal(board: Control) -> void:
	_grid(board).reveal_last()


func _grid(board: Control) -> WordGrid:
	return board.get_meta("grid") if board.has_meta("grid") else board


func _set_board(board: Control, bv: Dictionary, active: bool) -> void:
	var g := _grid(board)
	g.set_state(bv.get("guesses", []), _typed if active else "", active)


func _make_input() -> Control:
	_keyboard = WordKeyboard.new()
	_keyboard.key.connect(_on_key)
	return _keyboard


func _update_input(done: bool) -> void:
	_keyboard.disabled = done
	var rows: Array = v.me.get("guesses", []).map(func(g): return {"n": WordleWords.norm(g.w), "c": g.c})
	_keyboard.set_colors([WordleLogic.key_colors(rows)])


func _secret_widget() -> Control:
	return UI.label(str(v.secret).to_upper(), 54, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)


func _guess_result(accepted: bool) -> void:
	if accepted:
		_typed = ""
	elif is_instance_valid(_my_board):
		_grid(_my_board).shake()


func _config_lines() -> Array:
	var out := _race_lines()
	out.append("Modo difícil: %s" % ("ligado" if v.config.get("dificil", false) else "desligado"))
	return out


func _host_config(cv: VBoxContainer, cfg: Dictionary) -> void:
	super(cv, cfg)
	var row := UI.hbox(12)
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.label("Modo difícil", 20, Tokens.TINTA, Fonts.body_bold()))
	tv.add_child(UI.label("Vale pra todos: as dicas reveladas precisam ser usadas.", 15, Tokens.TINTA_SUAVE))
	row.add_child(tv)
	row.add_child(UI.toggle(cfg.get("dificil", false), func(x): session.send({"type": "set_config", "dificil": x})))
	cv.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if v.get("phase", "") != "play" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_on_key("enter")
	elif k.keycode == KEY_BACKSPACE:
		_on_key("back")
	elif k.unicode > 0 and WordleWords.norm(String.chr(k.unicode)).length() == 1:
		_on_key(WordleWords.norm(String.chr(k.unicode)))
	else:
		return
	get_viewport().set_input_as_handled()


func _on_key(k: String) -> void:
	if v.get("phase", "") != "play" or v.me.get("done", false) or _pending:
		return
	match k:
		"back":
			_typed = _typed.left(_typed.length() - 1)
		"enter":
			if _typed.length() < WordleWords.LENGTH:
				_grid(_my_board).shake()
				App.toast("Faltam letras", Tokens.VERMELHO)
				return
			_pending = true
			session.send({"type": "guess", "word": _typed, "local_us": Time.get_ticks_usec()})
			return
		_:
			if _typed.length() < WordleWords.LENGTH:
				_typed += k
	_set_board(_my_board, v.me, true)
