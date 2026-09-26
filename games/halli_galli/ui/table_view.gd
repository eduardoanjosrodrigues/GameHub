class_name HalliTableView
extends Control
## Modo aparelho na mesa (docs/PLANO_HALLI_GALLI.md §4.2): a tela dividida em áreas, uma por
## jogador, cada uma virada pro seu lado da mesa. Cada área tem monte, carta aberta e sino.
## Multitoque por dedo: arrastar na sua área vira, tocar no seu sino bate.

signal flip_requested(player_id: String)
signal bell_requested(player_id: String, local_us: int)

const SWIPE_PX := 40.0
const MARGIN := 8.0

## Cada área: {id, name, color, top, down, out, turn, ready}
var zones: Array = []
var _layout: Array = [] # [{rect, rot}]
var _touches := {} # index -> {zone, start, consumed}
var _anim := {} # id -> {flip, bell, banner: {text, color, age}}
var _pulse := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout = layout_for(zones.size(), size)


func set_zones(z: Array) -> void:
	for nz in z:
		var old: Dictionary = {}
		for oz in zones:
			if oz.id == nz.id:
				old = oz
		var a: Dictionary = _anim_of(nz.id)
		if not old.is_empty() and int(nz.top) != int(old.top) and int(nz.top) >= 0:
			a.flip = 0.0
	var resized := z.size() != zones.size()
	zones = z
	if resized:
		_layout = layout_for(zones.size(), size)
	queue_redraw()


func banner(id: String, text: String, color: Color) -> void:
	_anim_of(id).banner = {"text": text, "color": color, "age": 0.0}


func _anim_of(id: String) -> Dictionary:
	if not _anim.has(id):
		_anim[id] = {"flip": 1.0, "bell": 0.0, "banner": {}}
	return _anim[id]


## Áreas em sentido horário a partir de baixo (a ordem da vez segue a volta da mesa).
static func layout_for(n: int, s: Vector2) -> Array:
	var w := s.x
	var h := s.y
	var B := 0.0
	var L := PI / 2.0
	var T := PI
	var R := -PI / 2.0
	match n:
		2:
			return [{"rect": Rect2(0, h / 2, w, h / 2), "rot": B}, {"rect": Rect2(0, 0, w, h / 2), "rot": T}]
		3:
			return [
				{"rect": Rect2(0, h * 0.62, w, h * 0.38), "rot": B},
				{"rect": Rect2(0, 0, w / 2, h * 0.62), "rot": L},
				{"rect": Rect2(w / 2, 0, w / 2, h * 0.62), "rot": R},
			]
		4:
			return [
				{"rect": Rect2(0, h * 0.7, w, h * 0.3), "rot": B},
				{"rect": Rect2(0, h * 0.3, w / 2, h * 0.4), "rot": L},
				{"rect": Rect2(0, 0, w, h * 0.3), "rot": T},
				{"rect": Rect2(w / 2, h * 0.3, w / 2, h * 0.4), "rot": R},
			]
		5:
			return [
				{"rect": Rect2(0, h * 0.8, w, h * 0.2), "rot": B},
				{"rect": Rect2(0, h * 0.5, w / 2, h * 0.3), "rot": L},
				{"rect": Rect2(0, h * 0.2, w / 2, h * 0.3), "rot": L},
				{"rect": Rect2(0, 0, w, h * 0.2), "rot": T},
				{"rect": Rect2(w / 2, h * 0.2, w / 2, h * 0.6), "rot": R},
			]
		6:
			return [
				{"rect": Rect2(0, h * 0.8, w, h * 0.2), "rot": B},
				{"rect": Rect2(0, h * 0.5, w / 2, h * 0.3), "rot": L},
				{"rect": Rect2(0, h * 0.2, w / 2, h * 0.3), "rot": L},
				{"rect": Rect2(0, 0, w, h * 0.2), "rot": T},
				{"rect": Rect2(w / 2, h * 0.2, w / 2, h * 0.3), "rot": R},
				{"rect": Rect2(w / 2, h * 0.5, w / 2, h * 0.3), "rot": R},
			]
	return []


## Tamanho da área no referencial do jogador (largura ao longo da borda, altura = profundidade).
static func _local_size(l: Dictionary) -> Vector2:
	var r: Rect2 = l.rect
	return r.size if is_equal_approx(absf(sin(l.rot)), 0.0) else Vector2(r.size.y, r.size.x)


## Monte, carta e sino no referencial do jogador (origem no centro da área).
static func _parts(ls: Vector2) -> Dictionary:
	var ch := minf(ls.y * 0.6, ls.x * 0.42 * HalliArt.CARD_RATIO)
	var cw := ch / HalliArt.CARD_RATIO
	var pw := cw * 0.7
	var bs := minf(ch * 0.85, ls.x * 0.26)
	var gap := maxf(16.0, ls.x * 0.04)
	var total := pw + gap + cw + gap * 2.0 + bs
	# Encolhe tudo junto se não couber na largura da área (com folga nas bordas).
	var avail := ls.x - MARGIN * 2.0 - 40.0
	if total > avail:
		var k := avail / total
		ch *= k
		cw *= k
		pw *= k
		bs *= k
		gap *= k
		total = avail
	var x := -total / 2.0
	var cy := -ls.y * 0.06
	var pile := Rect2(x, cy - pw * HalliArt.CARD_RATIO / 2.0, pw, pw * HalliArt.CARD_RATIO)
	x += pw + gap
	var card := Rect2(x, cy - ch / 2.0, cw, ch)
	x += cw + gap * 2.0
	var bell := Rect2(x, cy - bs / 2.0, bs, bs)
	return {"pile": pile, "card": card, "bell": bell, "name_y": ls.y / 2.0 - MARGIN - 26.0}


