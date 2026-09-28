class_name PegPalette
extends Control
## Paleta de símbolos do Senha: tocar num símbolo põe na primeira vaga livre da linha atual.

signal picked(s: int)

var symbols := 6
var look := "cores"
var disabled := false
## Símbolos que não dá pra usar agora (Fácil: já está na linha).
var blocked: Array = []
var max_peg := 64.0
var gap := 10.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _per_row() -> int:
	return symbols if symbols <= 6 else 4


func _cell() -> float:
	var n := _per_row()
	return minf(max_peg, (size.x - gap * (n - 1)) / n)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var rows := int(ceil(symbols / float(_per_row())))
		var h := rows * _cell() + (rows - 1) * gap
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h


func _center(i: int) -> Vector2:
	var n := _per_row()
	var cell := _cell()
	var row := i / n
	var in_row := mini(n, symbols - row * n)
	var x0 := (size.x - (in_row * cell + (in_row - 1) * gap)) / 2.0
	return Vector2(x0 + (i % n) * (cell + gap) + cell / 2.0, row * (cell + gap) + cell / 2.0)


func _gui_input(event: InputEvent) -> void:
	if disabled or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in symbols:
		if event.position.distance_to(_center(i)) <= _cell() / 2.0 + gap / 2.0:
			if i in blocked:
				return
			Haptics.tap()
			Audio.sfx("tap")
			picked.emit(i)
			accept_event()
			return


func _draw() -> void:
	var cell := _cell()
	for i in symbols:
		var c := _center(i)
		var off := disabled or i in blocked
		draw_circle(c + Vector2(0, 3), cell * 0.47, Color(Tokens.SHADOW_COLOR, 0.12 if off else 0.2))
		SenhaArt.draw_peg(self, c, cell * 0.45, i, look, off)
