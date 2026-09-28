class_name HalliPlayerView
extends Control
## Tela do jogador no Wi-Fi, com o celular deitado na mesa (docs/PLANO_HALLI_GALLI.md §4.1):
## a carta aberta enorme, o monte num canto, a borda de "sua vez" e os gestos.
##   Arrastar em qualquer parte: virar. Toque duplo em qualquer parte: sino.
## Só desenha e reconhece gestos; quem decide o que fazer é a tela.

signal swiped
signal double_tapped(local_us: int)

const SWIPE_PX := 40.0
const TAP_SLOP_PX := 24.0
const TAP_MAX_US := 260_000
const DOUBLE_TAP_GAP_US := 300_000
const DOUBLE_TAP_DIST_PX := 80.0
const BORDER_W := 16.0

var top := -1
var down := 0
var color := Tokens.AZUL
var player_name := ""
var status_text := ""
var hint_text := ""
var weak := false
var my_turn := false
## 0..1: quanto do intervalo entre viradas já passou (1 = pode virar).
var ready_frac := 1.0

var _touches := {} # index -> {start, t, consumed}
var _last_tap_us := 0
var _last_tap_pos := Vector2.ZERO
var _flip_anim := 1.0 # 0 = carta de lado (meio da virada), 1 = normal
var _leave_anim := 0.0 # >0: carta saindo da mesa
var _leaving_card := -1
var _ripples: Array = [] # {pos, age}
var _banner := {} # {text, sub, color, age, dur}
var _pulse := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)


## reflip: caiu uma carta nova na pilha; anima mesmo se ela for igual à de baixo.
func set_top(card: int, animate: bool, reflip := false) -> void:
	if card == top and not (reflip and card >= 0):
		return
	if card < 0 and top >= 0 and animate:
		_leaving_card = top
		_leave_anim = 1.0
	top = card
	if card >= 0 and animate:
		_flip_anim = 0.0
	queue_redraw()


func show_banner(text: String, sub: String, bg: Color, dur := 1.4) -> void:
	_banner = {"text": text, "sub": sub, "color": bg, "age": 0.0, "dur": dur}
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if _flip_anim < 1.0:
		_flip_anim = minf(1.0, _flip_anim + delta / 0.2)
	if _leave_anim > 0.0:
		_leave_anim = maxf(0.0, _leave_anim - delta / 0.35)
	for r in _ripples:
		r.age += delta
	_ripples = _ripples.filter(func(r): return r.age < 0.6)
	if not _banner.is_empty():
		_banner.age += delta
		if _banner.age > _banner.dur:
			_banner = {}
	queue_redraw()


# --- Gestos ----------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		accept_event()
		var now := Time.get_ticks_usec()
		if e.pressed:
			if _last_tap_us > 0 and now - _last_tap_us <= DOUBLE_TAP_GAP_US and e.position.distance_to(_last_tap_pos) <= DOUBLE_TAP_DIST_PX:
				_last_tap_us = 0
				_touches[e.index] = {"start": e.position, "t": now, "consumed": true}
				_ripples.append({"pos": e.position, "age": 0.0})
				double_tapped.emit(now)
			else:
				_touches[e.index] = {"start": e.position, "t": now, "consumed": false}
		else:
			var tt: Dictionary = _touches.get(e.index, {})
			_touches.erase(e.index)
			if tt.is_empty() or tt.consumed:
				return
			if e.position.distance_to(tt.start) <= TAP_SLOP_PX and now - int(tt.t) <= TAP_MAX_US:
				_last_tap_us = now
				_last_tap_pos = e.position
	elif e is InputEventScreenDrag:
		accept_event()
		var tt: Dictionary = _touches.get(e.index, {})
		if tt.is_empty() or tt.consumed:
			return
		if e.position.distance_to(tt.start) >= SWIPE_PX:
			tt.consumed = true
			_last_tap_us = 0
			swiped.emit()


# --- Desenho ---------------------------------------------------------------

