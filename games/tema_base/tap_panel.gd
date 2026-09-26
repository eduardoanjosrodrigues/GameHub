class_name TapPanel
extends PanelContainer
## Cartão que dá pra tocar (carta da fila, tema pra escolher). Como o AppButton, arrastar pra rolar
## a tela cancela o toque.

signal tapped

var _down := false
var _cancelled := false
var _press_pos := Vector2.ZERO
var _style: StyleBoxFlat


func _init(bg := Tokens.SUPERFICIE, pad := 18, border := Color.TRANSPARENT, border_w := 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_style = ThemeBuilder.card_style(bg)
	_style.content_margin_left = pad
	_style.content_margin_right = pad
	_style.content_margin_top = pad - 4
	_style.content_margin_bottom = pad - 4
	if border_w > 0:
		_style.border_color = border
		_style.set_border_width_all(border_w)
	add_theme_stylebox_override("panel", _style)


func set_bg(c: Color) -> void:
	_style.bg_color = c


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_cancelled = false
			_press_pos = event.position
			modulate = Color(0.94, 0.94, 0.94)
		elif _down:
			_down = false
			modulate = Color.WHITE
			if not _cancelled and Rect2(Vector2.ZERO, size).has_point(event.position):
				Audio.sfx("tap")
				Haptics.tap()
				tapped.emit()
	elif event is InputEventMouseMotion and _down and event.position.distance_to(_press_pos) > 24:
		_cancelled = true
		_down = false
		modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _down:
		_down = false
		_cancelled = true
		modulate = Color.WHITE
