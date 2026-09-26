extends PartyHowTo
## Como jogar o Coup.


func _init() -> void:
	super()
	steps = [
		["Intriga na corte", "Cada um começa com 2 cartas escondidas (a sua influência) e 2 moedas. Perdeu as duas cartas, está fora. Ganha o último que sobrar.", Tokens.tint(CoupArt.COLORS.duque, 0.3)],
		["Na sua vez", "Faça uma ação. Renda (+1) e Ajuda Externa (+2) qualquer um faz. As outras dependem de um personagem, e você pode dizer que tem qualquer um, tendo ou não!"],
		["Os personagens", "Duque: Imposto (+3) e bloqueia a Ajuda Externa. Assassino: paga 3 e tira uma carta de alguém. Capitão: pega 2 moedas de alguém e bloqueia isso. Embaixador: troca cartas com o baralho e bloqueia o Capitão. Condessa: bloqueia o Assassino. Inquisidor (variante): troca 1 carta, examina a carta de alguém e bloqueia o Capitão."],
		["Golpe de Estado", "Pague 7 e alguém perde uma carta, sem defesa. Com 10 moedas, é obrigatório."],
		["Desafiar e bloquear", "Toda ação que dá pra contestar espera 5 segundos: quem quiser aperta Desafiar ou Bloquear. Vale quem apertou primeiro. No bloqueio, todo mundo pode desafiar, mas o jogo só segue quando quem foi bloqueado aceita.", Tokens.tint(Tokens.MOSTARDA, 0.4)],
		["Quem perde", "Desafiou e a pessoa tinha a carta? Você perde uma carta, e ela troca a carta mostrada por outra do baralho. Não tinha? Ela perde e a ação é cancelada. Quem perde escolhe qual carta vira."],
	]
	footer = "Baseado em Coup, de Rikki Tahta (Indie Boards & Cards / La Mame Games). Variante do Inquisidor da expansão Reforma."
