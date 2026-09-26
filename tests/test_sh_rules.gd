extends TestCase
## Testes das regras do Secret Hitler (docs/PLANO_SECRET_HITLER.md §3, marco S1).

const HOST := {"id": "", "host": true}


func _as(id: String) -> Dictionary:
	return {"id": id, "host": false}


## Partida com n jogadores (p0..pn-1), papéis fixos, presidente p0 e baralho fixo (o fim é o topo).
func _rigged(role_list: Array, deck_top_first := []) -> ShRules:
	var r := ShRules.new(7)
	for i in role_list.size():
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	for i in role_list.size():
		r.roles["p%d" % i] = role_list[i]
	r._rot = 0
	if not deck_top_first.is_empty():
		var d: Array = deck_top_first.duplicate()
		d.reverse()
		r.deck = d
	for i in role_list.size():
		r.apply(_as("p%d" % i), {"type": "ready"})
	return r


func _roles5() -> Array:
	return ["liberal", "liberal", "liberal", "fascista", "hitler"]


## Indica o chanceler e todos os vivos votam.
func _elect(r: ShRules, chancellor: String, ja := true) -> void:
	check(r.apply(_as(r.president), {"type": "nominate", "id": chancellor}).ok, "indicar %s" % chancellor)
	for p in r.alive():
		r.apply(_as(p.id), {"type": "vote", "ja": ja})


func _cont(r: ShRules) -> void:
	check(r.apply(HOST, {"type": "continue"}).ok, "continuar em %s" % r.phase)


## Governo eleito aprova a lei que estiver em hand[0] depois do descarte do presidente (índice).
func _legislate(r: ShRules, pres_discard: int, chanc_enact: int) -> void:
	_cont(r)
	eq(r.phase, ShRules.PHASE_LEG_PRESIDENT, "fase do presidente")
	check(r.apply(_as(r.president), {"type": "discard", "index": pres_discard}).ok, "descartar")
	check(r.apply(_as(r.chancellor), {"type": "enact", "index": chanc_enact}).ok, "aprovar")


func test_role_table() -> void:
	for n in range(5, 11):
		var r := ShRules.new(n)
		for i in n:
			r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
		r.apply(HOST, {"type": "start"})
		var vals: Array = r.roles.values()
		eq(vals.count("hitler"), 1, "um Hitler com %d" % n)
		eq(vals.count("fascista"), ShRules.FASCISTS[n], "fascistas com %d" % n)
		eq(vals.count("liberal"), n - 1 - ShRules.FASCISTS[n], "liberais com %d" % n)
		eq(r.deck.size(), 17, "17 leis")
		eq(r.deck.count("L"), 6, "6 liberais")


func test_knowledge() -> void:
	var r := _rigged(_roles5())
	eq(r.view_for({"id": "p0"}).knows.size(), 0, "liberal não sabe nada")
	var f: Array = r.view_for({"id": "p3"}).knows
	check(f.size() == 1 and f[0].id == "p4" and f[0].tag == "hitler", "fascista vê o Hitler")
	var h: Array = r.view_for({"id": "p4"}).knows
	check(h.size() == 1 and h[0].id == "p3", "Hitler com 5 vê o fascista")
	var r7 := _rigged(["liberal", "liberal", "liberal", "liberal", "fascista", "fascista", "hitler"])
	eq(r7.view_for({"id": "p6"}).knows.size(), 0, "Hitler com 7 não sabe nada")
	eq(r7.view_for({"id": "p4"}).knows.size(), 2, "fascista com 7 vê o outro e o Hitler")
	eq(r7.view_for({"id": "", "role": "board"}).role, "", "tabuleiro não tem papel")


func test_term_limits() -> void:
	var r := _rigged(["liberal", "liberal", "liberal", "liberal", "fascista", "hitler"], ["L", "L", "F", "L", "L", "F", "F", "F", "F"])
	check(not r.apply(_as("p0"), {"type": "nominate", "id": "p0"}).ok, "não indica a si mesmo")
	_elect(r, "p1")
	_legislate(r, 2, 0) # descarta F, aprova L
	eq(r.liberal, 1, "lei liberal")
	_cont(r)
	eq(r.president, "p1", "presidência passa")
	var el: Array = r.view_for({"id": "p1"}).eligible
	check("p0" not in el and "p1" not in el, "último presidente e último chanceler impedidos (6 vivos)")
	# Com 5 vivos, o último presidente pode.
	r.player("p5").alive = false
	el = r.eligible_chancellors()
	check("p0" in el and "p1" not in el, "com 5 vivos só o último chanceler fica impedido")


