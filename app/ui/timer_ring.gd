class_name TimerRing
extends Control
## Cronômetro: anel fino sobre um disco de papel, números serifados.
## Nos últimos 10 s o anel fica vermelho e o disco pulsa de leve.

var total_ms := 60000
var remaining_ms := 60000:
	set(v):
		remaining_ms = max(0, v)
		queue_redraw()
var diameter := 180.0
var _pulse := 0.0


func _init(p_diameter := 180.0) -> void:
	diameter = p_diameter
	custom_minimum_size = Vector2(p_diameter, p_diameter)
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if remaining_ms <= 10000 and remaining_ms > 0:
		_pulse = fmod(_pulse + delta * 2.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var d: float = min(size.x, size.y)
	var r := d / 2.0
	var c := size / 2.0
	var urgent := remaining_ms <= 10000
	var k := 1.0
	if urgent and remaining_ms > 0:
		k = 1.0 + 0.025 * sin(_pulse * TAU)
	var rr := r * k
	# Sombra difusa + disco de papel.
	for i in 6:
		draw_circle(c + Vector2(0, 4), rr + 6 - i, Color(Tokens.TINTA, 0.018), true, -1.0, true)
	draw_circle(c, rr, Tokens.SUPERFICIE, true, -1.0, true)
	var ring_w := d * 0.055
	var arc_r := rr - ring_w - 6
	draw_arc(c, arc_r, 0, TAU, 96, Tokens.LINHA, ring_w, true)
	var frac := clampf(float(remaining_ms) / float(max(total_ms, 1)), 0.0, 1.0)
	var col := Tokens.VERMELHO if urgent else Tokens.TINTA
	if frac > 0.0:
		draw_arc(c, arc_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 96, col, ring_w, true)
		var tip := c + Vector2(cos(-PI / 2.0 + TAU * frac), sin(-PI / 2.0 + TAU * frac)) * arc_r
		draw_circle(tip, ring_w * 0.9, col, true, -1.0, true)
	var secs := str(int(ceil(remaining_ms / 1000.0)))
	var font := Fonts.display()
	var fs := int(d * 0.36)
	var w := font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(c.x - w / 2.0, baseline), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.VERMELHO_ESCURO if urgent else Tokens.TINTA)
