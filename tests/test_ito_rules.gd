extends TestCase
## Testes das regras do Ito (docs/PLANO_SINTONIA_ITO.md §4, marco T1).

const HOST := {"id": "", "host": true}
const THEMES := ["O quão assustador é um animal", "O quão chique é uma comida", "O quão útil numa ilha deserta"]


func _as(id: String) -> Dictionary:
	return {"id": id, "host": false}


func _game(n: int, mode := "desafio", seed_value := 3) -> ItoRules:
	var r := ItoRules.new(THEMES, seed_value)
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "set_config", "mode": mode})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	return r


## Escolhe o tema e põe todas as cartas na fila na ordem dada pela função (ids das cartas).
func _play(r: ItoRules, order: Callable) -> void:
	check(r.apply(_as("p0"), {"type": "pick_theme", "index": 0}).ok, "tema")
	var ids: Array = order.call(r.cards.keys())
	for i in ids.size():
		var c: Dictionary = r.cards[ids[i]]
		check(r.apply(_as(c.owner), {"type": "place", "card": c.id, "to": i}).ok, "pôr %s" % c.id)


func _sorted(r: ItoRules) -> Callable:
	return func(ids: Array) -> Array:
		var out := ids.duplicate()
		out.sort_custom(func(a, b): return r.cards[a].n < r.cards[b].n)
		return out


func _reversed(r: ItoRules) -> Callable:
	return func(ids: Array) -> Array:
		var out := ids.duplicate()
		out.sort_custom(func(a, b): return r.cards[a].n > r.cards[b].n)
		return out


func test_deal_unique_numbers() -> void:
	var r := _game(10, "solta")
	r.apply(HOST, {"type": "to_lobby"})
	var r2 := ItoRules.new(THEMES, 5)
	for i in 10:
		r2.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r2.apply(HOST, {"type": "set_config", "mode": "solta", "cards": 3})
	r2.apply(HOST, {"type": "start"})
	eq(r2.cards.size(), 30, "30 cartas")
	var seen := {}
	for id in r2.cards:
		var n: int = r2.cards[id].n
		check(n >= 1 and n <= 100, "número entre 1 e 100")
		check(not seen.has(n), "número repetido %d" % n)
		seen[n] = true
	eq(r2.phase, "theme", "fase do tema")
	eq(r2.theme_options.size(), 2, "dois temas")


func test_min_players_and_start() -> void:
	var r := ItoRules.new(THEMES, 1)
	r.apply(HOST, {"type": "add_player", "name": "Ana", "id": "a"})
	check(not r.apply(HOST, {"type": "start"}).ok, "1 jogador não começa")
	r.apply(HOST, {"type": "add_player", "name": "Bia", "id": "b"})
	check(not r.apply(_as("a"), {"type": "start"}).ok, "só o host começa")
	check(r.apply(HOST, {"type": "start"}).ok, "2 jogadores começa")


func test_theme_pick_and_custom() -> void:
	var r := _game(3)
	check(not r.apply(_as("x"), {"type": "pick_theme", "index": 0}).ok, "de fora não escolhe")
	check(not r.apply(_as("p1"), {"type": "custom_theme", "text": "a"}).ok, "tema curto")
	check(r.apply(_as("p1"), {"type": "custom_theme", "text": "O quão barulhento"}).ok, "tema digitado")
	eq(r.theme, "O quão barulhento", "tema")
	eq(r.phase, "play", "fase da fila")


