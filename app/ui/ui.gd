class_name UI
extends RefCounted
## Atalhos pra montar telas em código com o visual do design system.

static var _icons := {}


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://design/icons/%s.svg" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


static func label(text: String, size := Tokens.FS_BODY, color := Tokens.TINTA, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := Tokens.FS_TITLE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return label(text, size, Tokens.TINTA, Fonts.title_bold(), align)


static func subtitle(text: String, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return label(text, Tokens.FS_SUBTITLE, Tokens.TINTA, Fonts.title(), align)


static func caption(text: String, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return label(text, Tokens.FS_BODY, Tokens.TINTA_SUAVE, Fonts.body(), align)


static func vbox(sep := 16) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep := 16) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func spacer(h := 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func card(bg := Tokens.SUPERFICIE, pad := 24) -> PanelContainer:
	var p := PanelContainer.new()
	var s := ThemeBuilder.card_style(bg)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad - 4
	s.content_margin_bottom = pad - 4
	p.add_theme_stylebox_override("panel", s)
	return p


static func button(text: String, variant := AppButton.Variant.PRIMARY, on_press := Callable(), icon_name := "") -> AppButton:
	var b := AppButton.new(text, variant, icon(icon_name) if icon_name != "" else null)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func small_button(text: String, variant := AppButton.Variant.SECONDARY, on_press := Callable(), icon_name := "") -> AppButton:
	var b := AppButton.new(text, variant, icon(icon_name) if icon_name != "" else null)
	b.height = 58
	b.font_size = 18
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func icon_button(icon_name: String, on_press := Callable(), variant := AppButton.Variant.SECONDARY) -> AppButton:
	var b := AppButton.new("", variant, icon(icon_name))
	b.height = 64
	b.custom_minimum_size = Vector2(64, 64)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func texture(icon_name: String, size_px: float, modulate := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size_px, size_px)
	t.modulate = modulate
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func line_edit(placeholder := "", text := "", max_len := 40) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = max_len
	e.custom_minimum_size.y = 64
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	e.caret_blink = true
	return e


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 12
	return s


static func margin(all := 24, top := -1, bottom := -1) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all if top < 0 else top)
	m.add_theme_constant_override("margin_bottom", all if bottom < 0 else bottom)
	return m


## Linha de jogador: avatar + nome (+ extra à direita).
static func player_row(p_name: String, color: Color, connected := true, extra := "") -> HBoxContainer:
	var row := hbox(12)
	var av := Avatar.new(p_name, color, 44)
	av.connected = connected
	row.add_child(av)
	var l := label(p_name, 20, Tokens.TINTA, Fonts.body_bold())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size.x = 80
	row.add_child(l)
	if extra != "":
		var e := label(extra, Tokens.FS_CAPTION + 2, Tokens.TINTA_SUAVE, Fonts.body_bold())
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(e)
	return row


## Seletor de opções (botões lado a lado, um marcado).
static func segmented(options: Array, selected: String, on_select: Callable, enabled := true) -> HBoxContainer:
	var row := hbox(10)
	for opt in options:
		var b := small_button(opt[1], AppButton.Variant.PRIMARY if opt[0] == selected else AppButton.Variant.SECONDARY)
		b.selected = opt[0] == selected
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not enabled and opt[0] != selected
		var key: String = opt[0]
		b.pressed.connect(func(): on_select.call(key))
		row.add_child(b)
	return row


## Contador com − e +.
static func stepper(value: int, min_v: int, max_v: int, step: int, on_change: Callable, enabled := true) -> HBoxContainer:
	var row := hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var minus := icon_button("minus", func(): on_change.call(clampi(value - step, min_v, max_v)))
	minus.disabled = not enabled or value <= min_v
	var plus := icon_button("plus", func(): on_change.call(clampi(value + step, min_v, max_v)))
	plus.disabled = not enabled or value >= max_v
	var l := label(str(value), 32, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 72
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(minus)
	row.add_child(l)
	row.add_child(plus)
	return row


## Interruptor liga/desliga no estilo cartoon.
static func toggle(on: bool, on_change: Callable, enabled := true) -> AppButton:
	var b := small_button("Ligado" if on else "Desligado", AppButton.Variant.SUCCESS if on else AppButton.Variant.SECONDARY)
	b.custom_minimum_size.x = 150
	b.disabled = not enabled
	b.pressed.connect(func(): on_change.call(not on))
	return b


## Linha de configuração: rótulo à esquerda, controle embaixo.
static func setting_block(title_text: String, control: Control, hint := "") -> VBoxContainer:
	var v := vbox(10)
	v.add_child(label(title_text, 20, Tokens.TINTA, Fonts.body_bold()))
	if hint != "":
		v.add_child(label(hint, Tokens.FS_CAPTION + 2, Tokens.TINTA_SUAVE))
	v.add_child(control)
	return v


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
