extends PartyMenu
## Menu do Ito.

const THEMES := "res://games/ito/data/temas.txt"


func _init() -> void:
	super()
	info = {
		"id": "ito",
		"name": "Ito",
		"icon": "ito",
		"desc": "Cada um tem um número secreto de 1 a 100. Falem do tema sem dizer números e montem juntos a fila em ordem. Cooperativo, de 2 a 10 pessoas.",
		"local_desc": "O celular passa pra cada um ver o número e depois fica no meio da mesa",
		"board_desc": "Ideal pra um tablet no meio da mesa: mostra o tema, a fila e as vidas. Ele não joga. Uma TV ou notebook também pode ser o tabuleiro, pelo navegador.",
		"rules": func(): return ItoRules.new(ThemeBank.load_file(THEMES)),
		"game": "res://games/ito/screens/ito_game.gd",
		"how_to": "res://games/ito/screens/ito_how_to.gd",
	}
