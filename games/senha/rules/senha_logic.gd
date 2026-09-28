class_name SenhaLogic
extends RefCounted
## Regras de um palpite do Senha (docs/PLANO_WORDLE_SENHA.md §4). A senha e os palpites são listas
## de símbolos 0..n-1 (a aparência, cores ou números, é só desenho).
##   Retorno "contagem": [certos no lugar, certos fora do lugar], sem dizer quais.
##   Retorno "posicao": uma cor por pino, como no Wordle.

const TRIES := 10
const LEVELS := {
	"facil": {"name": "Fácil", "pins": 4, "symbols": 6, "repeat": false},
	"medio": {"name": "Médio", "pins": 4, "symbols": 6, "repeat": true},
	"dificil": {"name": "Difícil", "pins": 5, "symbols": 8, "repeat": true},
}
const LEVEL_ORDER := ["facil", "medio", "dificil"]
const FEEDBACKS := {"contagem": "Contagem", "posicao": "Por posição"}
const LOOKS := {"cores": "Cores", "numeros": "Números"}


static func level(key: String) -> Dictionary:
	return LEVELS.get(key, LEVELS.medio)


static func feedback(guess: Array, code: Array, mode: String) -> Array:
	if mode == "posicao":
		return Desafio.score_positions(guess, code)
	var pos := Desafio.score_positions(guess, code)
	return [pos.count(Desafio.GREEN), pos.count(Desafio.YELLOW)]


static func solved(fb: Array, mode: String, pins: int) -> bool:
	if mode == "posicao":
		return fb.size() == pins and fb.all(func(c): return c == Desafio.GREEN)
	return fb.size() == 2 and int(fb[0]) == pins


## Quão perto chegou (desempate de quem não acertou).
static func quality(fb: Array, mode: String) -> int:
	if mode == "posicao":
		return fb.count(Desafio.GREEN) * 10 + fb.count(Desafio.YELLOW)
	return int(fb[0]) * 10 + int(fb[1])


## "" se o palpite (ou a senha criada) vale para o nível.
static func check(guess: Array, level_key: String) -> String:
	var lv := level(level_key)
	if guess.size() != lv.pins:
		return "Complete os %d pinos." % lv.pins
	for s in guess:
		if typeof(s) not in [TYPE_INT, TYPE_FLOAT] or int(s) < 0 or int(s) >= lv.symbols:
			return "Símbolo inválido."
	if not lv.repeat:
		var seen := {}
		for s in guess:
			if seen.has(int(s)):
				return "No Fácil, a senha não repete símbolo."
			seen[int(s)] = true
	return ""


static func ints(a: Array) -> Array:
	return a.map(func(x): return int(x))


static func random_code(level_key: String, rng: RandomNumberGenerator) -> Array:
	var lv := level(level_key)
	var out: Array = []
	var pool: Array = range(lv.symbols)
	for i in lv.pins:
		if lv.repeat:
			out.append(rng.randi_range(0, lv.symbols - 1))
		else:
			var j := rng.randi_range(0, pool.size() - 1)
			out.append(pool[j])
			pool.remove_at(j)
	return out


## Senha do dia de um nível: igual em todos os aparelhos.
static func daily_code(day: int, level_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_000_003 * (day + 1000) + 101 * (LEVEL_ORDER.find(level_key) + 1) + 424242
	return random_code(level_key, rng)
