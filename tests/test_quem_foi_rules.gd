extends TestCase
## Testes das regras do Quem Foi? (docs/PLANO_QUEM_FOI.md §3, marco Q1).

const HOST := {"id": "", "host": true}


func _as(id: String, now := 0) -> Dictionary:
	return {"id": id, "host": false, "now": now}


## Partida com n jogadores (p0..pn-1), p0 abre.
func _game(n := 3) -> QuemFoiRules:
	var r := QuemFoiRules.new(4)
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	# Abre sempre com p0, pra os testes ficarem previsíveis.
	r.starter = "p0"
	r.accuser = "p0"
	return r


func _tap(r: QuemFoiRules, id: String, t: int, animal := "") -> Dictionary:
	return r.ring([{"player": id, "t": t, "animal": animal if animal != "" else r.accused}], t + 100)


func test_setup() -> void:
	var r := QuemFoiRules.new(1)
	for i in 2:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	check(r.can_start() != "", "2 não jogam")
	for i in range(2, 7):
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	eq(r.players.size(), 6, "máximo 6")
	var colors := r.players.map(func(p): return p.color)
	colors.sort()
	eq(colors, [0, 1, 2, 3, 4, 5], "uma cor pra cada")
	r.apply(HOST, {"type": "remove_player", "id": "p1"})
	r.apply(HOST, {"type": "add_player", "name": "Novo", "id": "x"})
	eq(r.player("x").color, 1, "reaproveita a cor livre")
	r.apply(HOST, {"type": "start"})
	eq(r.phase, "accuse", "abre com acusação")
	for p in r.players:
		eq(r.hands[p.id].size(), 6, "6 bichos")


func test_open_and_race() -> void:
	var r := _game()
	check(not r.apply(_as("p1"), {"type": "accuse", "play": "gato", "animal": "coelho"}).ok, "só quem abre acusa")
	check(not r.apply(_as("p0"), {"type": "accuse", "animal": "coelho"}).ok, "na abertura tem que jogar um bicho")
	check(r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "coelho"}).ok, "abre")
	eq(r.phase, "race", "corrida")
	eq(r.pile.back(), {"animal": "gato", "owner": "p0"}, "gato na pilha")
	eq(r.racers(), ["p1", "p2"], "quem acusou não corre")
	# Toque do próprio acusador e do bicho errado não contam.
	_tap(r, "p0", 1100)
	eq(r.phase, "race", "acusador não ganha")
	_tap(r, "p1", 1100, "peixe")
	eq(r.phase, "race", "bicho errado não ganha")
	var res := r.ring([{"player": "p2", "t": 1300, "animal": "coelho"}, {"player": "p1", "t": 1200, "animal": "coelho"}], 1400)
	eq(r.accuser, "p1", "ganha o toque mais cedo")
	eq(r.phase, "accuse", "vencedor acusa")
	check(not r.has_animal("p1", "coelho"), "coelho saiu da mão")
	check(res.events.any(func(e): return e.type == "won_race"), "evento")


func test_miss_locks() -> void:
	var r := _game()
	r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "coelho"})
	r.apply(_as("p1", 1100), {"type": "miss"})
	r.ring([{"player": "p1", "t": 1500, "animal": "coelho"}, {"player": "p2", "t": 1800, "animal": "coelho"}], 1900)
	eq(r.accuser, "p2", "travado por 1 s não ganha")
	eq(r.view_for({"id": "p1"}, 1200).locked_ms, 0, "trava some fora da corrida")


func test_same_animal_accusation() -> void:
	var r := _game()
	check(r.apply(_as("p0"), {"type": "accuse", "play": "gato", "animal": "gato"}).ok, "pode acusar o mesmo tipo")
	eq(r.racers(), ["p1", "p2"], "os outros gatos correm")


func test_nobody_has_suspense() -> void:
	var r := _game()
	for id in ["p1", "p2"]:
		r.hands[id].erase("peixe")
	r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "peixe"})
	eq(r.phase, "race", "a tela segue como corrida")
	var v := r.view_for({"id": "p1"}, 1000)
	check(not v.has("doomed"), "a visão não entrega")
	r.tick(5999)
	eq(r.phase, "race", "suspense de 5 s")
	r.tick(6000)
	eq(r.phase, "round_end", "acabou")
	eq(r.last.guilty, "p0", "culpado é o dono do último bicho")
	eq(r.last.animal, "gato", "o gato")
	eq(r.last.reason, "ninguem_tem", "motivo")
	eq(r.player("p0").poops, 1, "levou o cocô")
	eq(r.last.hands.size(), 3, "mãos à mostra")


