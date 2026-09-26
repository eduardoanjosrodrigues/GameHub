extends Screen
## Como jogar: as regras em cartões ilustrados.


func _ready() -> void:
	var col := make_column()
	make_header(col, "Como jogar")
	col.add_child(_step("1. Palavras no chapéu", "Cada jogador escreve algumas palavras ou nomes em segredo (ou o app sorteia de uma lista pronta).", "chapeu", Tokens.SUPERFICIE))
	col.add_child(_step("2. Dois times", "Time Azul e Time Vermelho. Na sua vez, o time escolhe quem vai explicar e tem 60 segundos pra acertar o máximo que der. O Time Azul começa.", "people", Tokens.SUPERFICIE))
	col.add_child(UI.label("3. Três rodadas com as mesmas palavras", 24, Tokens.TINTA, Fonts.title()))
	for key in ["descrever", "uma_palavra", "mimica"]:
		var r: Dictionary = ChapeuText.round_info(key)
		col.add_child(_step(r.nome, r.regra, r.icone, r.cor))
	col.add_child(_step("Pontos", "Acertou: +1. Pulou: −1 (a palavra volta pro chapéu). Se o chapéu esvaziar no meio da sua vez, você começa a próxima rodada com o tempo que sobrou.", "check", Tokens.MOSTARDA))
	col.add_child(_step("Quem vence", "Mais pontos no total. Se empatar, vence quem ganhou mais rodadas; se ainda empatar, quem fez mais na mímica.", "trophy", Tokens.SUPERFICIE))


func _step(title_text: String, body: String, icon_name: String, color: Color) -> Control:
	var c := UI.card(color, 20)
	var row := UI.hbox(16)
	c.add_child(row)
	var colored := icon_name in ["chapeu", "rodada_descrever", "rodada_uma_palavra", "rodada_mimica"]
	var ic := UI.texture(icon_name, 72, Color.WHITE if colored else Tokens.TINTA)
	row.add_child(ic)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title_text, 22, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label(body, 17, Tokens.TINTA, Fonts.body()))
	row.add_child(v)
	return c
