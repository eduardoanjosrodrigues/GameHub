class_name QrView
extends Control
## Mostra um QR code num cartão de papel.

var qr: QrCode
var diameter := 260.0


func _init(text: String, p_size := 260.0) -> void:
	qr = QrCode.encode(text)
	diameter = p_size
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = min(size.x, size.y)
	var origin := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var card := ThemeBuilder.card_style(Tokens.SUPERFICIE, 18)
	card.bg_color = Color.WHITE
	draw_style_box(card, Rect2(origin, Vector2(s, s)))
	if qr == null:
		return
	# Zona de silêncio de ~3 módulos dentro do cartão (fundo branco puro ajuda a câmera).
	var cell := floorf(s / float(qr.size + 6))
	var total := cell * qr.size
	var o := origin + Vector2((s - total) / 2.0, (s - total) / 2.0).floor()
	for y in qr.size:
		for x in qr.size:
			if qr.is_dark(y, x):
				draw_rect(Rect2(o + Vector2(x * cell, y * cell), Vector2(cell, cell)), Tokens.TINTA)
