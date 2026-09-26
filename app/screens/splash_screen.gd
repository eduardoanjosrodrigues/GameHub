extends Screen
## Splash: logo animado (≤ 1,5 s) e segue pro início.

const HomeScreen := preload("res://app/screens/home_screen.gd")


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UI.vbox(12)
	center.add_child(v)
	var hat := UI.texture("chapeu", 180)
	v.add_child(hat)
	var logo := Logo.new(84)
	v.add_child(logo)
	hat.pivot_offset = Vector2(90, 90)
	hat.scale = Vector2(0.2, 0.2)
	logo.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hat, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): App.replace(HomeScreen.new()))
