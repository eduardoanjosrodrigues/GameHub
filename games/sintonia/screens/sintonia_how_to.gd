extends PartyHowTo
## Como jogar a Sintonia.


func _init() -> void:
	super()
	steps = [
		["A ideia", "Um disco vai de um extremo a outro (tipo Frio – Quente). Uma pessoa vê onde está o alvo e dá uma dica pro time acertar com a agulha.", Tokens.tint(Tokens.MOSTARDA, 0.45)],
		["1. Quem dá a dica", "Vê o alvo, escondido dos outros, e escolhe um de dois temas (ou digita outro). Fala uma dica em voz alta: com Frio – Quente e o alvo quase na direita, \"café de padaria\"."],
		["2. O time gira", "Todo mundo do time pode arrastar a agulha, e todos veem ela se mexer. Discutam! Quando concordarem, travem. Quem deu a dica não ajuda."],
		["3. Pontos", "Centro: 4 pontos. Do lado do centro: 3. Na borda: 2. Fora: nada. Se cair na linha, vale a faixa melhor."],
		["Times", "O outro time aposta se o centro do alvo está à esquerda ou à direita da agulha: acertando, 1 ponto (menos quando a agulha caiu no centro). O time que começa depois já tem 1 ponto. Fez 4 e continua perdendo? Joga de novo. Ganha quem chegar a 10; empate em 10 vai pra morte súbita.", Tokens.tint(Tokens.AZUL, 0.3)],
		["Cooperativo", "Todos juntos, 7 rodadas, sem aposta. O centro vale 3 e dá uma rodada extra. No fim, a nota do grupo: 16 ou mais é vitória!", Tokens.tint(Tokens.SALVIA, 0.35)],
	]
	footer = "Baseado em Wavelength, de Alex Hague, Justin Vickers e Wolfgang Warsch. Temas escritos pra este app."
