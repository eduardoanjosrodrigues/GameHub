class_name HalliArt
extends RefCounted
## Desenho das cartas, do monte e do sino do Halli Galli (docs/PLANO_HALLI_GALLI.md §7).
## Tudo desenhado no _draw de quem chama, pra dar pra girar (modo mesa) sem montar nós.

const CARD_RATIO := 1.42 # altura / largura
const FACE := Color("#FFFDF8")
const BACK := Color("#C8392B")
const BACK_DARK := Color("#9E2A1F")
## Cores dos jogadores (avatar, borda da vez, área na mesa).
const PLAYER_COLORS := [
	Color("#2B59C3"), Color("#C8392B"), Color("#2F7D5B"), Color("#E0A21F"),
	Color("#6E3B93"), Color("#1E7F86"), Color("#D9772B"), Color("#C4467A"),
]
const FRUIT_NAMES := ["bananas", "morangos", "limões", "ameixas"]
const FRUIT_ONE := ["banana", "morango", "limão", "ameixa"]

## Posições das frutas na carta (0..1), simétricas por meia-volta: dá pra ler de qualquer lado.
const SLOTS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.32, 0.29), Vector2(0.68, 0.71)],
	3: [Vector2(0.28, 0.24), Vector2(0.5, 0.5), Vector2(0.72, 0.76)],
	4: [Vector2(0.3, 0.27), Vector2(0.7, 0.27), Vector2(0.3, 0.73), Vector2(0.7, 0.73)],
	5: [Vector2(0.28, 0.21), Vector2(0.72, 0.21), Vector2(0.5, 0.5), Vector2(0.28, 0.79), Vector2(0.72, 0.79)],
}
const FRUIT_SCALE := {1: 0.7, 2: 0.52, 3: 0.44, 4: 0.44, 5: 0.4}

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://games/halli_galli/art/%s.svg" % name)
	return _tex[name]


static func fruit_tex(fruit: int) -> Texture2D:
	return tex(HalliRules.FRUITS[fruit])


static func player_color(idx: int) -> Color:
	return PLAYER_COLORS[idx % PLAYER_COLORS.size()]


## Maior carta que cabe em `area`, centralizada.
static func fit_card(area: Rect2) -> Rect2:
	var w := minf(area.size.x, area.size.y / CARD_RATIO)
	var s := Vector2(w, w * CARD_RATIO)
	return Rect2(area.position + (area.size - s) / 2.0, s)


static func _card_box(ci: CanvasItem, r: Rect2, fill: Color, border: Color, lifted := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(maxi(2, int(r.size.x * 0.012)))
	sb.set_corner_radius_all(int(r.size.x * 0.09))
	sb.anti_aliasing = true
	if lifted:
		sb.shadow_color = Color(Tokens.TINTA, 0.16)
		sb.shadow_size = int(r.size.x * 0.05)
		sb.shadow_offset = Vector2(0, r.size.x * 0.02)
	ci.draw_style_box(sb, r)


## xf: transformação já em uso por quem desenha (área girada, carta virando). As frutas giram
## em cima dela, e ela volta a valer no fim.
static func draw_face(ci: CanvasItem, r: Rect2, card: int, xf := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(xf)
	_card_box(ci, r, FACE, Tokens.TINTA)
	var inner := r.grow(-r.size.x * 0.055)
	var ib := StyleBoxFlat.new()
	ib.draw_center = false
	ib.border_color = Tokens.LINHA
	ib.set_border_width_all(maxi(1, int(r.size.x * 0.008)))
	ib.set_corner_radius_all(int(r.size.x * 0.06))
	ib.anti_aliasing = true
	ci.draw_style_box(ib, inner)
	var n := HalliRules.card_count(card)
	var t := fruit_tex(HalliRules.card_fruit(card))
	var fs: float = r.size.x * FRUIT_SCALE[n]
	var slots: Array = SLOTS[n]
	for i in slots.size():
		var p: Vector2 = r.position + Vector2(slots[i].x * r.size.x, slots[i].y * r.size.y)
		# Uma leve inclinação por posição, sempre a mesma (a carta não "treme" ao redesenhar).
		var ang := deg_to_rad([-8.0, 10.0, -4.0, 6.0, -10.0][i])
		ci.draw_set_transform_matrix(xf * Transform2D(ang, p))
		ci.draw_texture_rect(t, Rect2(-fs / 2.0, -fs / 2.0, fs, fs), false)
	ci.draw_set_transform_matrix(xf)


static func draw_back(ci: CanvasItem, r: Rect2) -> void:
	_card_box(ci, r, BACK, Tokens.TINTA)
	var inner := r.grow(-r.size.x * 0.07)
	var ib := StyleBoxFlat.new()
	ib.bg_color = BACK_DARK
	ib.border_color = Color(FACE, 0.85)
	ib.set_border_width_all(maxi(2, int(r.size.x * 0.018)))
	ib.set_corner_radius_all(int(r.size.x * 0.06))
	ib.anti_aliasing = true
	ci.draw_style_box(ib, inner)
	# Losangos claros em diagonal
	var step := inner.size.x / 5.0
	var d := step * 0.18
	var y := inner.position.y + step * 0.5
	var row := 0
	while y < inner.end.y - step * 0.3:
		var x := inner.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < inner.end.x - step * 0.3:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d), Vector2(x - d, y)]), Color(FACE, 0.22))
			x += step
		y += step * 0.5
		row += 1
	var bell_s := inner.size.x * 0.5
	ci.draw_texture_rect(tex("sino"), Rect2(inner.get_center() - Vector2(bell_s, bell_s) / 2.0, Vector2(bell_s, bell_s)), false)


