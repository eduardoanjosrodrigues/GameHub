class_name DesafioStatsScreen
extends Screen
## Estatísticas do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md §6): um cartão por modo, com jogos,
## % de vitórias, sequência (só no desafio do dia) e o gráfico de tentativas.
## sections: [{key, title, daily: bool, tries: int}]

var title_text := "Estatísticas"
var sections: Array = []


func _init(p_title: String, p_sections: Array) -> void:
	super()
	title_text = p_title
	sections = p_sections


func _ready() -> void:
	var col := make_column()
	make_header(col, title_text)
	var today := Desafio.day_index()
	for s in sections:
		col.add_child(_section(s, DesafioStore.stats(s.key, today)))


func _section(s: Dictionary, st: Dictionary) -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var v := UI.vbox(14)
	c.add_child(v)
	v.add_child(UI.label(s.title, 24, Tokens.TINTA, Fonts.title()))
	var nums := UI.hbox(8)
	var pct := int(round(100.0 * st.won / st.played)) if st.played > 0 else 0
	var cells := [[str(st.played), "jogos"], ["%d%%" % pct, "vitórias"]]
	if s.daily:
		cells.append([str(st.streak), "sequência"])
		cells.append([str(st.best), "melhor"])
	else:
		cells.append([str(st.won), "acertos"])
	for cell in cells:
		var cv := UI.vbox(0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(UI.label(cell[0], 34, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.label(cell[1], 14, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		nums.add_child(cv)
	v.add_child(nums)
	if st.played == 0:
		v.add_child(UI.caption("Nenhuma partida ainda."))
		return c
	v.add_child(UI.label("Acertou em quantas tentativas", 16, Tokens.TINTA_SUAVE, Fonts.body_bold()))
	var most := 1
	for n in range(1, int(s.tries) + 1):
		most = maxi(most, int(st.dist.get(str(n), 0)))
	for n in range(1, int(s.tries) + 1):
		v.add_child(_bar(n, int(st.dist.get(str(n), 0)), most))
	return c


func _bar(n: int, count: int, most: int) -> Control:
	var row := UI.hbox(10)
	var l := UI.label(str(n), 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 24
	row.add_child(l)
	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size.y = 28
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(func():
		var w := maxf(34.0, track.size.x * count / float(most))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tokens.SALVIA if count > 0 else Tokens.DESABILITADO
		sb.set_corner_radius_all(8)
		track.draw_style_box(sb, Rect2(0, 0, w, track.size.y))
		var f := Fonts.body_bold()
		var t := str(count)
		var sz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		track.draw_string(f, Vector2(w - sz.x - 10, track.size.y / 2.0 + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tokens.SUPERFICIE if count > 0 else Tokens.TINTA_SUAVE))
	row.add_child(track)
	return row
