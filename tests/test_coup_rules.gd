extends TestCase
## Testes das regras do Coup (docs/PLANO_COUP.md §3, marco C1).

const HOST := {"id": "", "host": true}


func _as(id: String, now := 0) -> Dictionary:
	return {"id": id, "host": false, "now": now}


## Partida com n jogadores (p0..), cartas fixas, vez do p0.
func _game(hands: Array, fifth := "embaixador") -> CoupRules:
	var r := CoupRules.new(5)
	for i in hands.size():
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "set_config", "fifth": fifth})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	for i in hands.size():
		r.cards["p%d" % i] = hands[i].map(func(x): return {"role": x, "up": false})
		r.coins["p%d" % i] = 2
	r.turn = "p0"
	r.phase = "turn"
	return r


func _react(r: CoupRules, type: String, id: String, t: int, role := "") -> Dictionary:
	return r.resolve_timed([{"type": type, "player": id, "t": t, "role": role}], t + 100)


func test_setup() -> void:
	var r := CoupRules.new(1)
	for i in 3:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "start"})
	eq(r.phase, "turn", "começa")
	var total := r.deck.size()
	for p in r.players:
		eq(r.cards[p.id].size(), 2, "2 cartas")
		eq(r.coins[p.id], 2, "2 moedas")
		total += 2
	eq(total, 15, "15 cartas")
	var v := r.view_for({"id": "p0", "role": "player"})
	check(v.players[0].cards[0].role != "", "vê as próprias")
	eq(v.players[1].cards[0].role, "", "não vê as dos outros")
	var b := r.view_for({"id": "", "role": "board"})
	check(b.players.all(func(p): return p.cards.all(func(c): return c.role == "")), "tabuleiro não vê nada")


func test_two_players() -> void:
	var r := CoupRules.new(2)
	r.apply(HOST, {"type": "add_player", "name": "A", "id": "a"})
	r.apply(HOST, {"type": "add_player", "name": "B", "id": "b"})
	r.apply(HOST, {"type": "start"})
	eq(r.phase, "pick_first", "escolhe a primeira")
	eq(r.coins[r.turn], 1, "quem começa tem 1 moeda")
	var other := "b" if r.turn == "a" else "a"
	eq(r.coins[other], 2, "o outro tem 2")
	eq(r.view_for({"id": "a"}).first_options.size(), 5, "5 opções")
	check(not r.apply(_as("a"), {"type": "pick_first", "role": "xis"}).ok, "opção inválida")
	r.apply(_as("a"), {"type": "pick_first", "role": "duque"})
	eq(r.phase, "pick_first", "espera o outro")
	r.apply(_as("b"), {"type": "pick_first", "role": "duque"})
	eq(r.phase, "turn", "começa")
	eq(r.cards["a"][0].role, "duque", "ficou com a escolhida")
	eq(r.deck.size(), 3, "baralho de 3")


func test_income_coup_and_must_coup() -> void:
	var r := _game([["duque", "condessa"], ["capitao", "assassino"]])
	check(not r.apply(_as("p1"), {"type": "act", "action": "renda"}).ok, "fora da vez")
	r.apply(_as("p0"), {"type": "act", "action": "renda"})
	eq(r.coins["p0"], 3, "renda +1")
	eq(r.turn, "p1", "vez passa")
	check(not r.apply(_as("p1"), {"type": "act", "action": "golpe", "target": "p0"}).ok, "golpe sem 7 moedas")
	r.coins["p1"] = 10
	check(not r.apply(_as("p1"), {"type": "act", "action": "imposto"}).ok, "com 10, golpe obrigatório")
	r.apply(_as("p1"), {"type": "act", "action": "golpe", "target": "p0"})
	eq(r.coins["p1"], 3, "pagou 7")
	eq(r.phase, "lose", "alvo escolhe a carta")
	eq(r.loser, "p0", "p0 perde")
	check(not r.apply(_as("p1"), {"type": "lose", "index": 0}).ok, "só o alvo escolhe")
	r.apply(_as("p0"), {"type": "lose", "index": 1})
	check(r.cards["p0"][1].up, "virou a escolhida")
	eq(r.turn, "p0", "vez do p0")


func test_window_passes_after_5s() -> void:
	var r := _game([["duque", "condessa"], ["capitao", "assassino"], ["duque", "capitao"]])
	r.apply(_as("p0", 1000), {"type": "act", "action": "imposto"})
	eq(r.phase, "window", "janela aberta")
	r.tick(5999)
	eq(r.phase, "window", "ainda dentro dos 5 s")
	r.tick(6000)
	eq(r.coins["p0"], 5, "imposto +3")
	eq(r.turn, "p1", "vez passa")