## Lugar vazio na mesa (pilha aberta sem carta).
static func draw_slot(ci: CanvasItem, r: Rect2, color := Tokens.TINTA_SUAVE) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = true
	sb.bg_color = Color(color, 0.06)
	sb.border_color = Color(color, 0.35)
	sb.set_border_width_all(maxi(2, int(r.size.x * 0.012)))
	sb.set_corner_radius_all(int(r.size.x * 0.09))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## Monte fechado: algumas cartas empilhadas (mais cartas, pilha mais alta), com o número em cima.
static func draw_pile(ci: CanvasItem, r: Rect2, count: int, font_size := 0) -> void:
	if count <= 0:
		draw_slot(ci, r)
		return
	var layers := clampi(ceili(count / 6.0), 1, 4)
	var off := r.size.x * 0.025
	for i in range(layers - 1, 0, -1):
		_card_box(ci, Rect2(r.position + Vector2(off * i, -off * i), r.size), BACK_DARK, Tokens.TINTA, i == layers - 1)
	var top := Rect2(r.position, r.size)
	draw_back(ci, top)
	if font_size > 0:
		var font := Fonts.title_bold()
		var txt := str(count)
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var c := top.get_center() + Vector2(0, top.size.y * 0.33)
		var pill := Rect2(c - Vector2(ts.x / 2.0 + font_size * 0.4, font_size * 0.62), Vector2(ts.x + font_size * 0.8, font_size * 1.24))
		var sb := StyleBoxFlat.new()
		sb.bg_color = FACE
		sb.border_color = Tokens.TINTA
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(pill.size.y / 2.0))
		sb.anti_aliasing = true
		ci.draw_style_box(sb, pill)
		ci.draw_string(font, Vector2(c.x - ts.x / 2.0, c.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.TINTA)


## Sino. pressed afunda um pouco.
static func draw_bell(ci: CanvasItem, r: Rect2, pressed := false, dim := false) -> void:
	var s := minf(r.size.x, r.size.y)
	var rr := Rect2(r.get_center() - Vector2(s, s) / 2.0, Vector2(s, s))
	if pressed:
		rr = rr.grow(-s * 0.04)
		rr.position.y += s * 0.03
	ci.draw_texture_rect(tex("sino"), rr, false, Color(1, 1, 1, 0.45) if dim else Color.WHITE)


static func fruit_phrase(fruit: int) -> String:
	return "5 %s" % FRUIT_NAMES[fruit] if fruit >= 0 else ""
