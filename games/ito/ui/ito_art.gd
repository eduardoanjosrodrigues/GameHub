class_name ItoArt
extends RefCounted
## Desenho do Ito (docs/PLANO_SINTONIA_ITO.md §9): cartas numeradas, o fio vermelho que liga a fila
## ("ito" é fio em japonês) e os corações das vidas.

const FIO := Color("#C8392B")
const CARTA := Color("#FFFCF6")
const VERSO := Color("#2B2A33")


## Carta da mão: o número grande. n < 0 = virada (número escondido).
static func number_card(n: int, w := 120.0, accent := FIO) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := ThemeBuilder.card_style(CARTA if n >= 0 else VERSO, 18)
	s.border_color = accent
	s.set_border_width_all(4)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(w, w * 1.3)
	var l := UI.label(str(n) if n >= 0 else "?", int(w * 0.46), Tokens.TINTA if n >= 0 else Tokens.SUPERFICIE, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


## Coluna com o fio vermelho descendo pela esquerda, ligando as cartas da fila.
class ThreadLine:
	extends VBoxContainer

	var x := 26.0

	func _draw() -> void:
		if get_child_count() < 2:
			return
		draw_line(Vector2(x, 12), Vector2(x, size.y - 12), ItoArt.FIO, 4.0, true)
		for c in get_children():
			if c is Control and c.get_meta("knot", false):
				var y: float = (c as Control).position.y + (c as Control).size.y / 2.0
				draw_circle(Vector2(x, y), 8.0, ItoArt.FIO)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			queue_redraw()


## Vidas: corações cheios e vazios.
class Hearts:
	extends Control

	var lives := 3
	var total := 3
	var side := 30.0

	func _init(p_lives: int, p_total: int, p_side := 30.0) -> void:
		lives = p_lives
		total = p_total
		side = p_side
		custom_minimum_size = Vector2(p_total * (p_side + 8), p_side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			_heart(Vector2(i * (side + 8) + side / 2.0, side / 2.0), side, i < lives)

	func _heart(c: Vector2, s: float, full: bool) -> void:
		var pts := PackedVector2Array()
		for k in 48:
			var t := TAU * k / 48.0
			# Curva do coração, escalada pra caber em s x s.
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			pts.append(c + Vector2(x, y + 1.5) * (s / 36.0))
		if full:
			draw_colored_polygon(pts, ItoArt.FIO)
		pts.append(pts[0])
		draw_polyline(pts, ItoArt.FIO if full else Tokens.TEXTO_DESABILITADO, 2.5, true)
