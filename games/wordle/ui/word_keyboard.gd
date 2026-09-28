class_name WordKeyboard
extends Control
## Teclado QWERTY do Wordle, sem acentos (docs/PLANO_WORDLE_SENHA.md §3.1, §6). Cada tecla mostra a
## melhor cor que a letra já teve. No Dueto e no Quarteto a tecla se divide em 2 ou 4 partes, uma
## cor por grade (como no Termo).

signal key(k: String) # "a".."z", "enter" ou "back"

const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

## Um dicionário por grade: {letra: 0|1|2}. Grade resolvida: null (a parte fica neutra).
var colors: Array = [{}]
var disabled := false
var key_h := 62.0
var gap := 6.0
var _rects: Array = [] # [[Rect2, tecla]]
var _down := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = key_h * 3 + gap * 2


func set_colors(p: Array) -> void:
	colors = p
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()


func _layout() -> void:
	_rects = []
	var w := (size.x - gap * 9) / 10.0
	for r in 3:
		var y := r * (key_h + gap)
		var letters: String = ROWS[r]
		if r < 2:
			var x := (size.x - (letters.length() * w + (letters.length() - 1) * gap)) / 2.0
			for ch in letters:
				_rects.append([Rect2(x, y, w, key_h), ch])
				x += w + gap
		else:
			var wide := (size.x - letters.length() * (w + gap) - gap) / 2.0
			_rects.append([Rect2(0, y, wide, key_h), "enter"])
			var x := wide + gap
			for ch in letters:
				_rects.append([Rect2(x, y, w, key_h), ch])
				x += w + gap
			_rects.append([Rect2(x, y, size.x - x, key_h), "back"])


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		pos = event.position
		if not event.pressed:
			_down = ""
			queue_redraw()
			return
	elif event is InputEventScreenTouch:
		# O Godot já converte o toque em clique; aqui só evita tratar duas vezes.
		return
	else:
		return
	if not pressed or disabled:
		return
	for rk in _rects:
		if (rk[0] as Rect2).grow(gap / 2.0).has_point(pos):
			_down = rk[1]
			queue_redraw()
			Haptics.tap()
			key.emit(rk[1])
			accept_event()
			return


func _draw() -> void:
	var font := Fonts.title_bold()
	for rk in _rects:
		var rect: Rect2 = rk[0]
		var k: String = rk[1]
		var parts: Array = []
		for board in colors:
			parts.append(-1 if board == null else int(board.get(k, -1)))
		var single := parts.size() == 1
		var base := Tokens.DESABILITADO
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = base if k == _down else base.lerp(Tokens.SUPERFICIE, 0.35)
		if k.length() == 1 and single and parts[0] >= 0:
			sb.bg_color = WordGrid.tile_color(parts[0])
		draw_style_box(sb, rect)
		# Várias grades: cada parte da tecla com a cor de uma grade.
		if k.length() == 1 and not single:
			for i in parts.size():
				if parts[i] < 0:
					continue
				var ps := StyleBoxFlat.new()
				ps.bg_color = WordGrid.tile_color(parts[i])
				_round_outer(ps, i, parts.size(), 10)
				draw_style_box(ps, _part(rect, i, parts.size()))
		var fg := Tokens.TINTA
		if k.length() == 1 and single and parts[0] >= 0:
			fg = WordGrid.text_color(parts[0])
		elif k.length() == 1 and not single and parts.all(func(p): return p == Desafio.GRAY or p == Desafio.GREEN):
			fg = Tokens.SUPERFICIE
		if disabled:
			fg = Tokens.TEXTO_DESABILITADO
		if k == "back":
			var ic := UI.icon("back")
			if ic:
				var s := minf(rect.size.y, rect.size.x) * 0.5
				draw_texture_rect(ic, Rect2(rect.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), false, fg)
			continue
		var text := "ENVIAR" if k == "enter" else k.to_upper()
		var fs := int(key_h * (0.26 if k == "enter" else 0.42))
		var ssz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := rect.get_center() + Vector2(-ssz.x / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
		if not single and k.length() == 1:
			# Letra com uma sombra clara pra ler sobre qualquer mistura de cores.
			draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tokens.TINTA, 0.35) if fg == Tokens.SUPERFICIE else Color(Tokens.SUPERFICIE, 0.6))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## Só os cantos que ficam na borda da tecla são arredondados.
func _round_outer(sb: StyleBoxFlat, i: int, n: int, r: int) -> void:
	var left := i % 2 == 0
	var top := n == 2 or i < 2
	var bottom := n == 2 or i >= 2
	sb.corner_radius_top_left = r if left and top else 0
	sb.corner_radius_bottom_left = r if left and bottom else 0
	sb.corner_radius_top_right = r if not left and top else 0
	sb.corner_radius_bottom_right = r if not left and bottom else 0


## Parte i de n da tecla: 2 = metades (esquerda/direita), 4 = quadrantes.
func _part(rect: Rect2, i: int, n: int) -> Rect2:
	var inner := rect
	if n == 2:
		return Rect2(inner.position + Vector2(inner.size.x / 2.0 * i, 0), Vector2(inner.size.x / 2.0, inner.size.y))
	var hw := inner.size.x / 2.0
	var hh := inner.size.y / 2.0
	return Rect2(inner.position + Vector2(hw * (i % 2), hh * (i / 2)), Vector2(hw, hh))
