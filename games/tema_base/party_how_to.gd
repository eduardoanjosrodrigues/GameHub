class_name PartyHowTo
extends Screen
## Como jogar da Sintonia e do Ito: passos em cartões. Cada jogo estende e preenche steps:
## [[título, texto, cor], ...].

var title_text := "Como jogar"
var steps: Array = []
var footer := ""


func _ready() -> void:
	var col := make_column()
	make_header(col, title_text)
	for s in steps:
		var c := UI.card(s[2] if s.size() > 2 else Tokens.SUPERFICIE, 20)
		var v := UI.vbox(4)
		c.add_child(v)
		v.add_child(UI.label(s[0], 22, Tokens.TINTA, Fonts.title()))
		v.add_child(UI.label(s[1], 17, Tokens.TINTA, Fonts.body()))
		col.add_child(c)
	if footer != "":
		col.add_child(UI.label(footer, 14, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
