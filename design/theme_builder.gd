class_name ThemeBuilder
extends RefCounted
## Monta o Theme global do app a partir dos tokens.


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.body()
	t.default_font_size = Tokens.FS_BODY

	t.set_color("font_color", "Label", Tokens.TINTA)

	# Campo de texto
	var field := card_style(Tokens.BRANCO, Tokens.RADIUS_FIELD, false)
	field.content_margin_left = 20
	field.content_margin_right = 20
	field.content_margin_top = 14
	field.content_margin_bottom = 14
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Tokens.AZUL
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_font("font", "LineEdit", Fonts.body_bold())
	t.set_font_size("font_size", "LineEdit", 22)
	t.set_color("font_color", "LineEdit", Tokens.TINTA)
	t.set_color("font_placeholder_color", "LineEdit", Tokens.TINTA_SUAVE.lerp(Tokens.BRANCO, 0.35))
	t.set_color("caret_color", "LineEdit", Tokens.AZUL)
	t.set_color("selection_color", "LineEdit", Tokens.AZUL.lerp(Tokens.BRANCO, 0.6))
	t.set_constant("caret_width", "LineEdit", 3)

	# Painel padrão = card
	t.set_stylebox("panel", "PanelContainer", card_style(Tokens.BRANCO))

	# Rolagem sem barra visível (arrastar com o dedo)
	var empty := StyleBoxEmpty.new()
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, empty)
		t.set_stylebox("scroll_focus", sb, empty)
		t.set_stylebox("grabber", sb, empty)
		t.set_stylebox("grabber_highlight", sb, empty)
		t.set_stylebox("grabber_pressed", sb, empty)
	t.set_stylebox("panel", "ScrollContainer", empty)
	t.set_stylebox("focus", "ScrollContainer", empty)

	t.set_constant("separation", "VBoxContainer", 16)
	t.set_constant("separation", "HBoxContainer", 16)
	return t


## Card no estilo cartoon: fundo, contorno tinta e sombra dura.
static func card_style(bg: Color, radius := Tokens.RADIUS_CARD, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Tokens.TINTA
	s.set_border_width_all(Tokens.BORDER)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Tokens.TINTA
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, Tokens.SHADOW)
	return s
