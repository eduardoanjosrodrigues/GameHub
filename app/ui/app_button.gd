class_name AppButton
extends Control
## Botão do app: retângulo arredondado com sombra difusa. Ao tocar, afunda um pouco e escurece.

signal pressed

enum Variant { PRIMARY, SECONDARY, SUCCESS, DANGER, ACCENT, TEAM_AZUL, TEAM_VERMELHO }

## [fundo, texto, borda]
const _STYLE := {
	Variant.PRIMARY: [Tokens.TINTA, Tokens.SUPERFICIE, Tokens.TINTA],
	Variant.SECONDARY: [Tokens.SUPERFICIE, Tokens.TINTA, Tokens.LINHA],
	Variant.SUCCESS: [Tokens.SALVIA, Tokens.SUPERFICIE, Tokens.SALVIA],
	Variant.DANGER: [Tokens.SUPERFICIE, Tokens.VERMELHO_ESCURO, Color("#E9B7AF")],
	Variant.ACCENT: [Tokens.MOSTARDA, Tokens.TINTA, Tokens.MOSTARDA],
	Variant.TEAM_AZUL: [Tokens.AZUL, Tokens.SUPERFICIE, Tokens.AZUL],
	Variant.TEAM_VERMELHO: [Tokens.VERMELHO, Tokens.SUPERFICIE, Tokens.VERMELHO],
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
## Marcado (seletores e interruptores): botões secundários ficam em tinta.
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var height := 68
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
	var font := Fonts.ui()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if icon:
		w += _icon_size() + (10 if text != "" else 0)
	return Vector2(w + 48, max(height, Tokens.TOUCH_MIN))


func _icon_size() -> float:
	return font_size * 1.25


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


func _colors() -> Array:
	if disabled:
		return [Tokens.DESABILITADO, Tokens.TEXTO_DESABILITADO, Tokens.DESABILITADO]
	var st: Array = _STYLE[variant]
	if selected and variant == Variant.SECONDARY:
		return [Tokens.TINTA, Tokens.SUPERFICIE, Tokens.TINTA]
	return st


func _draw() -> void:
	var c := _colors()
	var fill: Color = c[0]
	var fg: Color = c[1]
	var border: Color = c[2]
	var lift := 3.0
	var dy := lift if _down and not disabled else 0.0
	if _down and not disabled:
		fill = fill.darkened(0.08)
	var body_rect := Rect2(0, dy, size.x, size.y - lift)
	var radius := int(min(Tokens.RADIUS_BUTTON, body_rect.size.y / 2.0))

	var body := StyleBoxFlat.new()
	body.bg_color = fill
	body.border_color = border
	body.set_border_width_all(2 if border != fill else 0)
	body.set_corner_radius_all(radius)
	body.anti_aliasing = true
	if not disabled:
		var flat: bool = fill.get_luminance() > 0.8
		body.shadow_color = Color(Tokens.TINTA, 0.10) if flat else Color(fill.darkened(0.55), 0.28)
		body.shadow_size = 4 if _down else 10
		body.shadow_offset = Vector2(0, 1 if _down else 4)
	draw_style_box(body, body_rect)

	var font := Fonts.ui()
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_w := 0.0
	if icon:
		icon_w = _icon_size() + (10 if text != "" else 0)
	var x := (size.x - text_w - icon_w) / 2.0
	var cy := body_rect.position.y + body_rect.size.y / 2.0
	if icon:
		var s := _icon_size()
		draw_texture_rect(icon, Rect2(x, cy - s / 2.0, s, s), false, fg)
		x += icon_w
	if text != "":
		var baseline := cy + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
