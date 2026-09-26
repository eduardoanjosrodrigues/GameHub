class_name ThemeBuilder
extends RefCounted
## Monta o Theme global do app a partir dos tokens.


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.body()
	t.default_font_size = Tokens.FS_BODY

	t.set_color("font_color", "Label", Tokens.TINTA)

	# Campo de texto: papel, linha fina, foco em cobalto.
	var field := StyleBoxFlat.new()
	field.bg_color = Tokens.SUPERFICIE
	field.border_color = Tokens.LINHA
	field.set_border_width_all(2)
	field.set_corner_radius_all(Tokens.RADIUS_FIELD)
	field.content_margin_left = 18
	field.content_margin_right = 18
	field.content_margin_top = 14
	field.content_margin_bottom = 14
	field.anti_aliasing = true
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Tokens.AZUL
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_font("font", "LineEdit", Fonts.body_bold())
	t.set_font_size("font_size", "LineEdit", 21)
	t.set_color("font_color", "LineEdit", Tokens.TINTA)
	t.set_color("font_placeholder_color", "LineEdit", Tokens.TEXTO_DESABILITADO)
	t.set_color("caret_color", "LineEdit", Tokens.AZUL)
	t.set_color("selection_color", "LineEdit", Tokens.tint(Tokens.AZUL, 0.3))
	t.set_constant("caret_width", "LineEdit", 2)

	t.set_stylebox("panel", "PanelContainer", card_style(Tokens.SUPERFICIE))

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


## Cartão de papel. Cores de impressão viram fundo tingido com borda da mesma cor;
## assim o texto em tinta continua legível em qualquer cartão.
static func card_style(bg: Color, radius := Tokens.RADIUS_CARD, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var plain := bg == Tokens.SUPERFICIE or bg == Tokens.PAPEL
	s.bg_color = bg if plain else Tokens.tint(bg)
	s.border_color = Tokens.LINHA if plain else Tokens.tint(bg, 0.35)
	s.set_border_width_all(int(Tokens.BORDER + 0.5))
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	s.anti_aliasing = true
	if shadow and plain:
		s.shadow_color = Tokens.SHADOW_COLOR
		s.shadow_size = 14
		s.shadow_offset = Vector2(0, 5)
	return s


## Cartão sólido (fundo com a cor cheia, texto claro por cima).
static func solid_style(bg: Color, radius := Tokens.RADIUS_CARD) -> StyleBoxFlat:
	var s := card_style(Tokens.SUPERFICIE, radius)
	s.bg_color = bg
	s.border_color = bg
	s.shadow_color = Color(bg.darkened(0.5), 0.22)
	return s
