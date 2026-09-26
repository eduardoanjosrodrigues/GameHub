extends Node
## Vibração (docs/PLANO_FASE_1.md §9.4 e PLANO_HALLI_GALLI.md §6), respeitando a configuração.


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


## Sequência de pulsos: [[ms, amplitude, pausa depois em ms], ...].
func pattern(steps: Array) -> void:
	var at := 0.0
	for s in steps:
		var ms: int = s[0]
		var amp: float = s[1]
		if at <= 0.0:
			_vibrate(ms, amp)
		else:
			get_tree().create_timer(at).timeout.connect(func(): _vibrate(ms, amp))
		at += (ms + (s[2] if s.size() > 2 else 0)) / 1000.0


# --- Halli Galli (celular deitado na mesa: tem que dar pra sentir e ouvir) ----

func hg_turn() -> void:
	pattern([[40, 0.8, 70], [40, 0.8]])


func hg_flip() -> void:
	_vibrate(15, 0.5)


func hg_bell_tap() -> void:
	_vibrate(25, 1.0)


func hg_won() -> void:
	_vibrate(200, 1.0)


func hg_wrong() -> void:
	pattern([[45, 1.0, 45], [45, 1.0, 45], [45, 1.0]])


func hg_received() -> void:
	_vibrate(18, 0.35)


func hg_not_turn() -> void:
	_vibrate(10, 0.25)


func hg_out() -> void:
	_vibrate(350, 0.3)


func hg_victory() -> void:
	pattern([[60, 0.8, 60], [60, 0.8, 60], [220, 1.0]])