func test_challenge_won_and_lost() -> void:
	# p0 tem o Duque: quem desafia perde, e a carta do p0 é trocada.
	var r := _game([["duque", "condessa"], ["capitao", "assassino"], ["capitao", "capitao"]])
	r.apply(_as("p0", 0), {"type": "act", "action": "imposto"})
	var res := r.resolve_timed([{"type": "challenge", "player": "p2", "t": 900}, {"type": "challenge", "player": "p1", "t": 800}], 1000)
	check(res.events.any(func(e): return e.type == "challenge" and e.by == "p1" and e.had), "vale o primeiro, e ele tinha")
	eq(r.loser, "p1", "quem desafiou perde")
	r.apply(_as("p1"), {"type": "lose", "index": 0})
	eq(r.coins["p0"], 5, "imposto aconteceu")
	eq(r.cards["p0"].size(), 2, "p0 continua com 2")
	# p1 blefa o Duque: desafiado, perde e não ganha nada.
	r.apply(_as("p1", 2000), {"type": "act", "action": "imposto"})
	_react(r, "challenge", "p2", 2100)
	eq(r.coins["p1"], 2, "sem imposto")
	check(r.cards["p1"].all(func(c): return c.up), "p1 com 1 carta perdeu a última")
	check(not r.alive("p1"), "p1 fora")
	eq(r.turn, "p2", "vez pula quem saiu")


func test_block_accept_and_block_challenge() -> void:
	var r := _game([["duque", "condessa"], ["capitao", "assassino"], ["duque", "capitao"]])
	# Ajuda Externa: qualquer um bloqueia com o Duque.
	r.apply(_as("p0", 0), {"type": "act", "action": "ajuda"})
	check(not _react(r, "challenge", "p1", 100).ok, "ajuda não se desafia")
	check(not _react(r, "block", "p1", 200, "condessa").ok, "bloqueio com personagem errado")
	_react(r, "block", "p1", 300, "duque")
	eq(r.phase, "block", "bloqueou")
	# Os outros aceitam, mas só o bloqueado encerra.
	r.apply(_as("p2"), {"type": "accept"})
	eq(r.phase, "block", "aceitar dos outros só avisa")
	eq(r.pending.accepted, ["p2"], "avisou")
	check(not r.apply(_as("p1"), {"type": "accept"}).ok, "quem bloqueou não aceita")
	r.apply(_as("p0"), {"type": "accept"})
	eq(r.coins["p0"], 2, "sem as 2 moedas")
	eq(r.turn, "p1", "vez passa")
	# p1 bloqueia a ajuda de p2 blefando o Duque; p0 desafia o bloqueio e ganha.
	r.turn = "p2"
	r.phase = "turn"
	r.apply(_as("p2", 1000), {"type": "act", "action": "ajuda"})
	_react(r, "block", "p1", 1100, "duque")
	_react(r, "challenge", "p0", 1200)
	eq(r.loser, "p1", "bloqueador blefou e perde")
	r.apply(_as("p1"), {"type": "lose", "index": 0})
	eq(r.coins["p2"], 4, "a ajuda aconteceu")


func test_assassinate_and_contessa() -> void:
	var r := _game([["assassino", "duque"], ["condessa", "capitao"], ["duque", "duque"]])
	r.coins["p0"] = 3
	check(not r.apply(_as("p0"), {"type": "act", "action": "assassinar", "target": "p0"}).ok, "não se mata")
	r.apply(_as("p0", 0), {"type": "act", "action": "assassinar", "target": "p1"})
	eq(r.coins["p0"], 0, "pagou 3")
	check(not _react(r, "block", "p2", 100, "condessa").ok, "só o alvo bloqueia")
	eq(r.can_block("p1"), ["condessa"], "alvo pode bloquear com a Condessa")
	_react(r, "block", "p1", 200, "condessa")
	r.apply(_as("p0"), {"type": "accept"})
	eq(r.coins["p0"], 0, "bloqueado: moedas perdidas")
	check(r.cards["p1"].all(func(c): return not c.up), "p1 intacto")


func test_assassinate_double_loss() -> void:
	# O alvo desafia o Assassino verdadeiro: perde uma pelo desafio e outra pelo assassinato.
	var r := _game([["assassino", "duque"], ["capitao", "duque"], ["duque", "duque"]])
	r.coins["p0"] = 3
	r.apply(_as("p0", 0), {"type": "act", "action": "assassinar", "target": "p1"})
	_react(r, "challenge", "p1", 100)
	eq(r.loser, "p1", "perde pelo desafio")
	r.apply(_as("p1", 200), {"type": "lose", "index": 0})
	eq(r.phase, "window", "nova janela, só pra bloquear")
	eq(r.pending.stage, "block_only", "só bloqueio")
	check(not r.can_challenge("p2"), "nessa janela não se desafia")
	r.tick(200 + 5000)
	check(not r.alive("p1"), "perdeu as duas")
	# Assassino blefando e desafiado: moedas voltam.
	var s := _game([["duque", "duque"], ["capitao", "condessa"], ["duque", "capitao"]])
	s.coins["p0"] = 3
	s.apply(_as("p0", 0), {"type": "act", "action": "assassinar", "target": "p1"})
	_react(s, "challenge", "p2", 100)
	eq(s.coins["p0"], 3, "moedas voltam")


