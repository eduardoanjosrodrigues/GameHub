class_name WordleWords
extends RefCounted
## Listas do Wordle (docs/PLANO_WORDLE_SENHA.md §7): palpites válidos (VERO, LGPLv3/MPL) e respostas
## curadas. Tudo é comparado sem acento; o acento só aparece quando as letras são reveladas.

const GUESSES := "res://games/wordle/data/palpites.txt"
const ANSWERS := "res://games/wordle/data/respostas.txt"
const LENGTH := 5
## Semente do embaralhamento da palavra do dia. Não mude depois do lançamento.
const DAILY_SEED := 20260928
## O treino não usa as palavras do dia que já passaram nem as dos próximos dias (§3.4).
const TRAINING_GUARD_DAYS := 30

static var _display := {} # sem acento -> com acento
static var _answers: Array = [] # com acento
static var _order: Array = []
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for w in _read(GUESSES):
		var n := TextNorm.normalize(w)
		if n.length() == LENGTH and not _display.has(n):
			_display[n] = w
	for w in _read(ANSWERS):
		var n := TextNorm.normalize(w)
		if n.length() != LENGTH:
			continue
		_answers.append(w)
		_display[n] = w # a forma da resposta ganha de outra grafia do mesmo palpite
	_order = Desafio.shuffled(_answers.size(), DAILY_SEED)


static func _read(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Não achei %s" % path)
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			out.append(line)
	return out


## Só letras, sem acento, minúsculas. "Canção" -> "cancao".
static func norm(w: String) -> String:
	var n := TextNorm.normalize(w)
	var out := ""
	for ch in n:
		if ch >= "a" and ch <= "z":
			out += ch
	return out


static func is_valid(n: String) -> bool:
	_ensure()
	return _display.has(n)


## Como a palavra aparece revelada (com acento). Sem o acento conhecido, em maiúsculas mesmo.
static func display(n: String) -> String:
	_ensure()
	return str(_display.get(n, n))


static func answers() -> Array:
	_ensure()
	return _answers


static func guess_count() -> int:
	_ensure()
	return _display.size()


static func daily(day: int) -> String:
	_ensure()
	return _answers[_order[posmod(day, _answers.size())]]


## Palavras de treino: nenhuma do dia já passada nem dos próximos dias. exclude: sem acento.
static func random_training(rng: RandomNumberGenerator, today: int, count := 1, exclude: Array = []) -> Array:
	_ensure()
	var n := _answers.size()
	var blocked := {}
	var upto := mini(n, today + TRAINING_GUARD_DAYS + 1)
	for d in range(0, upto):
		blocked[_order[d]] = true
	var pool: Array = []
	for i in n:
		if not blocked.has(i) and norm(_answers[i]) not in exclude:
			pool.append(i)
	if pool.size() < count:
		# A lista acabou (daqui a anos): vale qualquer uma menos a de hoje.
		pool = range(n).filter(func(i): return i != _order[posmod(today, n)] and norm(_answers[i]) not in exclude)
	var out: Array = []
	for k in count:
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(_answers[pool[j]])
		pool.remove_at(j)
	return out