func test_place_move_permissions() -> void:
	var r := _game(3)
	r.apply(_as("p0"), {"type": "pick_theme", "index": 1})
	var c0: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p0")[0]
	var c1: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p1")[0]
	check(not r.apply(_as("p1"), {"type": "place", "card": c0, "to": 0}).ok, "não põe carta alheia")
	check(r.apply(_as("p0"), {"type": "place", "card": c0, "to": 0}).ok, "põe a própria")
	check(not r.apply(_as("p0"), {"type": "place", "card": c0, "to": 0}).ok, "não põe duas vezes")
	check(r.apply(_as("p1"), {"type": "place", "card": c1, "to": 0}).ok, "põe antes")
	eq(r.row, [c1, c0], "ordem")
	check(r.apply(_as("p2"), {"type": "move", "card": c1, "to": 1}).ok, "qualquer um move")
	eq(r.row, [c0, c1], "ordem depois de mover")
	check(not r.apply(_as("p2"), {"type": "take_back", "card": c1}).ok, "não tira carta alheia")
	check(r.apply(_as("p1"), {"type": "take_back", "card": c1}).ok, "tira a própria")
	eq(r.row, [c0], "fila sem a carta")
	check(not r.apply(_as("p0"), {"type": "reveal"}).ok, "não revela com carta fora")
	check(r.apply(_as("p1"), {"type": "word", "card": c1, "text": "um leão"}).ok, "palavra-chave")
	eq(r.cards[c1].word, "um leão", "palavra salva")
	check(not r.apply(_as("p0"), {"type": "word", "card": c1, "text": "x"}).ok, "não escreve na alheia")


func test_errors_left_to_right() -> void:
	var r := _game(4, "solta")
	r.apply(_as("p0"), {"type": "pick_theme", "index": 0})
	var ids: Array = r.cards.keys()
	var nums := [10, 50, 30, 70]
	for i in 4:
		r.cards[ids[i]].n = nums[i]
		r.apply(_as(r.cards[ids[i]].owner), {"type": "place", "card": ids[i], "to": i})
	check(r.apply(_as("p2"), {"type": "reveal"}).ok, "revela")
	eq(r.result.errors, [ids[2]], "só o 30 depois do 50 é erro")
	# 60, 20, 30, 10: 20, 30 e 10 são menores que o 60.
	var r2 := _game(4, "solta")
	r2.apply(_as("p0"), {"type": "pick_theme", "index": 0})
	var ids2: Array = r2.cards.keys()
	var n2 := [60, 20, 30, 10]
	for i in 4:
		r2.cards[ids2[i]].n = n2[i]
		r2.apply(_as(r2.cards[ids2[i]].owner), {"type": "place", "card": ids2[i], "to": i})
	r2.apply(_as("p0"), {"type": "reveal"})
	eq(r2.result.errors.size(), 3, "três erros")
	eq(r2.lives, 3, "rodada solta não tem vidas")
	eq(r2.result.next, "round", "segue")


func test_desafio_progression_and_extreme() -> void:
	var r := _game(3, "desafio", 9)
	eq(r.level(), 1, "nível 1")
	eq(r.total_cards(), 3, "uma carta cada")
	_play(r, _sorted(r))
	r.apply(_as("p0"), {"type": "reveal"})
	check(r.result.ok, "acertou")
	eq(r.best, 1, "recorde 1")
	r.apply(_as("p1"), {"type": "continue"})
	eq(r.level(), 2, "nível 2")
	eq(r.total_cards(), 4, "uma carta a mais")
	check(not r.extreme(), "sem extremo ainda")
	# Até todos terem 2 cartas (nível 4), depois o extremo.
	for k in 3:
		_play(r, _sorted(r))
		r.apply(_as("p0"), {"type": "reveal"})
		r.apply(_as("p0"), {"type": "continue"})
	eq(r.level(), 5, "nível 5")
	check(r.extreme(), "extremo com alguém em 3")
	r.apply(_as("p0"), {"type": "pick_theme", "index": 0})
	var v := r.view_for({"id": "p1", "role": "player"})
	var c: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p0")[0]
	r.apply(_as("p0"), {"type": "place", "card": c, "to": 0})
	v = r.view_for({"id": "p1", "role": "player"})
	eq(v.row[0].owner, "", "extremo esconde o dono")
	eq(r.view_for({"id": "p0", "role": "player"}).row[0].owner, "p0", "o dono se vê")
	eq(v.pending, {}, "extremo não mostra quem falta")


