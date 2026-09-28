class_name WordleNetRules
extends RaceRules
## Corrida do Wordle (docs/PLANO_WORDLE_SENHA.md §5): todos tentam a mesma palavra de 5 letras em 6
## tentativas. O host confere no dicionário; o modo difícil vale pra todos se o host ligar (§3.3).
## A palavra sai do treino: nunca a do dia, nem uma já usada nesta sala.

const TRIES := 6

var secret := "" # sem acento
var _used: Array = []


func _init(seed_value := -1) -> void:
	super(seed_value)
	config.dificil = false


func _jogo_new_secret() -> void:
	secret = WordleWords.norm(WordleWords.random_training(rng, Desafio.day_index(), 1, _used)[0])
	_used.append(secret)


func _jogo_check(board: Dictionary, a: Dictionary) -> Dictionary:
	var n := WordleWords.norm(str(a.get("word", "")))
	if n.length() != WordleWords.LENGTH:
		return {"error": "A palavra tem %d letras." % WordleWords.LENGTH}
	if not WordleWords.is_valid(n):
		return {"error": "Palavra não aceita"}
	if config.dificil:
		var why := WordleLogic.hard_violation(n, board.guesses.map(func(g): return {"n": g.g, "c": g.c}))
		if why != "":
			return {"error": why}
	return {"g": n, "w": WordleWords.display(n)}


func _jogo_colors(g) -> Array:
	return WordleLogic.score(g, secret)


func _jogo_solved(c: Array) -> bool:
	return WordleLogic.solved(c)


func _jogo_quality(c: Array) -> int:
	return WordleLogic.quality(c)


func _jogo_max_tries() -> int:
	return TRIES


func _jogo_secret_view():
	return WordleWords.display(secret)


func _jogo_config(a: Dictionary) -> void:
	if a.has("dificil"):
		config.dificil = bool(a.dificil)