func _card_rect() -> Rect2:
	var area := Rect2(Vector2(40, 150), size - Vector2(80, 150 + 210))
	return HalliArt.fit_card(area)


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	_draw_turn_border(full)

	var font := Fonts.title_bold()
	var body := Fonts.body_bold()
	# Status no topo (virado pro dono).
	if status_text != "":
		_center_text(font, status_text, Vector2(size.x / 2.0, 92), 40, Tokens.TINTA)
	if hint_text != "":
		_center_text(body, hint_text, Vector2(size.x / 2.0, 130), 20, Tokens.TINTA_SUAVE)

	var cr := _card_rect()
	if _leave_anim > 0.0 and _leaving_card >= 0:
		var k := 1.0 - _leave_anim
		var lc := cr.get_center() + Vector2(0, -cr.size.y * 0.25 * k)
		var lxf := Transform2D(0.0, lc).scaled_local(Vector2.ONE * (1.0 - 0.3 * k))
		HalliArt.draw_face(self, Rect2(-cr.size / 2.0, cr.size), _leaving_card, lxf)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if top >= 0:
		# Virada: a carta "gira" de lado e cresce um pouquinho.
		var sx := absf(cos((1.0 - _flip_anim) * PI / 2.0))
		var lift := 1.0 + 0.06 * sin(_flip_anim * PI)
		var fxf := Transform2D(0.0, cr.get_center()).scaled_local(Vector2(maxf(sx, 0.02) * lift, lift))
		HalliArt.draw_face(self, Rect2(-cr.size / 2.0, cr.size), top, fxf)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif _leave_anim <= 0.0:
		HalliArt.draw_slot(self, cr)
		var msg := "Arraste pra virar" if my_turn else "Sua carta aparece aqui"
		_center_text(body, msg, cr.get_center(), 24, Tokens.TINTA_SUAVE)

	# Monte e nome, embaixo.
	var pr := Rect2(Vector2(40, size.y - 190), Vector2(110, 110 * HalliArt.CARD_RATIO))
	pr.position.y = size.y - pr.size.y - 36
	HalliArt.draw_pile(self, pr, down, 28)
	var name_pos := Vector2(pr.end.x + 28, size.y - 36 - pr.size.y / 2.0)
	draw_string(font, name_pos + Vector2(0, 8), player_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - name_pos.x - 40, 34, Tokens.TINTA)
	draw_string(body, name_pos + Vector2(0, 42), "%d %s no monte" % [down, "carta" if down == 1 else "cartas"], HORIZONTAL_ALIGNMENT_LEFT, size.x - name_pos.x - 40, 20, Tokens.TINTA_SUAVE)
	if weak:
		draw_string(body, name_pos + Vector2(0, -34), "sinal fraco", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Tokens.VERMELHO_ESCURO)

	for r in _ripples:
		var k: float = r.age / 0.6
		draw_arc(r.pos, 40.0 + 160.0 * k, 0, TAU, 48, Color(Tokens.MOSTARDA, 1.0 - k), 10.0 * (1.0 - k) + 2.0, true)
		var bs := 120.0 * (1.0 + 0.2 * sin(k * PI))
		HalliArt.draw_bell(self, Rect2(r.pos - Vector2(bs, bs) / 2.0, Vector2(bs, bs)), k < 0.2)

	if not _banner.is_empty():
		_draw_banner()


func _draw_turn_border(full: Rect2) -> void:
	if not my_turn:
		return
	var inset := full.grow(-BORDER_W / 2.0)
	if ready_frac >= 1.0:
		var a := 0.75 + 0.25 * sin(_pulse * 5.0)
		var sb := StyleBoxFlat.new()
		sb.draw_center = true
		sb.bg_color = Color(color, 0.08)
		sb.border_color = Color(color, a)
		sb.set_border_width_all(int(BORDER_W))
		sb.set_corner_radius_all(28)
		draw_style_box(sb, full)
		return
	# Enchendo durante o intervalo entre viradas: contorno parcial, começando no topo.
	var pts := _perimeter(inset, ready_frac)
	var base := StyleBoxFlat.new()
	base.draw_center = false
	base.border_color = Color(color, 0.18)
	base.set_border_width_all(int(BORDER_W))
	base.set_corner_radius_all(28)
	draw_style_box(base, full)
	if pts.size() >= 2:
		draw_polyline(pts, color, BORDER_W, true)


static func _perimeter(r: Rect2, frac: float) -> PackedVector2Array:
	var corners := [Vector2(r.get_center().x, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position, Vector2(r.get_center().x, r.position.y)]
	var total := 2.0 * (r.size.x + r.size.y)
	var left := total * clampf(frac, 0.0, 1.0)
	var out := PackedVector2Array([corners[0]])
	for i in range(1, corners.size()):
		var seg: float = corners[i - 1].distance_to(corners[i])
		if left >= seg:
			out.append(corners[i])
			left -= seg
		else:
			out.append(corners[i - 1].lerp(corners[i], left / seg))
			break
	return out


func _draw_banner() -> void:
	var k: float = _banner.age / _banner.dur
	var a := clampf(minf(k * 8.0, (1.0 - k) * 5.0), 0.0, 1.0)
	var pop := 1.0 + 0.12 * maxf(0.0, 1.0 - k * 6.0)
	var w := size.x - 80.0
	var h := 190.0 if _banner.sub != "" else 140.0
	var r := Rect2(Vector2(40, size.y * 0.42 - h / 2.0), Vector2(w, h))
	draw_set_transform(r.get_center(), 0.0, Vector2(pop, pop))
	var rr := Rect2(-r.size / 2.0, r.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_banner.color, a)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(Tokens.TINTA, 0.2 * a)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	sb.anti_aliasing = true
	draw_style_box(sb, rr)
	var fg := Color(Tokens.on(_banner.color), a)
	_center_text(Fonts.title_bold(), _banner.text, Vector2(0, -18 if _banner.sub != "" else 0), 56, fg)
	if _banner.sub != "":
		_center_text(Fonts.body_bold(), _banner.sub, Vector2(0, 48), 24, fg)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _center_text(font: Font, text: String, center: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := center.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(center.x - w / 2.0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
