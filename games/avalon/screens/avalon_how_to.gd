extends Screen
## Como jogar Avalon: as regras em cartões.


func _ready() -> void:
	var col := make_column()
	make_header(col, "Como jogar")
	col.add_child(_step("Bem contra mal", "Os servos leais de Arthur (bem) precisam completar 3 missões. Os lacaios de Mordred (mal) querem que 3 missões falhem. O mal sabe quem é do mal; o bem não sabe de nada.", AvalonArt.BEM))
	col.add_child(_step("1. Seu papel", "No começo, cada um vê o próprio papel no celular. Não mostre pra ninguém.", Tokens.SUPERFICIE))
	col.add_child(_step("2. O líder monta o time", "A cada missão, o líder escolhe quem vai. Todo mundo conversa, acusa e defende.", Tokens.SUPERFICIE))
	col.add_child(_step("3. Todos votam o time", "Aprovar ou rejeitar, em segredo; os votos aparecem todos juntos. Se rejeitarem, a liderança passa. Cinco recusas seguidas: o mal vence.", Tokens.SUPERFICIE))
	col.add_child(_step("4. A missão", "Quem está no time joga Sucesso ou Falha em segredo. Uma Falha já derruba a missão (na 4ª, com 7 ou mais pessoas, precisa de duas). Só o mal pode jogar Falha.", Tokens.SUPERFICIE))
	col.add_child(_step("O Assassino", "Se o bem completar 3 missões, o mal ainda tem uma chance: o Assassino tenta adivinhar quem é Merlin. Acertou, o mal vence.", AvalonArt.MAL))
	col.add_child(UI.label("Personagens", 24, Tokens.TINTA, Fonts.title()))
	for r in ["merlin", "percival", "servo", "assassino", "morgana", "mordred", "oberon", "lacaio"]:
		col.add_child(_step(AvalonArt.role_name(r), AvalonArt.ROLES[r].texto, Tokens.tint(AvalonArt.side_color(AvalonArt.is_good(r)), 0.5)))
	col.add_child(_step("Dama do Lago", "Com 7 ou mais: depois das missões 2, 3 e 4, quem tem a Dama vê em segredo o lado de alguém, e passa a Dama pra essa pessoa.", Color("#1E7F86")))


func _step(title_text: String, body: String, color: Color) -> Control:
	var c := UI.card(color, 20)
	var v := UI.vbox(4)
	c.add_child(v)
	v.add_child(UI.label(title_text, 22, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label(body, 17, Tokens.TINTA, Fonts.body()))
	return c
