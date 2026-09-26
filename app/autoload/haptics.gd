extends Node
## Vibração (docs/PLANO_FASE_1.md §9.4), respeitando a configuração.


func _vibrate(ms: int, amplitude := -1.0) -> void:
	if not Settings.vibration:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


func tap() -> void:
	_vibrate(20, 0.4)


func hit() -> void:
	_vibrate(40, 0.8)


func skip() -> void:
	_vibrate(30, 0.6)
	get_tree().create_timer(0.09).timeout.connect(func(): _vibrate(30, 0.6))


func countdown_pulse() -> void:
	_vibrate(35, 0.7)


func time_up() -> void:
	_vibrate(400, 1.0)