func test_steal() -> void:
	var r := _game([["capitao", "duque"], ["condessa", "duque"], ["duque", "duque"]])
	r.coins["p1"] = 1
	r.apply(_as("p0", 0), {"type": "act", "action": "extorquir", "target": "p1"})
	eq(r.can_block("p1"), ["capitao", "embaixador"], "bloqueia com Capitão ou Embaixador")
	r.tick(5000)
	eq(r.coins["p0"], 3, "pegou só 1")
	eq(r.coins["p1"], 0, "ficou sem")


func test_ambassador_exchange() -> void:
	var r := _game([["embaixador", "duque"], ["condessa", "duque"], ["duque", "capitao"]])
	r.deck = ["capitao", "assassino"]
	r.apply(_as("p0", 0), {"type": "act", "action": "trocar"})
	r.tick(5000)
	eq(r.phase, "exchange", "trocando")
	eq(r.view_for({"id": "p0"}).exchange, ["assassino", "capitao"], "vê as 2 compradas")
	eq(r.view_for({"id": "p1"}).exchange, [], "os outros não")
	check(not r.apply(_as("p0"), {"type": "exchange", "keep": [0]}).ok, "tem que ficar com 2")
	r.apply(_as("p0"), {"type": "exchange", "keep": [2, 3]})
	eq(r.hidden("p0").map(func(c): return c.role), ["assassino", "capitao"], "ficou com as novas")
	eq(r.deck.size(), 2, "devolveu 2")


func test_inquisitor() -> void:
	var r := _game([["inquisidor", "duque"], ["condessa", "duque"], ["duque", "capitao"]], "inquisidor")
	check("examinar" in r.available_actions(), "examinar existe")
	r.deck = ["assassino"]
	r.apply(_as("p0", 0), {"type": "act", "action": "trocar"})
	r.tick(5000)
	eq(r.view_for({"id": "p0"}).exchange, ["assassino"], "compra 1")
	r.apply(_as("p0"), {"type": "exchange", "swap": 1})
	eq(r.hidden("p0").map(func(c): return c.role), ["inquisidor", "assassino"], "trocou o Duque")
	# Examinar: o alvo escolhe a carta; o Inquisidor manda trocar.
	r.turn = "p0"
	r.phase = "turn"
	r.apply(_as("p0", 10000), {"type": "act", "action": "examinar", "target": "p1"})
	r.tick(15000)
	eq(r.phase, "examine_show", "alvo mostra")
	r.apply(_as("p1"), {"type": "show", "index": 0})
	eq(r.view_for({"id": "p0"}).examined, "condessa", "o Inquisidor vê")
	eq(r.view_for({"id": "p2"}).examined, "", "os outros não")
	r.apply(_as("p0"), {"type": "examine", "force": true})
	eq(r.cards["p1"].size(), 2, "trocou a carta")
	eq(r.turn, "p1", "vez passa")
	# Extorquir: o Inquisidor bloqueia.
	r.apply(_as("p1", 20000), {"type": "act", "action": "renda"})
	r.turn = "p2"
	r.apply(_as("p2", 20000), {"type": "act", "action": "extorquir", "target": "p0"})
	eq(r.can_block("p0"), ["capitao", "inquisidor"], "Capitão ou Inquisidor")


func test_game_over() -> void:
	var r := _game([["duque", "condessa"], ["capitao", "assassino"]])
	r.cards["p1"][0].up = true
	r.coins["p0"] = 7
	r.apply(_as("p0"), {"type": "act", "action": "golpe", "target": "p1"})
	eq(r.phase, "game_over", "acabou")
	eq(r.winner, "p0", "p0 venceu")
	var v := r.view_for({"id": "p1"})
	check(v.players[0].cards.all(func(c): return c.role != ""), "no fim todo mundo vê")


func test_late_reaction_rejected() -> void:
	var r := _game([["duque", "condessa"], ["capitao", "assassino"]])
	r.apply(_as("p0", 0), {"type": "act", "action": "imposto"})
	var res := _react(r, "challenge", "p1", 5001)
	check(not res.ok, "desafio depois dos 5 s não vale")
