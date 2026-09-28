class_name DesafioStore
extends RefCounted
## Estatísticas, partidas em andamento e preferências do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md
## §2, §3.2), salvas em user://desafios.json. Cada modo tem uma chave ("wordle_dia", "senha_treino_facil"...).
##   stats[chave]: {played, won, streak, best, dist: {"tentativas": vezes}, last_won_day}
##   saves[chave]: a partida do jeito que o jogo guardou, mais "day" (desafio do dia) e "finished".
## Uma partida do dia que não terminou até a meia-noite conta como derrota (e zera a sequência).

const PATH := "user://desafios.json"

static var persist := true
static var _data := {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"stats": {}, "saves": {}, "prefs": {}}
	if not persist or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in ["stats", "saves", "prefs"]:
			if d.get(k) is Dictionary:
				_data[k] = d[k]


static func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))


## Só pros testes: começa do zero, sem disco.
static func reset_for_tests() -> void:
	persist = false
	_loaded = true
	_data = {"stats": {}, "saves": {}, "prefs": {}}


static func pref(key: String, default = null):
	_ensure()
	return _data.prefs.get(key, default)


static func set_pref(key: String, value) -> void:
	_ensure()
	_data.prefs[key] = value
	_save()


static func stats(key: String, today := -1) -> Dictionary:
	_ensure()
	var s: Dictionary = _data.stats.get(key, {}).duplicate(true)
	for k in ["played", "won", "streak", "best"]:
		s[k] = int(s.get(k, 0))
	if not s.has("dist"):
		s.dist = {}
	s.last_won_day = int(s.get("last_won_day", -999999))
	# Pulou um dia: a sequência já quebrou, mesmo sem ter jogado.
	if today >= 0 and s.last_won_day < today - 1:
		s.streak = 0
	return s


## Registra uma partida terminada. day >= 0 = desafio do dia (conta a sequência).
static func record(key: String, won: bool, tries: int, day := -1) -> void:
	_ensure()
	var s := stats(key)
	s.played += 1
	if won:
		s.won += 1
		s.dist[str(tries)] = int(s.dist.get(str(tries), 0)) + 1
	if day >= 0:
		if won:
			s.streak = s.streak + 1 if s.last_won_day == day - 1 else 1
			s.last_won_day = day
		else:
			s.streak = 0
		s.best = maxi(s.best, s.streak)
	_data.stats[key] = s
	_save()


static func load_game(key: String) -> Dictionary:
	_ensure()
	var g = _data.saves.get(key, {})
	return g.duplicate(true) if g is Dictionary else {}


static func save_game(key: String, state: Dictionary) -> void:
	_ensure()
	_data.saves[key] = state.duplicate(true)
	_save()


static func clear_game(key: String) -> void:
	_ensure()
	_data.saves.erase(key)
	_save()


## Partida do dia salva de um dia que já passou e não terminou: vira derrota. Devolve a partida de
## hoje (ou {} se não tiver).
static func today_game(key: String, today: int) -> Dictionary:
	var g := load_game(key)
	if g.is_empty():
		return {}
	if int(g.get("day", -1)) == today:
		return g
	if not g.get("finished", false):
		record(key, false, 0, int(g.get("day", today - 1)))
	clear_game(key)
	return {}
