extends Screen
## Como jogar Secret Hitler: as regras em cartões, e os créditos (licença CC BY-NC-SA 4.0).


func _ready() -> void:
	var col := make_column()
	make_header(col, "Como jogar")
	col.add_child(_step("Liberais contra fascistas", "Os liberais são maioria, mas ninguém sabe quem é quem. Os fascistas se conhecem e sabem quem é o Hitler. Liberais vencem com 5 leis liberais ou executando o Hitler. Fascistas vencem com 6 leis fascistas ou elegendo o Hitler chanceler depois de 3 leis fascistas.", Tokens.tint(ShArt.LIBERAL, 0.4)))
	col.add_child(_step("1. Seu papel", "No começo, cada um vê o próprio papel no celular. Não mostre pra ninguém.", Tokens.SUPERFICIE))
	col.add_child(_step("2. O presidente indica um chanceler", "A presidência passa pela mesa. O último presidente e o último chanceler eleitos não podem ser o próximo chanceler (com 5 vivos, só o último chanceler).", Tokens.SUPERFICIE))
	col.add_child(_step("3. Todos votam o governo", "Ja! ou Nein, em segredo; os votos aparecem todos juntos, com o nome de cada um. Se o governo cair, o marcador de eleições sobe. Com 3 eleições fracassadas seguidas, a lei do topo do baralho entra direto (caos).", Tokens.SUPERFICIE))
	col.add_child(_step("4. A sessão legislativa", "O presidente recebe 3 leis, descarta 1 e passa 2 pro chanceler, que aprova 1. Ninguém mais vê. Depois cada um conta o que recebeu, e pode mentir.", Tokens.SUPERFICIE))
	col.add_child(_step("5. Poderes", "Algumas leis fascistas dão um poder ao presidente, que depende de quantos estão jogando: investigar o partido de alguém, espiar o baralho, escolher o próximo presidente ou executar alguém. Com 5 leis fascistas, o governo pode vetar.", Tokens.tint(ShArt.FASCISTA, 0.35)))
	col.add_child(UI.label("Papéis", 24, Tokens.TINTA, Fonts.title()))
	for r in ["liberal", "fascista", "hitler"]:
		col.add_child(_step(ShArt.role_name(r), ShArt.ROLES[r].texto, Tokens.tint(ShArt.party_color(ShArt.is_liberal(r)), 0.45)))
	col.add_child(UI.label("Adaptação de Secret Hitler, de Goat, Wolf & Cabbage, licenciado CC BY-NC-SA 4.0. Uso não comercial.", 14, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))


func _step(title_text: String, body: String, color: Color) -> Control:
	var c := UI.card(color, 20)
	var v := UI.vbox(4)
	c.add_child(v)
	v.add_child(UI.label(title_text, 22, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label(body, 17, Tokens.TINTA, Fonts.body()))
	return c
