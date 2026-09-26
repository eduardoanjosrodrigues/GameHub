extends PartyHowTo
## Como jogar o Quem Foi?.


func _init() -> void:
	super()
	var coco := Tokens.tint(QuemFoiArt.COCO, 0.25)
	steps = [
		["Um cocô no meio da sala!", "Foi o bicho de alguém. Cada um tem os 6 bichos da sua cor: gato, peixe, tartaruga, coelho, hamster e papagaio. Prove que os seus são inocentes e passe a culpa adiante.", coco],
		["1. Quem começa", "Joga um bicho e acusa outro: \"Não foi o meu gato… acho que foi o coelho de alguém!\". Pode acusar até o mesmo bicho que acabou de jogar."],
		["2. Corrida!", "Quem ainda tem o bicho acusado corre pra achar e tocar nele no celular. A mão embaralha a cada acusação, e tocar no bicho errado trava você por 1 segundo. Quem acusou não corre."],
		["3. Passe a culpa", "Quem jogou primeiro acusa o próximo bicho. E assim segue. Quem joga o último bicho está a salvo nessa rodada."],
		["4. Quem foi?", "Se ninguém mais tem o bicho acusado, o culpado é o último bicho jogado: o dono leva um cocô. Se só uma pessoa ainda tem bichos, ela leva o cocô. Lembre quais bichos já saíram!"],
		["Fim", "Quando alguém chega a 3 cocôs, acaba (o host pode mudar na sala). Ganha quem tiver menos; empate divide a vitória.", Tokens.tint(Tokens.SALVIA, 0.35)],
	]
	footer = "Baseado em Who Did It? (Quem Foi?), de Jonathan Favre-Godal, Blue Orange / PaperGames."
