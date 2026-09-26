extends PartyHowTo
## Como jogar o Ito.


func _init() -> void:
	super()
	var fio := Tokens.tint(ItoArt.FIO, 0.3)
	steps = [
		["Todos no mesmo time", "O Ito é cooperativo: o grupo inteiro ganha ou perde junto.", fio],
		["1. Seu número", "Cada um recebe um número secreto de 1 a 100. Não mostre e não diga o número!"],
		["2. O tema", "O app sorteia dois temas e vocês escolhem um (ou digitam outro). Ex: \"O quão assustador é um animal\". 1 é o mínimo, 100 é o máximo."],
		["3. A dica", "Cada um fala um exemplo do tema que represente o seu número: com 5, \"um gatinho\"; com 90, \"um tubarão\". Pode usar \"muito\", \"meio\", mas nada de números, valores ou quantidades. Se quiser, escreva uma palavra-chave: ela aparece embaixo da sua carta."],
		["4. A fila", "Ponha a sua carta na fila, do menor pro maior. Conversem e mudem as cartas de lugar quantas vezes quiserem: qualquer um pode mexer em qualquer carta."],
		["5. Revelar", "Quando todo mundo concordar, alguém aperta Revelar. Os números aparecem da esquerda pra direita, e cada um menor que algum anterior conta como erro."],
		["Desafio", "Começa com 1 carta cada e 3 vidas. Cada erro custa 1 vida; errou, o nível se repete com números novos. Acertou, uma pessoa ganha +1 carta no próximo nível. Depois que todos tiverem 2 cartas, vem o modo extremo: a fila não mostra de quem é cada carta.", Tokens.tint(Tokens.MOSTARDA, 0.45)],
		["Rodada solta", "Sem vidas: cada rodada vale por si. É pra rir das dicas.", Tokens.tint(Tokens.SALVIA, 0.35)],
	]
	footer = "Baseado em ito, de Mitsuru Nakamura (Arclight). Temas escritos pra este app."
