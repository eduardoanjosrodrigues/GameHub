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
	s.bg_color = CARTA if n >= 0 else VERSO # card_style clareia cores fora do papel
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


## Monte da revelação: as cartas da fila que ainda não foram viradas, de costas. Quem pode virar
## (o host) toca nele; aí o monte pulsa de leve pra chamar o toque.
class CardStack:
	extends Control

	signal tapped

	var count := 0
	var w := 180.0
	var active := false
	var _t := 0.0
	var _down := false
	var _cancelled := false
	var _press := Vector2.ZERO
	var _back: StyleBoxFlat
	var _glow: StyleBoxFlat

	func _init(p_count: int, p_w: float, p_active: bool) -> void:
		count = p_count
		w = p_w
		active = p_active and p_count > 0
		custom_minimum_size = Vector2(w + 14, w * 1.3 + 14)
		mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
		_back = ThemeBuilder.card_style(ItoArt.VERSO, 18)
		_back.bg_color = ItoArt.VERSO
		_back.border_color = ItoArt.CARTA
		_back.set_border_width_all(4)
		_glow = StyleBoxFlat.new()
		_glow.bg_color = Color.TRANSPARENT
		_glow.border_color = Tokens.MOSTARDA
		_glow.set_border_width_all(5)
		_glow.set_corner_radius_all(22)
		set_process(active)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var sz := Vector2(w, w * 1.3)
		if count <= 0:
			var e := StyleBoxFlat.new()
			e.bg_color = Color.TRANSPARENT
			e.border_color = Tokens.LINHA
			e.set_border_width_all(3)
			e.set_corner_radius_all(18)
			draw_style_box(e, Rect2(Vector2.ZERO, sz))
			return
		# As de baixo aparecem pela borda, como um monte de verdade.
		for i in range(mini(count, 4) - 1, 0, -1):
			draw_style_box(_back, Rect2(Vector2(i * 4.5, i * 4.5), sz))
		var lift := (-5.0 - 4.0 * sin(_t * 4.0)) if active and not _down else 0.0
		var top := Rect2(Vector2(0, lift), sz)
		draw_style_box(_back, top)
		var f := Fonts.title_bold()
		var fs := int(w * 0.46)
		var txt := "?"
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, top.get_center() + Vector2(-tw / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ItoArt.CARTA)
		if active:
			_glow.border_color = Color(Tokens.MOSTARDA, 0.55 + 0.45 * sin(_t * 4.0))
			draw_style_box(_glow, top.grow(6))

	func _gui_input(event: InputEvent) -> void:
		if not active:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = true
				_cancelled = false
				_press = event.position
			elif _down:
				_down = false
				if not _cancelled and Rect2(Vector2.ZERO, size).has_point(event.position):
					tapped.emit()
		elif event is InputEventMouseMotion and _down and event.position.distance_to(_press) > 24:
			_down = false
			_cancelled = true


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
