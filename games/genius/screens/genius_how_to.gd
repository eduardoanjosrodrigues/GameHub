extends PartyHowTo
## Como jogar o Genius.


func _init() -> void:
	super()
	steps = [
		["Olhe e escute", "O Genius acende uma cor com o som dela. Depois é a sua vez: toque a mesma cor.", Tokens.tint(Tokens.SALVIA, 0.3)],
		["Uma cor a mais", "Acertou? Ele toca tudo de novo e junta mais uma cor no fim. A sequência vai crescendo e fica mais rápida depois da 5ª e da 13ª cor."],
		["Errou, acabou", "Tocou a cor errada: o Genius faz o som de erro e pisca a cor certa. Seu placar é o tamanho da maior sequência que você acertou. Não tem pressa pra tocar."],
		["Passa o aparelho", "Um celular só. Cada um, na sua vez, repete a sequência. Acertou, ela ganha uma cor e vai pro próximo. Errou, sai, e o próximo recebe a mesma sequência. Ganha quem sobrar.", Tokens.tint(Tokens.MOSTARDA, 0.3)],
		["Corrida no Wi-Fi", "Cada um no seu celular (ou no navegador). A sequência toca junto pra todos, e cada um repete. Quem errar sai; se todos errarem na mesma rodada, ninguém sai e ela se repete. Ganha quem sobrar.", Tokens.tint(Tokens.AZUL, 0.25)],
	]
	footer = "Inspirado no Genius, da Estrela (Simon, de Ralph Baer e Howard Morrison)."
