class_name Logo
extends Control
## Logo "gamehub": palavra serifada em tinta com um ponto mostarda no lugar do pingo,
## e um sublinhado de papel levemente torto.

var font_size := 72
var animate := true
var _t := 0.0


func _init(p_size := 72) -> void:
	font_size = p_size
	mouse_filter = MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	var f := Fonts.title_italic()
	return Vector2(f.get_string_size("gamehub", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40, font_size * 1.4)


func _process(delta: float) -> void:
	if animate:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var f := Fonts.title_italic()
	var w_game := f.get_string_size("game", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w_hub := f.get_string_size("hub", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total := w_game + w_hub
	var x := (size.x - total) / 2.0
	var base_y := size.y / 2.0 + (f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0 - font_size * 0.08
	draw_string(f, Vector2(x, base_y), "game", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.TINTA)
	draw_string(f, Vector2(x + w_game, base_y), "hub", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.AZUL)
	# Faixa mostarda sob "hub", como uma fita adesiva.
	var bob := sin(_t * 1.6) * 1.5
	var band_y := base_y + font_size * 0.14 + bob
	var pts := PackedVector2Array([
		Vector2(x + w_game - 4, band_y), Vector2(x + total + 6, band_y - 4),
		Vector2(x + total + 8, band_y + font_size * 0.12 - 4), Vector2(x + w_game - 2, band_y + font_size * 0.12)])
	draw_colored_polygon(pts, Tokens.MOSTARDA)
	# Ponto final vermelho.
	draw_circle(Vector2(x + total + font_size * 0.2, base_y - font_size * 0.06), font_size * 0.085, Tokens.VERMELHO, true, -1.0, true)
