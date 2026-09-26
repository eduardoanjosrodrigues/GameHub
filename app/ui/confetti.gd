class_name Confetti
extends Control
## Chuva de papeizinhos (retângulos de papel colorido que giram e caem). Some sozinha.

const COLORS := [Tokens.MOSTARDA, Tokens.SALVIA, Tokens.AZUL, Tokens.VERMELHO, Tokens.SUPERFICIE]

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
		var ang := rng.randf_range(-PI * 0.92, -PI * 0.08)
		var spd := rng.randf_range(380, 820)
		c._bits.append({
			"p": origin,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"rot": rng.randf() * TAU,
			"vr": rng.randf_range(-7, 7),
			"flip": rng.randf() * TAU,
			"s": Vector2(rng.randf_range(10, 16), rng.randf_range(14, 22)),
			"c": colors[rng.randi() % colors.size()],
		})
	return c


func _process(delta: float) -> void:
	_life += delta
	for b in _bits:
		b.v.y += 1300 * delta
		b.v *= 0.985
		b.p += b.v * delta
		b.rot += b.vr * delta
		b.flip += delta * 9.0
	queue_redraw()
	if _life > _duration:
		queue_free()


func _draw() -> void:
	var alpha := clampf((_duration - _life) / 0.5, 0.0, 1.0)
	for b in _bits:
		# "Virar" o papel: escala horizontal oscila, como um papel caindo.
		var sx := absf(cos(b.flip)) * 0.8 + 0.2
		draw_set_transform(b.p, b.rot, Vector2(sx, 1))
		var r := Rect2(-b.s / 2.0, b.s)
		draw_rect(r.grow(1), Color(Tokens.TINTA, 0.12 * alpha))
		draw_rect(r, Color(b.c, alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
