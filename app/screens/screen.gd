class_name Screen
extends Control
## Base de todas as telas. As telas montam a interface em código no _ready.

## Trilha desta tela: "menu", "turn" ou "" (silêncio).
var music := "menu"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Chamado no botão voltar do Android. Retorne true se a tela tratou sozinha.
func on_back() -> bool:
	return false


## Monta a estrutura padrão: coluna centralizada com largura máxima e rolagem.
## Retorna a VBox onde o conteúdo vai.
func make_column(with_scroll := true, pad := 32, sep := 20) -> VBoxContainer:
	var mw := MaxWidth.new()
	mw.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mw)
	var m := UI.margin(pad, pad - 8, pad)
	var col := UI.vbox(sep)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if with_scroll:
		var s := UI.scroll()
		mw.add_child(s)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.size_flags_vertical = Control.SIZE_EXPAND_FILL
		s.add_child(m)
	else:
		mw.add_child(m)
	m.add_child(col)
	return col


## Cabeçalho com botão voltar e título.
func make_header(parent: Control, title_text: String, on_back_pressed := Callable()) -> HBoxContainer:
	var row := UI.hbox(16)
	var back := UI.icon_button("back", on_back_pressed if on_back_pressed.is_valid() else func(): App.back())
	row.add_child(back)
	var t := UI.title(title_text, 34, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	parent.add_child(row)
	return row
