extends Control
## Raiz do app: fundo, área segura (notch/barra de gestos), telas e camada de avisos.

const SplashScreen := preload("res://app/screens/splash_screen.gd")
## Ferramentas de desenvolvimento (ficam fora do export; por isso são carregadas pelo caminho,
## nunca pelo nome da classe — senão este script não compila no app instalado).
const DEV_TOOLS := {"--bot=": "res://tools/net_bot.gd", "--hbot=": "res://tools/halli_bot.gd", "--abot=": "res://tools/avalon_bot.gd", "--sbot=": "res://tools/sh_bot.gd", "--pbot=": "res://tools/party_bot.gd", "--qbot=": "res://tools/quem_foi_bot.gd", "--cbot=": "res://tools/coup_bot.gd", "--tour=": "res://tools/dev_tour.gd"}

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
	if _start_dev_tool():
		return
	App.push(SplashScreen.new())
	App.check_deep_link()


func _start_dev_tool() -> bool:
	for a in OS.get_cmdline_user_args():
		for prefix in DEV_TOOLS:
			if a.begins_with(prefix) and ResourceLoader.exists(DEV_TOOLS[prefix]):
				load(DEV_TOOLS[prefix]).start(self)
				return true
	return false


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


## Fundo de papel creme com fibras e grãos bem sutis.
class Background extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tokens.PAPEL)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		# Grãos
		var n := int(size.x * size.y / 900.0)
		for i in n:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var dark := rng.randf() < 0.6
			var c := Color(Tokens.TINTA, rng.randf_range(0.025, 0.055)) if dark else Color(1, 1, 1, rng.randf_range(0.25, 0.5))
			draw_rect(Rect2(p, Vector2(rng.randf_range(1.0, 2.2), rng.randf_range(1.0, 2.2))), c)
		# Fibras
		for i in int(n / 30.0):
			var a := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var ang := rng.randf() * TAU
			var len := rng.randf_range(6, 16)
			draw_line(a, a + Vector2(cos(ang), sin(ang)) * len, Color(Tokens.TINTA_SUAVE, 0.06), 1.0, true)
