class_name Desafio
extends RefCounted
## O que o Wordle e o Senha têm em comum (docs/PLANO_WORDLE_SENHA.md §3.4, §4.3, §9): o número
## do dia (vira à meia-noite no horário do aparelho), o embaralhamento fixo e as cores por posição.

## Dia 0 do desafio diário. Mudar isso muda a palavra/senha de todos os dias.
const EPOCH := {"year": 2026, "month": 9, "day": 28}
const GREEN := 2
const YELLOW := 1
const GRAY := 0


## Dias desde EPOCH, pela data local do aparelho. date: {year, month, day} (vazio = hoje).
static func day_index(date := {}) -> int:
	var d: Dictionary = date if not date.is_empty() else Time.get_date_dict_from_system()
	var a := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 0, "minute": 0, "second": 0})
	var b := Time.get_unix_time_from_datetime_dict({"year": EPOCH.year, "month": EPOCH.month, "day": EPOCH.day, "hour": 0, "minute": 0, "second": 0})
	return floori((a - b) / 86400.0)


## Segundos até a meia-noite local (pra contagem "próxima palavra em").
static func seconds_to_midnight() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


## 0..n-1 embaralhados sempre do mesmo jeito para a mesma semente, em qualquer aparelho.
static func shuffled(n: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Cores por posição, com a regra do Wordle para repetidos (§3.1): primeiro os verdes; depois,
## da esquerda para a direita, amarelo enquanto a resposta tiver cópias ainda não usadas.
static func score_positions(guess: Array, answer: Array) -> Array:
	var out: Array = []
	out.resize(guess.size())
	out.fill(GRAY)
	var left := {}
	for i in guess.size():
		if i < answer.size() and guess[i] == answer[i]:
			out[i] = GREEN
		elif i < answer.size():
			left[answer[i]] = int(left.get(answer[i], 0)) + 1
	for i in guess.size():
		if out[i] == GREEN:
			continue
		var n := int(left.get(guess[i], 0))
		if n > 0:
			out[i] = YELLOW
			left[guess[i]] = n - 1
	return out


static func mmss(s: int) -> String:
	s = maxi(0, s)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
