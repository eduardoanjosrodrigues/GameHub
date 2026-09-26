extends Control
## Raiz do app: fundo, área segura (notch/barra de gestos), telas e camada de avisos.

const SplashScreen := preload("res://app/screens/splash_screen.gd")

var _safe: MarginContainer
var _host: Control
var _overlay: Control


func _ready() -> void:
	get_tree().root.theme = ThemeBuilder.build()

	var bg := Background.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)

	_host = Control.new()
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.clip_contents = true
	_safe.add_child(_host)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

	App.register_main(self, _host, _overlay)
	if NetBot.requested():
		NetBot.start(self)
		return
	if DevTour.requested():
		DevTour.start(self)
		return
	App.push(SplashScreen.new())
	App.check_deep_link()


func _update_safe_area() -> void:
	var margins := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var vp := get_viewport_rect().size
		if screen.x > 0 and screen.y > 0:
			var k := vp.x / float(screen.x)
			margins.left = int(safe.position.x * k)
			margins.top = int(safe.position.y * k)
			margins.right = int((screen.x - safe.end.x) * k)
			margins.bottom = int((screen.y - safe.end.y) * k)
	for side in margins:
		_safe.add_theme_constant_override("margin_" + side, margins[side])


## Fundo gelo com bolinhas e confetes estáticos bem suaves.
class Background extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tokens.GELO)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var colors := [Tokens.AZUL, Tokens.TURQUESA, Tokens.LIMA, Tokens.ROSA]
		var step := 120.0
		var y := 40.0
		while y < size.y + step:
			var x := 30.0 + fmod(y * 0.37, step)
			while x < size.x + step:
				var c: Color = colors[rng.randi() % colors.size()]
				c.a = 0.10
				var p := Vector2(x + rng.randf_range(-25, 25), y + rng.randf_range(-25, 25))
				if rng.randf() < 0.5:
					draw_circle(p, rng.randf_range(5, 9), c, true, -1.0, true)
				else:
					draw_set_transform(p, rng.randf() * TAU, Vector2.ONE)
					draw_rect(Rect2(-8, -4, 16, 8), c)
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				x += step
			y += step
