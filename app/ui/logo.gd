class_name Logo
extends Control
## Logo "gamehub." estática: "game" em tinta, "hub" em cobalto sobre uma fita mostarda,
## e o ponto final em vermelho. Tudo alinhado pela linha de base do texto.

var font_size := 72


func _init(p_size := 72) -> void:
	font_size = p_size
	mouse_filter = MOUSE_FILTER_IGNORE


func _parts() -> Dictionary:
	var f := Fonts.display()
	return {
		"font": f,
		"game": f.get_string_size("game", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		"hub": f.get_string_size("hub", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		"dot": f.get_string_size(".", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
	}


func _get_minimum_size() -> Vector2:
	var p := _parts()
	return Vector2(p.game + p.hub + p.dot + 24, font_size * 1.3)


func _draw() -> void:
	var p := _parts()
	var f: Font = p.font
	var total: float = p.game + p.hub + p.dot
	var x := (size.x - total) / 2.0
	var ascent := f.get_ascent(font_size)
	var descent := f.get_descent(font_size)
	var baseline := size.y / 2.0 + (ascent - descent) / 2.0 - font_size * 0.05
	var hub_x: float = x + p.game

	# Fita mostarda atrás do "hub": faixa levemente inclinada, na altura da parte de baixo das letras.
	var band_h := font_size * 0.26
	var top := baseline - band_h * 0.75
	var pad := font_size * 0.06
	var band := PackedVector2Array([
		Vector2(hub_x - pad, top + 2), Vector2(hub_x + p.hub + pad, top - 2),
		Vector2(hub_x + p.hub + pad, top - 2 + band_h), Vector2(hub_x - pad, top + 2 + band_h)])
	draw_colored_polygon(band, Tokens.MOSTARDA)

	draw_string(f, Vector2(x, baseline), "game", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.TINTA)
	draw_string(f, Vector2(hub_x, baseline), "hub", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.AZUL)
	draw_string(f, Vector2(hub_x + p.hub, baseline), ".", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.VERMELHO)
