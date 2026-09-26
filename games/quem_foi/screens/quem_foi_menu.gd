extends PartyMenu
## Menu do Quem Foi?.


func _init() -> void:
	super()
	info = {
		"id": "quem_foi",
		"name": "Quem Foi?",
		"icon": "quem_foi",
		"desc": "Acharam um cocô no meio da sala! Jogue seus bichos, passe a culpa pro bicho de alguém e corra pra provar que o seu é inocente. De 3 a 6 pessoas.",
		"board_desc": "Ideal pra um tablet no meio da mesa: mostra a pilha, quem acusou e os cocôs de cada um. Ele não joga. Uma TV ou notebook também pode ser o tabuleiro, pelo navegador.",
		"host": func(role: String, n: String): return QuemFoiHost.new(role, n),
		"cover": func(): return QuemFoiArt.art("capa"),
		"game": "res://games/quem_foi/screens/quem_foi_game.gd",
		"how_to": "res://games/quem_foi/screens/quem_foi_how_to.gd",
	}
