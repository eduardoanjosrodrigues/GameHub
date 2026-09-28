class_name SenhaArt
extends RefCounted
## Desenho dos pinos do Senha (docs/PLANO_WORDLE_SENHA.md §4.1). Em cores, cada cor tem também uma
## forma (pra quem é daltônico). Em números, é o dígito num pino claro. As mesmas cores e formas
## estão em web/senha.js.

const COLORS := [
	Color("#C8392B"), # vermelho
	Color("#2B59C3"), # azul
	Color("#F2B233"), # mostarda
	Color("#2F7D5B"), # sálvia
	Color("#6E3B93"), # roxo
	Color("#D9772B"), # laranja
	Color("#C4467A"), # rosa
	Color("#1E7F86"), # turquesa
]
const COLOR_NAMES := ["vermelho", "azul", "amarelo", "verde", "roxo", "laranja", "rosa", "turquesa"]
const SHAPES := ["circle", "triangle", "square", "diamond", "star", "plus", "hexagon", "ring"]


static func mark_color(s: int) -> Color:
	return Tokens.TINTA if s == 2 else Tokens.SUPERFICIE


## Pino de símbolo s centrado em c. look: "cores" ou "numeros". s < 0 = vaga vazia.
static func draw_peg(ci: CanvasItem, c: Vector2, r: float, s: int, look: String, dim := false) -> void:
	if s < 0:
		ci.draw_arc(c, r * 0.9, 0, TAU, 32, Tokens.LINHA, maxf(2.0, r * 0.12), true)
		ci.draw_circle(c, r * 0.22, Tokens.LINHA)
		return
	var fade := func(col: Color) -> Color: return col.lerp(Tokens.PAPEL, 0.6) if dim else col
	if look == "numeros":
		ci.draw_circle(c, r, fade.call(Tokens.SUPERFICIE))
		ci.draw_arc(c, r, 0, TAU, 40, fade.call(Tokens.TINTA), maxf(2.0, r * 0.1), true)
		var font := Fonts.title_bold()
		var fs := int(r * 1.15)
		var text := str(s + 1)
		var ssz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		ci.draw_string(font, c + Vector2(-ssz.x / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fade.call(Tokens.TINTA))
		return
	var col: Color = COLORS[s % COLORS.size()]
	ci.draw_circle(c, r, fade.call(col))
	ci.draw_arc(c, r, 0, TAU, 40, fade.call(col.darkened(0.25)), maxf(1.5, r * 0.08), true)
	draw_shape(ci, c, r * 0.42, SHAPES[s % SHAPES.size()], fade.call(mark_color(s)))


static func draw_shape(ci: CanvasItem, c: Vector2, r: float, shape: String, col: Color) -> void:
	match shape:
		"circle":
			ci.draw_circle(c, r * 0.8, col)
		"triangle":
			ci.draw_colored_polygon(_poly(c, r * 1.1, 3, -PI / 2, Vector2(0, r * 0.15)), col)
		"square":
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), col)
		"diamond":
			ci.draw_colored_polygon(_poly(c, r * 1.05, 4, -PI / 2), col)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.1 if i % 2 == 0 else r * 0.45))
			ci.draw_colored_polygon(pts, col)
		"plus":
			ci.draw_rect(Rect2(c - Vector2(r, r * 0.32), Vector2(r * 2, r * 0.64)), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.32, r), Vector2(r * 0.64, r * 2)), col)
		"hexagon":
			ci.draw_colored_polygon(_poly(c, r * 0.95, 6, 0), col)
		"ring":
			ci.draw_arc(c, r * 0.7, 0, TAU, 32, col, r * 0.4, true)


static func _poly(c: Vector2, r: float, n: int, start: float, offset := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := start + i * TAU / n
		pts.append(c + offset + Vector2(cos(a), sin(a)) * r)
	return pts


## Retorno por contagem: bolinhas cheias (lugar certo) e vazadas (lugar errado), em até 2 linhas.
static func draw_count(ci: CanvasItem, rect: Rect2, fb: Array, pins: int) -> void:
	var black := int(fb[0]) if fb.size() > 0 else 0
	var white := int(fb[1]) if fb.size() > 1 else 0
	var per_row := int(ceil(pins / 2.0))
	var cell := minf(rect.size.x / per_row, rect.size.y / 2.0)
	var r := cell * 0.32
	var origin := rect.get_center() - Vector2(per_row * cell, 2 * cell) / 2.0
	for i in pins:
		var c := origin + Vector2((i % per_row + 0.5) * cell, (i / per_row + 0.5) * cell)
		if i < black:
			ci.draw_circle(c, r, Tokens.TINTA)
		elif i < black + white:
			ci.draw_circle(c, r, Tokens.SUPERFICIE)
			ci.draw_arc(c, r, 0, TAU, 24, Tokens.TINTA, maxf(1.5, r * 0.35), true)
		else:
			ci.draw_circle(c, r * 0.45, Tokens.LINHA)
