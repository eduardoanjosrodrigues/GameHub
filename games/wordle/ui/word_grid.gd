class_name WordGrid
extends Control
## Grade do Wordle desenhada em código (docs/PLANO_WORDLE_SENHA.md §6): as letras viram uma por
## uma ao revelar, e a linha treme quando o palpite é recusado. Com hide_letters, só as cores
## aparecem (mini-grade dos adversários na Corrida).

const FLIP_S := 0.34
const STAGGER_S := 0.2
const SHAKE_S := 0.4
const POP_S := 0.12

var rows := 6
var cols := 5
var max_tile := 76.0
var gap := 8.0
## [{w: palavra como aparece (ou ""), c: [cores]}]
var guesses: Array = []
var typed := ""
var active := true
var hide_letters := false
var dim := false # grade resolvida no Dueto/Quarteto

var _reveal_row := -1
var _reveal_t0 := -100.0
var _shake_t0 := -100.0
var _pop_i := -1
var _pop_t0 := -100.0


static func tile_color(c: int) -> Color:
	match c:
		Desafio.GREEN:
			return Tokens.SALVIA
		Desafio.YELLOW:
			return Tokens.MOSTARDA
	return Tokens.TINTA_SUAVE


static func text_color(c: int) -> Color:
	return Tokens.TINTA if c == Desafio.YELLOW else Tokens.SUPERFICIE


func _init(p_rows := 6, p_max_tile := 76.0, p_gap := 8.0) -> void:
	rows = p_rows
	max_tile = p_max_tile
	gap = p_gap
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_state(p_guesses: Array, p_typed := "", p_active := true) -> void:
	if p_typed.length() > typed.length():
		_pop_i = p_typed.length() - 1
		_pop_t0 = _now()
	guesses = p_guesses
	typed = p_typed
	active = p_active
	queue_redraw()


## Anima a última linha revelada.
func reveal_last() -> void:
	_reveal_row = guesses.size() - 1
	_reveal_t0 = _now()
	queue_redraw()


func reveal_seconds() -> float:
	return FLIP_S + STAGGER_S * (cols - 1)


func shake() -> void:
	_shake_t0 = _now()
	queue_redraw()


func tile() -> float:
	return clampf((size.x - gap * (cols - 1)) / cols, 8.0, max_tile)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var t := tile()
		var h := rows * t + gap * (rows - 1)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_d: float) -> void:
	var n := _now()
	if n - _reveal_t0 < reveal_seconds() + 0.05 or n - _shake_t0 < SHAKE_S or n - _pop_t0 < POP_S:
		queue_redraw()


func _draw() -> void:
	var t := tile()
	var total := cols * t + gap * (cols - 1)
	var x0 := (size.x - total) / 2.0
	var now := _now()
	var font := Fonts.title_bold()
	var fs := int(t * 0.56)
	var radius := int(maxf(3.0, t * 0.14))
	for r in rows:
		var dx := 0.0
		if r == guesses.size() and now - _shake_t0 < SHAKE_S:
			var p := (now - _shake_t0) / SHAKE_S
			dx = sin(p * TAU * 4.0) * t * 0.14 * (1.0 - p)
		for c in cols:
			var rect := Rect2(x0 + c * (t + gap) + dx, r * (t + gap), t, t)
			var letter := ""
			var bg := Tokens.SUPERFICIE
			var border := Tokens.LINHA
			var fg := Tokens.TINTA
			var scale_y := 1.0
			var scale := 1.0
			if r < guesses.size():
				var g: Dictionary = guesses[r]
				var col: int = int(g.c[c]) if c < g.c.size() else 0
				var w: String = str(g.get("w", ""))
				letter = w[c].to_upper() if not hide_letters and c < w.length() else ""
				var revealed := true
				if r == _reveal_row:
					var p := (now - _reveal_t0 - c * STAGGER_S) / FLIP_S
					if p < 1.0:
						scale_y = absf(1.0 - 2.0 * clampf(p, 0.0, 1.0))
						revealed = p >= 0.5
				if revealed:
					bg = tile_color(col)
					border = bg
					fg = text_color(col)
				else:
					border = Tokens.TINTA_SUAVE
			elif r == guesses.size() and active and not hide_letters:
				if c < typed.length():
					letter = typed[c].to_upper()
					border = Tokens.TINTA
					if c == _pop_i and now - _pop_t0 < POP_S:
						scale = 1.0 + 0.1 * sin((now - _pop_t0) / POP_S * PI)
			if dim:
				bg = bg.lerp(Tokens.PAPEL, 0.55)
				border = border.lerp(Tokens.PAPEL, 0.55)
			var center := rect.get_center()
			draw_set_transform(center, 0.0, Vector2(scale, scale * maxf(scale_y, 0.02)))
			var local := Rect2(-rect.size / 2.0, rect.size)
			var sb := StyleBoxFlat.new()
			sb.bg_color = bg
			sb.border_color = border
			sb.set_border_width_all(0 if bg != Tokens.SUPERFICIE else maxi(2, int(t * 0.04)))
			sb.set_corner_radius_all(radius)
			draw_style_box(sb, local)
			if letter != "":
				var ssz := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				var base := Vector2(-ssz.x / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
				draw_string(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg.lerp(Tokens.PAPEL, 0.55) if dim else fg)
			draw_set_transform(Vector2.ZERO)
