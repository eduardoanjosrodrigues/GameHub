class_name PegBoard
extends Control
## Tabuleiro do Senha desenhado em código (docs/PLANO_WORDLE_SENHA.md §6): uma linha por palpite, com
## o retorno ao lado (contagem) ou atrás de cada pino (por posição). A linha atual mostra o que a
## pessoa está montando; tocar num pino dela tira o pino. Com hide_symbols, só o retorno aparece
## (mini-grade dos adversários na Corrida).

signal slot_tapped(i: int)

var rows := 10
var pins := 4
var look := "cores"
var feedback_mode := "contagem"
var max_peg := 30.0
var row_gap := 8.0
## [{w: [símbolos], c: retorno}]
var guesses: Array = []
var typed: Array = []
var active := true
var hide_symbols := false
var compact := false # sem as linhas vazias depois da atual
var plain := false # só os pinos, sem número nem fundo (senha revelada)

var _shake_t0 := -100.0
var _reveal_t0 := -100.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_state(p_guesses: Array, p_typed: Array = [], p_active := true) -> void:
	guesses = p_guesses
	typed = p_typed
	active = p_active
	_resize()
	queue_redraw()


func shake() -> void:
	_shake_t0 = _now()
	queue_redraw()


func reveal_last() -> void:
	_reveal_t0 = _now()
	queue_redraw()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _visible_rows() -> int:
	if compact:
		return clampi(guesses.size() + (1 if active else 0), 1, rows)
	return rows


func _layout() -> Dictionary:
	# Largura: número da linha + pinos + retorno.
	var fb_w := 0.0 if feedback_mode == "posicao" else 2.4
	if plain:
		fb_w = 0.0
	var num := 0.0 if plain else 1.0
	var units := num + pins * 1.18 + fb_w
	var peg := minf(max_peg * 2.0, size.x / units)
	# O conteúdo fica centralizado na linha.
	var x0 := (size.x - units * peg) / 2.0
	return {"peg": peg, "num_w": peg * num, "fb_w": peg * fb_w, "row_h": peg * 1.08, "x0": x0}


func _resize() -> void:
	var l := _layout()
	var h: float = _visible_rows() * (l.row_h + row_gap) - row_gap
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size.y = h


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize()


func _process(_d: float) -> void:
	var n := _now()
	if n - _shake_t0 < 0.4 or n - _reveal_t0 < 0.35:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or not active or hide_symbols:
		return
	var l := _layout()
	var r := guesses.size()
	var y0: float = r * (l.row_h + row_gap)
	if event.position.y < y0 or event.position.y > y0 + l.row_h:
		return
	for i in pins:
		var cx: float = l.x0 + l.num_w + (i + 0.5) * l.peg * 1.18
		if absf(event.position.x - cx) < l.peg * 0.59:
			slot_tapped.emit(i)
			accept_event()
			return


func _draw() -> void:
	var l := _layout()
	var peg: float = l.peg
	var font := Fonts.body_bold()
	var now := _now()
	for r in _visible_rows():
		var y: float = r * (l.row_h + row_gap)
		var dx := 0.0
		var current := r == guesses.size() and active
		if current and now - _shake_t0 < 0.4:
			var p := (now - _shake_t0) / 0.4
			dx = sin(p * TAU * 4.0) * peg * 0.18 * (1.0 - p)
		var row_rect := Rect2(0, y, size.x, l.row_h)
		var bg := Tokens.SUPERFICIE if current else Tokens.PAPEL.lerp(Tokens.SUPERFICIE, 0.5)
		if not plain:
			var sb := StyleBoxFlat.new()
			sb.bg_color = bg
			sb.set_corner_radius_all(int(peg * 0.3))
			if current:
				sb.border_color = Tokens.TINTA
				sb.set_border_width_all(2)
			draw_style_box(sb, row_rect)
			var fs := int(peg * 0.42)
			var num := str(r + 1)
			var nsz := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, Vector2(l.x0 + l.num_w / 2.0 - nsz.x / 2.0, y + l.row_h / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.TINTA_SUAVE)
		var g: Dictionary = guesses[r] if r < guesses.size() else {}
		var pop := 1.0
		if r == guesses.size() - 1 and now - _reveal_t0 < 0.35:
			pop = 1.0 + 0.12 * sin((now - _reveal_t0) / 0.35 * PI)
		for i in pins:
			var c := Vector2(l.x0 + l.num_w + (i + 0.5) * peg * 1.18 + dx, y + l.row_h / 2.0)
			var s := -1
			if not g.is_empty():
				s = int(g.w[i]) if not hide_symbols and i < g.w.size() else -2
				if feedback_mode == "posicao" and i < g.c.size():
					var tile := StyleBoxFlat.new()
					tile.bg_color = WordGrid.tile_color(int(g.c[i]))
					tile.set_corner_radius_all(int(peg * 0.22))
					var ts := peg * 1.02 * pop
					draw_style_box(tile, Rect2(c - Vector2(ts, ts) / 2.0, Vector2(ts, ts)))
			elif current and i < typed.size():
				s = int(typed[i])
			if s == -2:
				continue # mini-grade: só o retorno
			SenhaArt.draw_peg(self, c, peg * 0.4 * (pop if not g.is_empty() else 1.0), s, look)
		if not g.is_empty() and feedback_mode == "contagem":
			var fr := Rect2(l.x0 + l.num_w + pins * peg * 1.18 + peg * 0.15, y + l.row_h * 0.08, l.fb_w - peg * 0.3, l.row_h * 0.84)
			SenhaArt.draw_count(self, fr, g.c, pins)
