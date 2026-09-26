class_name Confetti
extends Control
## Chuva de confete desenhada em código. Some sozinha depois de alguns segundos.

const COLORS := [Tokens.LIMA, Tokens.TURQUESA, Tokens.AZUL, Tokens.ROSA]

var _bits := []
var _life := 0.0
var _duration := 2.2


static func burst(parent: Control, origin: Vector2, count := 40, colors: Array = COLORS, duration := 2.2) -> Confetti:
	var c := Confetti.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._duration = duration
	parent.add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var ang := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var spd := rng.randf_range(420, 900)
		c._bits.append({
			"p": origin,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"rot": rng.randf() * TAU,
			"vr": rng.randf_range(-8, 8),
			"s": Vector2(rng.randf_range(10, 18), rng.randf_range(6, 11)),
			"c": colors[rng.randi() % colors.size()],
		})
	return c


func _process(delta: float) -> void:
	_life += delta
	for b in _bits:
		b.v.y += 1500 * delta
		b.v.x *= 0.99
		b.p += b.v * delta
		b.rot += b.vr * delta
	queue_redraw()
	if _life > _duration:
		queue_free()


func _draw() -> void:
	var alpha := clampf((_duration - _life) / 0.5, 0.0, 1.0)
	for b in _bits:
		draw_set_transform(b.p, b.rot, Vector2.ONE)
		var r := Rect2(-b.s / 2.0, b.s)
		draw_rect(r.grow(2), Color(Tokens.TINTA, alpha))
		draw_rect(r, Color(b.c, alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