func test_desafio_lives_and_repeat() -> void:
	var r := _game(3, "desafio", 4)
	_play(r, _reversed(r))
	r.apply(_as("p0"), {"type": "reveal"})
	eq(r.result.errors.size(), 2, "dois erros")
	eq(r.lives, 1, "perdeu 2 vidas")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.level(), 1, "repete o nível")
	eq(r.round_no, 2, "rodada nova")
	_play(r, _reversed(r))
	r.apply(_as("p0"), {"type": "reveal"})
	eq(r.lives, 0, "sem vidas")
	eq(r.result.lost, 1, "perde só o que tinha")
	eq(r.result.next, "game_over", "acaba")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.phase, "game_over", "fim")
	eq(r.end_reason, "lives", "motivo")
	check(r.apply(HOST, {"type": "rematch"}).ok, "revanche")
	eq(r.lives, 3, "vidas de volta")
	eq(r.level(), 1, "nível 1 de novo")


func test_view_hides_numbers() -> void:
	var r := _game(3, "solta")
	r.apply(_as("p0"), {"type": "pick_theme", "index": 0})
	var mine: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p0")[0]
	var other: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p1")[0]
	r.apply(_as("p0"), {"type": "place", "card": mine, "to": 0})
	r.apply(_as("p1"), {"type": "place", "card": other, "to": 1})
	var v := r.view_for({"id": "p0", "role": "player"})
	eq(v.hand.size(), 1, "uma carta na mão")
	eq(v.hand[0].n, r.cards[mine].n, "vê o próprio número")
	eq(v.row[0].n, r.cards[mine].n, "vê o próprio na fila")
	eq(v.row[1].n, -1, "não vê o alheio")
	var b := r.view_for({"id": "", "role": "board"})
	eq(b.hand, [], "tabuleiro sem mão")
	check(b.row.all(func(x): return x.n == -1), "tabuleiro não vê números")
	eq(b.pending, {"p2": 1}, "quem falta")
	var last: String = r.cards.keys().filter(func(id): return r.cards[id].owner == "p2")[0]
	r.apply(_as("p2"), {"type": "place", "card": last, "to": 2})
	r.apply(_as("p2"), {"type": "reveal"})
	b = r.view_for({"id": "", "role": "board"})
	check(b.row.all(func(x): return x.n > 0), "na revelação todos veem")


func test_local_mode() -> void:
	var r := ItoRules.new(THEMES, 2)
	r.local_mode = true
	var L := {"id": "", "host": true, "local": true}
	for n in ["Ana", "Bia"]:
		check(r.apply(L, {"type": "add_player", "name": n}).ok, "adiciona %s" % n)
	check(not r.apply(L, {"type": "add_player", "name": "ana"}).ok, "nome repetido")
	r.apply(L, {"type": "start"})
	r.apply(L, {"type": "pick_theme", "index": 0})
	var v := r.view_for({"id": "", "role": "local"})
	eq(v.loose.size(), 2, "cartas soltas pro grupo pôr")
	check(v.loose.all(func(x): return not x.has("n")), "soltas sem número")
	var ids: Array = r.cards.keys()
	ids.sort_custom(func(a, b): return r.cards[a].n < r.cards[b].n)
	for i in ids.size():
		check(r.apply(L, {"type": "place", "card": ids[i], "to": i}).ok, "local põe qualquer carta")
	r.apply(L, {"type": "reveal"})
	r.apply(L, {"type": "continue"})
	# Até todos com 2: com 2 jogadores, nível 3 é o último.
	for k in 2:
		r.apply(L, {"type": "pick_theme", "index": 0})
		ids = r.cards.keys()
		ids.sort_custom(func(a, b): return r.cards[a].n < r.cards[b].n)
		for i in ids.size():
			r.apply(L, {"type": "place", "card": ids[i], "to": i})
		check(not r.extreme(), "celular só não tem extremo")
		r.apply(L, {"type": "reveal"})
		r.apply(L, {"type": "continue"})
	eq(r.phase, "game_over", "venceu com todos em 2")
	eq(r.end_reason, "won", "vitória")
	eq(r.best, 3, "recorde")