func test_failed_elections_and_chaos() -> void:
	var r := _rigged(_roles5(), ["F", "L", "L", "L", "L", "L"])
	_elect(r, "p1", false)
	eq(r.tracker, 1, "marcador sobe")
	eq(r.last_chancellor, "", "eleição fracassada não muda os impedimentos")
	_cont(r)
	eq(r.president, "p1", "presidência passa")
	_elect(r, "p2", false)
	_cont(r)
	_elect(r, "p3", false)
	eq(r.tracker, 3, "3 fracassos")
	_cont(r)
	eq(r.phase, ShRules.PHASE_POLICY, "caos aprova direto")
	eq(r.fascist, 1, "a lei do topo (F) entrou")
	check(r.last_policy.chaos, "marcado como caos")
	eq(r.tracker, 0, "marcador zera")
	eq(r.power, "", "caos não dá poder")
	_cont(r)
	eq(r.phase, ShRules.PHASE_NOMINATE, "segue")


func test_hitler_elected_after_three() -> void:
	var r := _rigged(_roles5())
	r.fascist = 3
	_elect(r, "p3")
	check("p3" in r.not_hitler, "chanceler que não é Hitler fica confirmado")
	eq(r.phase, ShRules.PHASE_VOTE_RESULT, "segue")
	var r2 := _rigged(_roles5())
	r2.fascist = 3
	_elect(r2, "p4")
	eq(r2.phase, ShRules.PHASE_GAME_OVER, "Hitler chanceler")
	eq(r2.winner, "fascista", "fascistas vencem")
	var r3 := _rigged(_roles5())
	r3.fascist = 2
	_elect(r3, "p4")
	eq(r3.phase, ShRules.PHASE_VOTE_RESULT, "com 2 leis, Hitler chanceler não vence")


func test_hand_privacy_and_history() -> void:
	var r := _rigged(_roles5(), ["F", "L", "F", "L"])
	_elect(r, "p1")
	_cont(r)
	eq(r.view_for({"id": "p0"}).hand.size(), 3, "presidente vê 3")
	eq(r.view_for({"id": "p1"}).hand.size(), 0, "chanceler ainda não vê")
	eq(r.view_for({"id": "p2"}).hand.size(), 0, "os outros não veem")
	r.apply(_as("p0"), {"type": "discard", "index": 0})
	eq(r.view_for({"id": "p1"}).hand.size(), 2, "chanceler vê 2")
	eq(r.view_for({"id": "p0"}).hand.size(), 0, "presidente não vê mais")
	check(not r.view_for({"id": "p2"}).history[0].has("drawn"), "durante o jogo o histórico não mostra as leis")
	r.apply(_as("p1"), {"type": "enact", "index": 0})
	# Sobrou 1 no baralho: o descarte (as 2 leis) volta e é embaralhado (§3.3).
	eq(r.discard.size(), 0, "descarte voltou pro baralho")
	eq(r.deck.size(), 3, "baralho com 3")


func test_deck_reshuffle() -> void:
	var r := _rigged(_roles5())
	r.deck = ["L", "F"]
	r.discard = ["F", "F", "L"]
	_elect(r, "p1")
	_cont(r)
	eq(r.hand.size(), 3, "reembaralhou antes de comprar")
	eq(r.deck.size() + r.discard.size() + r.hand.size(), 5, "nenhuma lei sumiu")


func test_powers_5_players() -> void:
	var r := _rigged(_roles5(), ["F", "F", "F", "L", "L", "L", "F", "F", "F"])
	r.fascist = 2
	_elect(r, "p1")
	_legislate(r, 0, 0)
	eq(r.fascist, 3, "3ª fascista")
	eq(r.power, "peek", "5 jogadores: espiar")
	_cont(r)
	eq(r.view_for({"id": "p0"}).peek, ["L", "L", "L"], "presidente vê as 3 do topo")
	eq(r.view_for({"id": "p1"}).peek, [], "só o presidente")
	check(r.apply(_as("p0"), {"type": "power"}).ok, "visto")
	eq(r.deck.slice(r.deck.size() - 3), ["L", "L", "L"], "baralho não muda")


func test_investigate() -> void:
	var r := _rigged(["liberal", "liberal", "liberal", "liberal", "liberal", "fascista", "fascista", "fascista", "hitler"], ["F", "F", "F"])
	_elect(r, "p1")
	_legislate(r, 0, 0)
	eq(r.power, "investigate", "9 jogadores: investigar na 1ª")
	_cont(r)
	check(not r.apply(_as("p0"), {"type": "power", "id": "p0"}).ok, "não investiga a si mesmo")
	check(r.apply(_as("p0"), {"type": "power", "id": "p8"}).ok, "investiga o Hitler")
	var seen: Array = r.view_for({"id": "p0"}).investigations
	check(seen.size() == 1 and seen[0].party == "fascista", "Hitler aparece como fascista")
	eq(r.view_for({"id": "p2"}).investigations.size(), 0, "os outros não veem o resultado")
	_cont(r)
	r.power = "investigate"
	r.phase = ShRules.PHASE_POWER
	r.president = "p1"
	check(not r.apply(_as("p1"), {"type": "power", "id": "p8"}).ok, "ninguém é investigado duas vezes")


