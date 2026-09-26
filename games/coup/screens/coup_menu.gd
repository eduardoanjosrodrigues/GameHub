extends PartyMenu
## Menu do Coup.


func _init() -> void:
	super()
	info = {
		"id": "coup",
		"name": "Coup",
		"icon": "coup",
		"desc": "Intriga na corte: cada um tem 2 cartas escondidas e pode dizer que é qualquer personagem. Blefe, desafie, bloqueie. O último com influência vence. De 2 a 6 pessoas.",
		"board_desc": "Ideal pra um tablet no meio da mesa: mostra as moedas, as cartas perdidas, a ação da vez e os desafios. Ele não joga. Uma TV ou notebook também pode ser o tabuleiro, pelo navegador.",
		"host": func(role: String, n: String): return CoupHost.new(role, n),
		"cover": func(): return CoupArt.art("capa"),
		"game": "res://games/coup/screens/coup_game.gd",
		"how_to": "res://games/coup/screens/coup_how_to.gd",
	}
