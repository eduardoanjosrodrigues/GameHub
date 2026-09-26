extends PartyMenu
## Menu da Sintonia.

const THEMES := "res://games/sintonia/data/temas.txt"


func _init() -> void:
	super()
	info = {
		"id": "sintonia",
		"name": "Sintonia",
		"icon": "sintonia",
		"desc": "Uma pessoa vê o alvo e dá uma dica entre dois extremos. O time gira a agulha pra acertar. Em times ou cooperativo, de 2 a 12 pessoas.",
		"local_desc": "Quem dá a dica olha o alvo escondido; depois o celular fica no meio da mesa",
		"board_desc": "Ideal pra um tablet no meio da mesa: mostra o disco grande, a agulha ao vivo e o placar. Ele não joga. Uma TV ou notebook também pode ser o tabuleiro, pelo navegador.",
		"rules": func(): return SintoniaRules.new(ThemeBank.load_file(THEMES)),
		"game": "res://games/sintonia/screens/sintonia_game.gd",
		"how_to": "res://games/sintonia/screens/sintonia_how_to.gd",
	}
