class_name Logo
extends Control
## Logo "gamehub": letras coloridas com contorno e sombra dura, levemente inclinadas.

const COLORS := [Tokens.AZUL, Tokens.ROSA, Tokens.LIMA, Tokens.TURQUESA]

var text := "gamehub"
var font_size := 72
var _wobble := 0.0
var animate := true


func _init(p_size := 72) -> void:
	font_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	var f := Fonts.title_bold()
	return Vector2(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 1.15 + 20, font_size * 1.35)


func _process(delta: float) -> void:
	if animate:
		_wobble += delta
		queue_redraw()


func _draw() -> void:
	var f := Fonts.title_bold()
	var total := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 1.1
	var x := (size.x - total) / 2.0
	var base_y := size.y / 2.0 + (f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
	for i in text.length():
		var ch := text[i]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var bob := sin(_wobble * 2.4 + i * 0.7) * 3.0
		var rot := deg_to_rad(-6 if i % 2 == 0 else 5)
		var pos := Vector2(x + w / 2.0, base_y + bob)
		draw_set_transform(pos, rot, Vector2.ONE)
		var off := Vector2(-w / 2.0, 0)
		draw_string_outline(f, off + Vector2(0, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 14, Tokens.TINTA)
		draw_string(f, off + Vector2(0, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.TINTA)
		draw_string_outline(f, off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, Tokens.TINTA)
		draw_string(f, off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS[i % COLORS.size()])
		x += w * 1.1
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
