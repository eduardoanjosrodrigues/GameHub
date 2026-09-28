extends PartyHowTo
## Como jogar o Wordle.


func _init() -> void:
	super()
	steps = [
		["A ideia", "Descubra a palavra secreta de 5 letras em até 6 tentativas. Cada palpite precisa ser uma palavra que existe.", Tokens.tint(Tokens.SALVIA, 0.3)],
		["As cores", "Verde: a letra está na palavra e no lugar certo. Amarelo: a letra está na palavra, mas em outro lugar. Cinza: a letra não está na palavra."],
		["Letras repetidas", "Se a palavra tem uma letra só uma vez, só uma cópia dela no seu palpite fica colorida. As outras ficam cinza."],
		["Acentos", "Não precisa digitar acento nem cedilha: CANCAO vale CANÇÃO. O acento aparece quando as letras são reveladas."],
		["Palavra do dia", "Uma palavra por dia, a mesma pra todo mundo. Vira à meia-noite. Acertando todo dia, a sequência cresce; pulando um dia, ela zera.", Tokens.tint(Tokens.MOSTARDA, 0.4)],
		["Dueto e Quarteto", "2 ou 4 palavras ao mesmo tempo, com 7 ou 9 tentativas. Cada palpite vale pra todas as grades. No teclado, cada tecla se divide numa cor por grade."],
		["Modo difícil", "As dicas reveladas precisam ser usadas: letra verde fica no mesmo lugar e letra amarela precisa aparecer no palpite."],
		["Corrida no Wi-Fi", "Todos tentam a mesma palavra, cada um no seu celular. O host escolhe quem vence: menos tentativas, primeiro a acertar ou pontos em várias rodadas. Você vê as cores dos outros, mas não as letras.", Tokens.tint(Tokens.AZUL, 0.25)],
	]
	footer = "Baseado em Wordle, de Josh Wardle. Palavras válidas do VERO, o verificador ortográfico do LibreOffice (LGPLv3/MPL)."