func _process(delta: float) -> void:
	_pulse += delta
	for id in _anim:
		var a: Dictionary = _anim[id]
		a.flip = minf(1.0, a.flip + delta / 0.2)
		a.bell = maxf(0.0, a.bell - delta / 0.18)
		if not a.banner.is_empty():
			a.banner.age += delta
			if a.banner.age > 1.4:
				a.banner = {}
	queue_redraw()


# --- Toques ----------------------------------------------------------------

func _zone_at(pos: Vector2) -> int:
	for i in _layout.size():
		if (_layout[i].rect as Rect2).has_point(pos):
			return i
	return -1


func _to_local(i: int, pos: Vector2) -> Vector2:
	var l: Dictionary = _layout[i]
	return (pos - (l.rect as Rect2).get_center()).rotated(-l.rot)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		accept_event()
		if not e.pressed:
			_touches.erase(e.index)
			return
		var i := _zone_at(e.position)
		if i < 0 or i >= zones.size():
			return
		var p := _parts(_local_size(_layout[i]))
		var lp := _to_local(i, e.position)
		if (p.bell as Rect2).grow(14).has_point(lp):
			_touches[e.index] = {"zone": i, "start": e.position, "consumed": true}
			_anim_of(zones[i].id).bell = 1.0
			bell_requested.emit(zones[i].id, Time.get_ticks_usec())
			return
		_touches[e.index] = {"zone": i, "start": e.position, "consumed": false}
	elif e is InputEventScreenDrag:
		accept_event()
		var tt: Dictionary = _touches.get(e.index, {})
		if tt.is_empty() or tt.consumed:
			return
		if e.position.distance_to(tt.start) >= SWIPE_PX:
			tt.consumed = true
			flip_requested.emit(zones[tt.zone].id)


# --- Desenho ---------------------------------------------------------------

func _draw() -> void:
	for i in mini(zones.size(), _layout.size()):
		var l: Dictionary = _layout[i]
		var xf := Transform2D(l.rot, (l.rect as Rect2).get_center())
		draw_set_transform_matrix(xf)
		_draw_zone(zones[i], _local_size(l), xf)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_zone(z: Dictionary, ls: Vector2, xf: Transform2D) -> void:
	var col := HalliArt.player_color(int(z.color))
	var panel := Rect2(-ls / 2.0 + Vector2(MARGIN, MARGIN), ls - Vector2(MARGIN, MARGIN) * 2.0)
	var a: Dictionary = _anim_of(z.id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tokens.tint(col, 0.10 if not z.out else 0.03)
	sb.border_color = Color(col, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24)
	sb.anti_aliasing = true
	if z.turn and not z.out:
		if float(z.ready) >= 1.0:
			sb.border_color = Color(col, 0.75 + 0.25 * sin(_pulse * 5.0))
			sb.set_border_width_all(10)
		else:
			sb.set_border_width_all(4)
	draw_style_box(sb, panel)
	if z.turn and not z.out and float(z.ready) < 1.0:
		var pts := HalliPlayerView._perimeter(panel.grow(-4), float(z.ready))
		if pts.size() >= 2:
			draw_polyline(pts, col, 8.0, true)

	var p := _parts(ls)
	HalliArt.draw_pile(self, p.pile, int(z.down), int(clampf(p.pile.size.x * 0.24, 14, 26)))
	var cr: Rect2 = p.card
	if int(z.top) >= 0:
		var sx := absf(cos((1.0 - a.flip) * PI / 2.0))
		var cxf := xf * Transform2D(0.0, cr.get_center()).scaled_local(Vector2(maxf(sx, 0.02), 1.0))
		HalliArt.draw_face(self, Rect2(-cr.size / 2.0, cr.size), int(z.top), cxf)
		draw_set_transform_matrix(xf)
	else:
		HalliArt.draw_slot(self, cr, col)
	HalliArt.draw_bell(self, p.bell, a.bell > 0.0, z.out)

	var font := Fonts.title_bold()
	var body := Fonts.body_bold()
	var label: String = z.name
	var sub := ""
	if z.out:
		sub = "saiu"
	elif z.turn:
		sub = "sua vez · arraste" if float(z.ready) >= 1.0 else "espera..."
	var fs := int(clampf(ls.y * 0.075, 18, 30))
	var nw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6).x if sub != "" else 0.0
	var tot := nw + (sw + 16.0 if sub != "" else 0.0)
	var y: float = p.name_y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(-tot / 2.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.TINTA)
	if sub != "":
		draw_string(body, Vector2(-tot / 2.0 + nw + 16.0, y), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Tokens.dark_of(col) if z.turn else Tokens.TINTA_SUAVE)

	if not a.banner.is_empty():
		var k: float = a.banner.age / 1.4
		var al := clampf(minf(k * 8.0, (1.0 - k) * 5.0), 0.0, 1.0)
		var bf := int(clampf(ls.y * 0.16, 30, 64))
		var tw := font.get_string_size(a.banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bf).x
		var br := Rect2(Vector2(-tw / 2.0 - 28, -bf * 0.9), Vector2(tw + 56, bf * 1.8))
		var bb := StyleBoxFlat.new()
		bb.bg_color = Color(a.banner.color, al)
		bb.set_corner_radius_all(22)
		bb.anti_aliasing = true
		draw_style_box(bb, br)
		draw_string(font, Vector2(-tw / 2.0, (font.get_ascent(bf) - font.get_descent(bf)) / 2.0), a.banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bf, Color(Tokens.on(a.banner.color), al))
