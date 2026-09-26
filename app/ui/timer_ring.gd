class_name TimerRing
extends Control
## Cronômetro em anel: esvazia com o tempo e fica rosa pulsando nos últimos 10 s.

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
	var scale_k := 1.0
	if urgent and remaining_ms > 0:
		scale_k = 1.0 + 0.04 * sin(_pulse * TAU)
	var rr := r * scale_k
	var ring_w := d * 0.12
	draw_circle(c + Vector2(0, 5), rr, Tokens.TINTA, true, -1.0, true)
	draw_circle(c, rr, Tokens.TINTA, true, -1.0, true)
	draw_circle(c, rr - Tokens.BORDER, Tokens.BRANCO, true, -1.0, true)
	var frac := clampf(float(remaining_ms) / float(max(total_ms, 1)), 0.0, 1.0)
	var col := Tokens.ROSA if urgent else Tokens.AZUL
	var arc_r := rr - Tokens.BORDER - ring_w / 2.0 - 4
	draw_arc(c, arc_r, 0, TAU, 64, Tokens.GELO, ring_w, true)
	if frac > 0.0:
		draw_arc(c, arc_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 64, col, ring_w, true)
	var secs := str(int(ceil(remaining_ms / 1000.0)))
	var font := Fonts.title_bold()
	var fs := int(d * 0.3)
	var w := font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(c.x - w / 2.0, baseline), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.TINTA)
