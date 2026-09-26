class_name Avatar
extends Control
## Círculo com a cor do time e a inicial do nome.

var player_name := "":
	set(v):
		player_name = v
		queue_redraw()
var color := Tokens.AZUL:
	set(v):
		color = v
		queue_redraw()
var connected := true:
	set(v):
		connected = v
		queue_redraw()
var diameter := 48.0


func _init(p_name := "", p_color := Tokens.AZUL, p_diameter := 48.0) -> void:
	player_name = p_name
	color = p_color
	diameter = p_diameter
	custom_minimum_size = Vector2(p_diameter, p_diameter)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := diameter / 2.0
	var c := Vector2(r, r)
	var fill := color if connected else Tokens.DESABILITADO
	draw_circle(c, r, Tokens.TINTA, true, -1.0, true)
	draw_circle(c, r - Tokens.BORDER, fill, true, -1.0, true)
	var initial := player_name.strip_edges().left(1).to_upper()
	if initial == "":
		initial = "?"
	var font := Fonts.title_bold()
	var fs := int(diameter * 0.5)
	var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := r + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_string(font, Vector2(r - w / 2.0, baseline), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.TINTA)
	if not connected:
		# Indicador de desconectado: bolinha rosa no canto.
		draw_circle(Vector2(diameter - 7, 7), 8, Tokens.TINTA, true, -1.0, true)
		draw_circle(Vector2(diameter - 7, 7), 5, Tokens.ROSA, true, -1.0, true)
