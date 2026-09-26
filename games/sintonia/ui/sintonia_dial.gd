class_name SintoniaDial
extends Control
## O disco da Sintonia (docs/PLANO_SINTONIA_ITO.md §9): meio círculo de 0 (esquerda) a 100
## (direita), o alvo em faixas 2-3-4-3-2 quando dá pra ver, e a agulha. Com `interactive`, arrastar
## em qualquer ponto do disco gira a agulha; `moved` sai no máximo a cada SEND_EVERY_MS e
## `released` no fim do arrasto. Enquanto a pessoa arrasta, a posição que chega da rede é ignorada.

signal moved(pos: float)
signal released(pos: float)

const SEND_EVERY_MS := 66
const Z_COLORS := {4: Color("#2B59C3"), 3: Color("#C8392B"), 2: Color("#F2B233")}

var pos := 50.0
var target := -1.0 # -1 = escondido
var show_needle := true
var interactive := false
## Aposta do outro time: "left" / "right" pinta a metade escolhida.
var side := ""
var side_color := Tokens.VERMELHO
var _dragging := false
var _last_emit := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	resized.connect(func():
		var h := minf(size.x * 0.56, 520.0)
		if absf(custom_minimum_size.y - h) > 1.0:
			custom_minimum_size.y = h
		queue_redraw())


func set_interactive(on: bool) -> void:
	interactive = on
	# Parado, deixa o toque rolar a tela; girando, o disco fica com o toque.
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_PASS


func set_pos(p: float) -> void:
	if _dragging:
		return
	pos = p
	queue_redraw()


func _center() -> Vector2:
	return Vector2(size.x / 2.0, size.y - 14.0)


func _radius() -> float:
	return minf(size.x / 2.0 - 14.0, size.y - 28.0)


func _point(p: float, r: float) -> Vector2:
	var a := PI * (1.0 - p / 100.0)
	return _center() + Vector2(cos(a), -sin(a)) * r


func _wedge(a: float, b: float, r: float, color: Color) -> void:
	a = clampf(a, 0.0, 100.0)
	b = clampf(b, 0.0, 100.0)
	if b <= a:
		return
	var pts := PackedVector2Array([_center()])
	var steps := maxi(2, int((b - a) * 1.5))
	for i in steps + 1:
		pts.append(_point(lerpf(a, b, float(i) / steps), r))
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var c := _center()
	var r := _radius()
	if r <= 10:
		return
	var ink := Tokens.TINTA
	# Fundo.
	_wedge(0, 100, r, Tokens.SUPERFICIE)
	if side != "":
		if side == "left":
			_wedge(0, pos, r, Color(side_color, 0.16))
		else:
			_wedge(pos, 100, r, Color(side_color, 0.16))
	# Alvo: 2-3-4-3-2.
	if target >= 0:
		var zones := [[-10.0, -6.0, 2], [-6.0, -2.0, 3], [-2.0, 2.0, 4], [2.0, 6.0, 3], [6.0, 10.0, 2]]
		for z in zones:
			_wedge(target + z[0], target + z[1], r * 0.97, Z_COLORS[z[2]])
		var font := Fonts.title_bold()
		var fs := int(clampf(r * 0.09, 14, 40))
		for z in zones:
			var mid: float = target + (z[0] + z[1]) / 2.0
			if mid < 0 or mid > 100:
				continue
			var at := _point(mid, r * 0.82)
			var txt := str(z[2])
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, at + Vector2(-w / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Tokens.SUPERFICIE if z[2] != 2 else ink)
	# Marcas de 10 em 10.
	for i in 11:
		var p := i * 10.0
		draw_line(_point(p, r * 0.93), _point(p, r), Color(ink, 0.35), 2.0, true)
	# Contorno.
	var arc := PackedVector2Array()
	for i in 61:
		arc.append(_point(i * 100.0 / 60.0, r))
	arc.append(c + Vector2(-r, 0))
	draw_polyline(arc, ink, 5.0, true)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), ink, 5.0, true)
	# Agulha.
	if show_needle:
		var tip := _point(pos, r * 0.9)
		draw_line(c, tip, ink, maxf(5.0, r * 0.03), true)
		draw_circle(tip, maxf(5.0, r * 0.028), ink)
	draw_circle(c, maxf(12.0, r * 0.08), Tokens.SALVIA)
	draw_arc(c, maxf(12.0, r * 0.08), 0, TAU, 32, ink, 4.0, true)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_center()) > _radius() * 1.15:
				return
			_dragging = true
			_set_from(event.position, true)
		elif _dragging:
			_dragging = false
			released.emit(pos)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from(event.position, false)
		accept_event()


func _set_from(at: Vector2, force: bool) -> void:
	var d := at - _center()
	var a := atan2(-d.y, d.x) # 0 = direita, PI = esquerda
	if d.y > 0:
		a = 0.0 if d.x > 0 else PI
	pos = clampf(snappedf((1.0 - a / PI) * 100.0, 0.5), 0.0, 100.0)
	queue_redraw()
	var now := Time.get_ticks_msec()
	if force or now - _last_emit >= SEND_EVERY_MS:
		_last_emit = now
		moved.emit(pos)