func test_empty_hand_is_safe_and_last_one_guilty() -> void:
	var r := _game()
	# p0 com um bicho só: joga e fica a salvo.
	r.hands["p0"] = ["gato"]
	r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "coelho"})
	eq(r.hands["p0"], [], "mão vazia")
	# p1 ganha com o último bicho dele: sobra só p2 com cartas, mas p1 ainda precisa acusar.
	r.hands["p1"] = ["coelho"]
	_tap(r, "p1", 1100)
	eq(r.phase, "accuse", "quem esvaziou a mão ainda acusa")
	eq(r.accuser, "p1", "p1 acusa")
	r.apply(_as("p1", 1200), {"type": "accuse", "animal": "gato"})
	eq(r.phase, "round_end", "acertou um bicho de quem sobrou")
	eq(r.last.guilty, "p2", "p2 fica com a culpa")
	eq(r.last.animal, "gato", "o gato de p2")
	eq(r.last.reason, "ultimo", "motivo")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.phase, "accuse", "nova rodada")
	eq(r.accuser, "p2", "quem levou o cocô começa")
	eq(r.hands["p0"].size(), 6, "mãos de volta")


func test_last_accuser_misses() -> void:
	var r := _game()
	r.hands["p0"] = ["gato"]
	r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "coelho"})
	r.hands["p1"] = ["coelho"]
	r.hands["p2"].erase("peixe")
	_tap(r, "p1", 1100)
	# Errou: ninguém tem peixe, e o cocô volta pra quem acusou.
	r.apply(_as("p1", 1200), {"type": "accuse", "animal": "peixe"})
	eq(r.phase, "race", "suspense como sempre")
	r.tick(1200 + QuemFoiRules.SUSPENSE_MS)
	eq(r.phase, "round_end", "acabou")
	eq(r.last.guilty, "p1", "p1 errou e leva")
	eq(r.last.reason, "ninguem_tem", "motivo")


func test_opening_last_card_hits_the_last_one() -> void:
	var r := _game()
	r.hands["p0"] = ["gato"]
	r.hands["p2"] = []
	# p0 joga o último bicho e acerta um coelho de p1, o único com bichos: sem corrida.
	r.apply(_as("p0", 1000), {"type": "accuse", "play": "gato", "animal": "coelho"})
	eq(r.phase, "round_end", "acertou quem sobrou")
	eq(r.last.guilty, "p1", "p1 fica com a culpa")
	eq(r.last.reason, "ultimo", "motivo")


func test_game_end_and_ties() -> void:
	var r := _game(4)
	r.apply(HOST, {"type": "set_config", "max_poops": 9})
	eq(r.config.max_poops, 3, "config só na sala")
	r.players[0].poops = 2
	r.players[1].poops = 1
	r.players[2].poops = 0
	r.players[3].poops = 0
	for id in ["p1", "p2", "p3"]:
		r.hands[id].erase("peixe")
	r.apply(_as("p0", 0), {"type": "accuse", "play": "gato", "animal": "peixe"})
	r.tick(10000)
	r.apply(_as("p1"), {"type": "continue"})
	eq(r.phase, "game_over", "3 cocôs acaba")
	eq(r.winners, ["p2", "p3"], "empate divide")
	check(r.apply(HOST, {"type": "rematch"}).ok, "revanche")
	eq(r.player("p0").poops, 0, "zera")


func test_view_hides_hands() -> void:
	var r := _game()
	var v := r.view_for({"id": "p1", "role": "player"})
	eq(v.hand.size(), 6, "vê a própria mão")
	check(not v.has("hands"), "não vê a dos outros")
	var b := r.view_for({"id": "", "role": "board"})
	eq(b.hand, [], "tabuleiro sem mão")
	eq(b.played, {}, "sem ajuda de memória")
	eq(b.players[0].cards, 6, "quantas cartas cada um tem")
	# A mão embaralha a cada acusação, mas é a mesma na mesma acusação.
	var a1: Array = r.view_for({"id": "p1"}).hand
	eq(r.view_for({"id": "p1"}).hand, a1, "estável na mesma acusação")
	r.apply(_as("p0", 0), {"type": "accuse", "play": "gato", "animal": "coelho"})
	var shuffles := 0
	for k in 6:
		r.race_no += 1
		if r.view_for({"id": "p1"}).hand != a1:
			shuffles += 1
	check(shuffles >= 4, "embaralha a cada acusação")


func test_memory_help() -> void:
	var r := QuemFoiRules.new(2)
	for i in 3:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "set_config", "memory_help": true, "max_poops": 4})
	eq(r.config.max_poops, 4, "limite de cocôs")
	r.apply(HOST, {"type": "start"})
	r.accuser = r.starter
	r.apply(_as(r.starter, 0), {"type": "accuse", "play": "gato", "animal": "coelho"})
	eq(r.view_for({"id": "", "role": "board"}).played, {"gato": 1}, "ajuda de memória")
