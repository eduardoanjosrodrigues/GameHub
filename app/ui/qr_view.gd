class_name QrView
extends Control
## Mostra um QR code num cartão branco com contorno cartoon.

var qr: QrCode
var diameter := 260.0


func _init(text: String, p_size := 260.0) -> void:
	qr = QrCode.encode(text)
	diameter = p_size
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = min(size.x, size.y)
	var origin := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var card := StyleBoxFlat.new()
	card.bg_color = Tokens.BRANCO
	card.border_color = Tokens.TINTA
	card.set_border_width_all(Tokens.BORDER)
	card.set_corner_radius_all(Tokens.RADIUS_CARD)
	card.anti_aliasing = true
	var shadow := card.duplicate() as StyleBoxFlat
	shadow.bg_color = Tokens.TINTA
	draw_style_box(shadow, Rect2(origin + Vector2(0, Tokens.SHADOW), Vector2(s, s)))
	draw_style_box(card, Rect2(origin, Vector2(s, s)))
	if qr == null:
		return
	# Zona de silêncio de ~3 módulos dentro do cartão.
	var cell := floorf(s / float(qr.size + 6))
	var total := cell * qr.size
	var o := origin + Vector2((s - total) / 2.0, (s - total) / 2.0).floor()
	for y in qr.size:
		for x in qr.size:
			if qr.is_dark(y, x):
				draw_rect(Rect2(o + Vector2(x * cell, y * cell), Vector2(cell, cell)), Tokens.TINTA)
