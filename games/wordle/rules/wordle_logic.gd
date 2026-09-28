class_name WordleLogic
extends RefCounted
## Regras de um palpite do Wordle (docs/PLANO_WORDLE_SENHA.md §3): cores e modo difícil.
## As palavras chegam aqui sem acento (WordleWords.norm).

const MODES := {
	"dia": {"boards": 1, "tries": 6},
	"treino": {"boards": 1, "tries": 6},
	"dueto": {"boards": 2, "tries": 7},
	"quarteto": {"boards": 4, "tries": 9},
}


## 2 = verde, 1 = amarela, 0 = cinza, por letra.
static func score(guess: String, answer: String) -> Array:
	return Desafio.score_positions(_chars(guess), _chars(answer))


static func solved(colors: Array) -> bool:
	return not colors.is_empty() and colors.all(func(c): return c == Desafio.GREEN)


## Modo difícil (§3.3): as verdes ficam no lugar e as amarelas aparecem. history: [{n, c}].
## Devolve "" se o palpite vale, senão o aviso.
static func hard_violation(guess: String, history: Array) -> String:
	for h in history:
		var w: String = h.n
		var c: Array = h.c
		for i in w.length():
			if c[i] == Desafio.GREEN and guess[i] != w[i]:
				return "A %dª letra precisa ser %s" % [i + 1, w[i].to_upper()]
		var need := {}
		for i in w.length():
			if c[i] != Desafio.GRAY:
				need[w[i]] = int(need.get(w[i], 0)) + 1
		for ch in need:
			if guess.count(ch) < need[ch]:
				return "O palpite precisa ter %s" % ch.to_upper()
	return ""


## Melhor cor de cada letra até agora (teclado): {letra: 0|1|2}.
static func key_colors(history: Array) -> Dictionary:
	var out := {}
	for h in history:
		for i in h.n.length():
			var ch: String = h.n[i]
			out[ch] = maxi(int(out.get(ch, -1)), int(h.c[i]))
	return out


## Quão perto chegou (desempate de quem não acertou): mais verdes, depois mais amarelas.
static func quality(colors: Array) -> int:
	return colors.count(Desafio.GREEN) * 10 + colors.count(Desafio.YELLOW)


static func _chars(s: String) -> Array:
	var out: Array = []
	for ch in s:
		out.append(ch)
	return out