func test_special_election_order() -> void:
	var r := _rigged(["liberal", "liberal", "liberal", "liberal", "fascista", "fascista", "hitler"], ["F", "F", "F"])
	r.fascist = 2
	_elect(r, "p1")
	_legislate(r, 0, 0)
	eq(r.power, "special_election", "7 jogadores: eleição especial na 3ª")
	_cont(r)
	check(r.apply(_as("p0"), {"type": "power", "id": "p4"}).ok, "escolhe p4")
	_cont(r)
	eq(r.president, "p4", "p4 é o candidato")
	_elect(r, "p2", false)
	_cont(r)
	eq(r.president, "p1", "depois volta pra ordem, a partir de quem vinha depois do p0")


func test_execution() -> void:
	var r := _rigged(_roles5(), ["F", "F", "F", "F", "F", "F"])
	r.fascist = 3
	_elect(r, "p1")
	_legislate(r, 0, 0)
	eq(r.power, "execution", "4ª: execução")
	_cont(r)
	check(r.apply(_as("p0"), {"type": "power", "id": "p2"}).ok, "executa p2")
	check(not r.is_alive("p2"), "p2 morto")
	eq(r.view_for({"id": "p3"}).all_roles, {}, "papel não é revelado")
	check(not r.apply(_as("p2"), {"type": "vote", "ja": true}).ok or r.phase != ShRules.PHASE_VOTE, "morto não vota")
	_cont(r)
	eq(r.president, "p1", "presidência segue")
	_elect(r, "p3")
	check(r.votes.size() == 4 or r.phase != ShRules.PHASE_VOTE, "só os 4 vivos votam")
	var r2 := _rigged(_roles5(), ["F", "F", "F"])
	r2.fascist = 3
	_elect(r2, "p1")
	_legislate(r2, 0, 0)
	_cont(r2)
	r2.apply(_as("p0"), {"type": "power", "id": "p4"})
	eq(r2.winner, "liberal", "executar o Hitler: liberais vencem")


func test_veto() -> void:
	var r := _rigged(_roles5(), ["F", "F", "F", "F", "F", "F", "L", "L", "L"])
	r.fascist = 4
	_elect(r, "p1")
	_cont(r)
	r.apply(_as("p0"), {"type": "discard", "index": 0})
	check(not r.apply(_as("p1"), {"type": "veto"}).ok, "sem veto com 4")
	r.apply(_as("p1"), {"type": "enact", "index": 0})
	eq(r.fascist, 5, "5ª")
	_cont(r) # execução
	r.apply(_as("p0"), {"type": "power", "id": "p2"})
	_cont(r)
	_elect(r, "p3")
	_cont(r)
	r.apply(_as(r.president), {"type": "discard", "index": 0})
	check(r.apply(_as("p3"), {"type": "veto"}).ok, "pede veto")
	check(r.apply(_as(r.president), {"type": "veto_answer", "accept": false}).ok, "presidente recusa")
	check(not r.apply(_as("p3"), {"type": "veto"}).ok, "não pede de novo")
	eq(r.phase, ShRules.PHASE_LEG_CHANCELLOR, "chanceler tem que aprovar")
	r.phase = ShRules.PHASE_LEG_CHANCELLOR
	r.veto_refused = false
	r.apply(_as("p3"), {"type": "veto"})
	var before := r.tracker
	r.apply(_as(r.president), {"type": "veto_answer", "accept": true})
	eq(r.tracker, before + 1, "veto aceito sobe o marcador")
	check(r.last_policy.vetoed, "vetado")
	eq(r.fascist, 5, "nenhuma lei entra")


func test_wins_by_policies() -> void:
	var r := _rigged(_roles5(), ["L", "L", "L"])
	r.liberal = 4
	_elect(r, "p1")
	_legislate(r, 0, 0)
	eq(r.winner, "liberal", "5 liberais")
	var r2 := _rigged(_roles5(), ["F", "F", "F"])
	r2.fascist = 5
	_elect(r2, "p1")
	_legislate(r2, 0, 0)
	eq(r2.winner, "fascista", "6 fascistas")
	check(r2.view_for({"id": "p0"}).history[0].has("drawn"), "no fim o histórico mostra as leis")
	eq(r2.view_for({"id": "p0"}).all_roles.size(), 5, "no fim todos os papéis aparecem")
