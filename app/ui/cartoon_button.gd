class_name CartoonButton
extends Control
## Botão cartoon: pílula com contorno grosso e sombra dura que "afunda" ao tocar.

signal pressed

enum Variant { PRIMARY, SECONDARY, SUCCESS, DANGER, ACCENT, TEAM_AZUL, TEAM_VERMELHO }

const _FILL := {
	Variant.PRIMARY: Tokens.AZUL,
	Variant.SECONDARY: Tokens.BRANCO,
	Variant.SUCCESS: Tokens.TURQUESA,
	Variant.DANGER: Tokens.ROSA,
	Variant.ACCENT: Tokens.LIMA,
	Variant.TEAM_AZUL: Tokens.AZUL,
	Variant.TEAM_VERMELHO: Tokens.VERMELHO,
}

var text := "":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()
var variant := Variant.PRIMARY:
	set(v):
		variant = v
		queue_redraw()
var icon: Texture2D:
	set(v):
		icon = v
		update_minimum_size()
		queue_redraw()
var font_size := Tokens.FS_BUTTON:
	set(v):
		font_size = v
		update_minimum_size()
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		mouse_default_cursor_shape = CURSOR_ARROW if v else CURSOR_POINTING_HAND
		queue_redraw()
## Botão marcado (usado em seletores): desenhado já afundado.
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var height := 72
var sound := "tap"
var haptic := true

var _down := false
var _press_pos := Vector2.ZERO
var _cancelled := false


func _init(p_text := "", p_variant := Variant.PRIMARY, p_icon: Texture2D = null) -> void:
	text = p_text
	variant = p_variant
	icon = p_icon
	mouse_filter = MOUSE_FILTER_PASS
	focus_mode = FOCUS_NONE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _get_minimum_size() -> Vector2:
	var font := Fonts.title()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if icon:
		w += _icon_size() + (12 if text != "" else 0)
	return Vector2(w + 56, max(height, Tokens.TOUCH_MIN + Tokens.SHADOW))


func _icon_size() -> float:
	return font_size * 1.35


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_cancelled = false
			_press_pos = event.position
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			if not _cancelled and Rect2(Vector2.ZERO, size).has_point(event.position):
				_fire()
	elif event is InputEventMouseMotion and _down:
		# Arrastar (rolagem) cancela o toque.
		if event.position.distance_to(_press_pos) > 24:
			_cancelled = true
			_down = false
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _down:
		_down = false
		_cancelled = true
		queue_redraw()


func _fire() -> void:
	if sound != "":
		Audio.sfx(sound)
	if haptic:
		Haptics.tap()
	pressed.emit()


func _draw() -> void:
	var depth := Tokens.SHADOW
	var body_h := size.y - depth
	var sunk := (_down or selected) and not disabled
	var dy := Tokens.PRESS_DEPTH if sunk else 0
	var radius := int(min(body_h / 2.0, 40))

	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Tokens.TINTA
	shadow.set_corner_radius_all(radius)
	shadow.anti_aliasing = true
	draw_style_box(shadow, Rect2(0, depth, size.x, body_h))

	var fill: Color = Tokens.DESABILITADO if disabled else _FILL[variant]
	var body := StyleBoxFlat.new()
	body.bg_color = fill
	body.border_color = Tokens.TINTA
	body.set_border_width_all(Tokens.BORDER)
	body.set_corner_radius_all(radius)
	body.anti_aliasing = true
	draw_style_box(body, Rect2(0, dy, size.x, body_h))

	var fg := Tokens.TINTA_SUAVE if disabled else Tokens.TINTA
	var font := Fonts.title()
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_w := 0.0
	if icon:
		icon_w = _icon_size() + (12 if text != "" else 0)
	var x := (size.x - text_w - icon_w) / 2.0
	var cy := dy + body_h / 2.0
	if icon:
		var s := _icon_size()
		draw_texture_rect(icon, Rect2(x, cy - s / 2.0, s, s), false, fg)
		x += icon_w
	if text != "":
		var baseline := cy + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
