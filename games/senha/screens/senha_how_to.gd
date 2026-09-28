extends PartyHowTo
## Como jogar o Senha.


func _init() -> void:
	super()
	steps = [
		["A ideia", "Descubra a senha secreta: uma sequência de pinos (cores ou números) em até 10 tentativas.", Tokens.tint(Tokens.MOSTARDA, 0.4)],
		["Retorno por contagem", "Depois de cada palpite aparecem bolinhas: cheia é um pino certo no lugar certo; vazada é um pino certo no lugar errado. Elas não dizem quais pinos são. É o clássico."],
		["Retorno por posição", "Mais fácil: cada pino fica verde (lugar certo), amarelo (existe em outro lugar) ou cinza (não existe), como no Wordle."],
		["Níveis", "Fácil: 4 pinos, 6 símbolos, sem repetir. Médio: 4 pinos, 6 símbolos, pode repetir. Difícil: 5 pinos, 8 símbolos, pode repetir."],
		["Senha do dia", "Uma senha por nível, por dia, igual pra todo mundo. Cada nível tem a sua sequência de vitórias.", Tokens.tint(Tokens.SALVIA, 0.3)],
		["Duelo no Wi-Fi", "1 contra 1: cada um cria a senha do outro. Alternado: um palpite por vez, e se quem começou acertar, o outro ainda tem a última chance. Modo tempo: os dois ao mesmo tempo, vence quem quebrar primeiro.", Tokens.tint(Tokens.AZUL, 0.25)],
		["Corrida no Wi-Fi", "Todos tentam a mesma senha. O host escolhe quem vence: menos tentativas, primeiro a acertar ou pontos em várias rodadas."],
		["Daltonismo", "Cada cor tem também uma forma desenhada no pino. Ou jogue com números."],
	]
	footer = "Baseado no Mastermind, de Mordecai Meirowitz, e no jogo de papel Bulls and Cows."
