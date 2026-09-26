extends TestCase
## Testes das regras do Avalon (docs/PLANO_AVALON.md §3).

const HOST := {"id": "", "host": true}


func _game(n: int, specials := ["merlin", "assassino"], lady := false) -> AvalonRules:
	var r := AvalonRules.new(3)
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.config.roles = specials
	r.config.lady = lady
	return r


func _as(id: String) -> Dictionary:
	return {"id": id, "host": false}


## Começa, fixa os papéis na ordem pedida e deixa o líder no jogador 0.
func _rigged(role_list: Array, lady := false) -> AvalonRules:
	var r := _game(role_list.size(), ["merlin", "assassino"], lady)
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	for i in role_list.size():
		r.roles["p%d" % i] = role_list[i]
	r.leader = 0
	if r.lady_on():
		r.lady = "p%d" % (role_list.size() - 1)
		r.lady_used = [r.lady]
	for i in role_list.size():
		r.apply(_as("p%d" % i), {"type": "ready"})
	return r


func _team_and_vote(r: AvalonRules, ids: Array, approve_all := true) -> void:
	var lid := r.leader_id()
	check(r.apply(_as(lid), {"type": "select_team", "ids": ids}).ok, "select")
	check(r.apply(_as(lid), {"type": "propose"}).ok, "propose")
	for p in r.players:
		r.apply(_as(p.id), {"type": "vote", "approve": approve_all})
	check(r.apply(HOST, {"type": "continue"}).ok, "continue voto")


func _play_quest(r: AvalonRules, fails := {}) -> void:
	for id in r.team:
		r.apply(_as(id), {"type": "quest_card", "success": not fails.has(id)})
	check(r.apply(HOST, {"type": "continue"}).ok, "continue missão")


func test_table_and_deal() -> void:
	for n in range(5, 11):
		var r := _game(n)
		eq(r.apply(HOST, {"type": "start"}).ok, true, "start %d" % n)
		var evil := r.roles.values().filter(func(x): return x in AvalonRules.EVIL).size()
		eq(evil, AvalonRules.TABLE[n][0], "maus com %d" % n)
		check("merlin" in r.roles.values() and "assassino" in r.roles.values(), "merlin e assassino com %d" % n)
		eq(r.phase, AvalonRules.PHASE_REVEAL, "vai pra revelação")
	var few := _game(4)
	check(few.can_start() != "", "4 não começa")


func test_role_dependencies() -> void:
	var r := _game(7, [])
	r.apply(HOST, {"type": "set_config", "toggle": "morgana"})
	eq(r.config.roles, ["merlin", "assassino", "percival", "morgana"], "Morgana puxa Percival, Merlin e Assassino")
	r.apply(HOST, {"type": "set_config", "toggle": "merlin"})
	eq(r.config.roles, [], "sem Merlin sai tudo que depende dele")
	r.apply(HOST, {"type": "set_config", "toggle": "percival"})
	eq(r.config.roles, ["merlin", "assassino", "percival"], "Percival puxa Merlin")
	r.apply(HOST, {"type": "set_config", "toggle": "percival"})
	eq(r.config.roles, ["merlin", "assassino"], "tirar Percival mantém Merlin")
	var small := _game(5)
	small.apply(HOST, {"type": "set_config", "toggle": "mordred"})
	check(small.can_start() == "", "5: assassino + mordred cabem nos 2 maus")
	small.apply(HOST, {"type": "set_config", "toggle": "oberon"})
	check(small.can_start() != "", "5: 3 personagens do mal não cabem")


func test_knowledge() -> void:
	var r := _rigged(["merlin", "percival", "servo", "servo", "assassino", "morgana", "mordred", "oberon"])
	var ids := func(k: Array) -> Array: return k.map(func(e): return e.id)
	eq(ids.call(r.view_for({"id": "p0"}).knows), ["p4", "p5", "p7"], "Merlin vê o mal menos Mordred")
	eq(ids.call(r.view_for({"id": "p1"}).knows), ["p0", "p5"], "Percival vê Merlin e Morgana")
	eq(r.view_for({"id": "p2"}).knows, [], "servo não vê nada")
	eq(ids.call(r.view_for({"id": "p4"}).knows), ["p5", "p6"], "Assassino vê o mal menos Oberon")
	eq(r.view_for({"id": "p7"}).knows, [], "Oberon não vê ninguém")
	eq(r.view_for({"role": "board"}).role, "", "tabuleiro não vê papel")
	eq(r.view_for({"id": "p2"}).all_roles, {}, "ninguém vê os papéis antes do fim")


func test_reveal_waits_everyone() -> void:
	var r := _game(5)
	r.apply(HOST, {"type": "start"})
	for i in 4:
		r.apply(_as("p%d" % i), {"type": "ready"})
	eq(r.phase, AvalonRules.PHASE_REVEAL, "falta 1")
	r.apply(_as("p4"), {"type": "ready"})
	eq(r.phase, AvalonRules.PHASE_TEAM, "todos prontos: líder monta o time")


func test_team_and_vote_rules() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	check(not r.apply(_as("p1"), {"type": "select_team", "ids": ["p1", "p2"]}).ok, "só o líder escolhe")
	check(not r.apply(_as("p0"), {"type": "select_team", "ids": ["p0", "p1", "p2"]}).ok, "missão 1 com 5 leva 2")
	r.apply(_as("p0"), {"type": "select_team", "ids": ["p0"]})
	check(not r.apply(_as("p0"), {"type": "propose"}).ok, "time incompleto não vai")
	r.apply(_as("p0"), {"type": "select_team", "ids": ["p0", "p1"]})
	check(r.apply(_as("p0"), {"type": "propose"}).ok, "time completo vai pra votação")
	# 2 a favor, 3 contra: rejeitado
	for i in 5:
		r.apply(_as("p%d" % i), {"type": "vote", "approve": i < 2})
	eq(r.phase, AvalonRules.PHASE_VOTE_RESULT, "resultado do voto")
	eq(r.history.back().approved, false, "rejeitado")
	eq(r.rejects, 1, "uma recusa")
	r.apply(HOST, {"type": "continue"})
	eq(r.leader_id(), "p1", "liderança passa")
	eq(r.phase, AvalonRules.PHASE_TEAM, "novo time")


func test_tie_is_rejection() -> void:
	var r := _rigged(["merlin", "servo", "servo", "servo", "assassino", "lacaio"])
	r.apply(_as("p0"), {"type": "select_team", "ids": ["p0", "p1"]})
	r.apply(_as("p0"), {"type": "propose"})
	for i in 6:
		r.apply(_as("p%d" % i), {"type": "vote", "approve": i < 3})
	eq(r.history.back().approved, false, "3 x 3 é rejeição")


func test_five_rejections_evil_wins() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	for k in 5:
		_team_and_vote(r, [r.leader_id(), "p%d" % ((r.leader + 1) % 5)], false)
	eq(r.phase, AvalonRules.PHASE_GAME_OVER, "acabou")
	eq([r.winner, r.win_reason], ["mal", "rejects"], "mal vence por 5 recusas")


func test_rejects_reset_on_approval() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	_team_and_vote(r, ["p0", "p1"], false)
	_team_and_vote(r, ["p1", "p2"], true)
	eq(r.rejects, 0, "aprovado zera as recusas")
	eq(r.phase, AvalonRules.PHASE_QUEST, "missão")


func test_good_cannot_fail() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	_team_and_vote(r, ["p1", "p3"])
	var res := r.apply(_as("p1"), {"type": "quest_card", "success": false})
	check(not res.ok and res.error.contains("só podem jogar Sucesso"), "bem não joga Falha")
	check(not r.apply(_as("p2"), {"type": "quest_card", "success": true}).ok, "quem não está no time não joga")
	r.apply(_as("p1"), {"type": "quest_card", "success": true})
	r.apply(_as("p3"), {"type": "quest_card", "success": false})
	eq(r.results, ["fail"], "uma falha derruba a missão")
	eq(r.last_quest.fails, 1, "1 falha")


func test_fourth_quest_needs_two_fails() -> void:
	var r := _rigged(["merlin", "servo", "servo", "servo", "assassino", "lacaio", "lacaio"])
	r.quest = 3
	r.results = ["ok", "fail", "ok"]
	_team_and_vote(r, ["p0", "p1", "p2", "p4"])
	_play_quest_no_continue(r, {"p4": true})
	eq(r.results.back(), "ok", "1 falha na 4ª com 7 não derruba")
	var r2 := _rigged(["merlin", "servo", "servo", "servo", "assassino", "lacaio", "lacaio"])
	r2.quest = 3
	r2.results = ["ok", "fail", "ok"]
	_team_and_vote(r2, ["p0", "p1", "p4", "p5"])
	_play_quest_no_continue(r2, {"p4": true, "p5": true})
	eq(r2.results.back(), "fail", "2 falhas derrubam")


func _play_quest_no_continue(r: AvalonRules, fails: Dictionary) -> void:
	for id in r.team:
		r.apply(_as(id), {"type": "quest_card", "success": not fails.has(id)})


func test_three_fails_evil_wins() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	for q in 3:
		var size: int = r.quest_sizes()[r.quest]
		var t := ["p3"]
		for i in range(5):
			if t.size() < size and "p%d" % i != "p3":
				t.append("p%d" % i)
		_team_and_vote(r, t)
		_play_quest(r, {"p3": true})
	eq([r.winner, r.win_reason], ["mal", "quests"], "3 falhas: mal vence")


func test_assassination() -> void:
	for hit in [true, false]:
		var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
		for q in 3:
			var size: int = r.quest_sizes()[r.quest]
			_team_and_vote(r, ["p0", "p1", "p2"].slice(0, size))
			_play_quest(r)
		eq(r.phase, AvalonRules.PHASE_ASSASSIN, "3 sucessos com Merlin: assassinato")
		var ev: Array = r.view_for({"id": "p4"}).evil_team.map(func(e): return e.id)
		eq(ev, ["p3", "p4"], "os maus se veem no assassinato")
		check(not r.apply(_as("p4"), {"type": "assassinate", "id": "p0"}).ok, "só o Assassino escolhe")
		check(not r.apply(_as("p3"), {"type": "assassinate", "id": "p4"}).ok, "não mata alguém do mal")
		r.apply(_as("p3"), {"type": "assassinate", "id": "p0" if hit else "p1"})
		eq(r.winner, "mal" if hit else "bem", "acertou Merlin: %s" % hit)
		eq(r.view_for({"id": "p1"}).all_roles.size(), 5, "no fim todo mundo vê os papéis")


func test_without_merlin_good_wins_directly() -> void:
	var r := _game(5, [])
	r.apply(HOST, {"type": "start"})
	r.leader = 0
	for i in 5:
		r.apply(_as("p%d" % i), {"type": "ready"})
	var good: Array = r.players.filter(func(p): return not r.is_evil(p.id)).map(func(p): return p.id)
	for q in 3:
		_team_and_vote(r, good.slice(0, r.quest_sizes()[r.quest]))
		_play_quest(r)
	eq([r.winner, r.win_reason], ["bem", "quests"], "sem Merlin, 3 sucessos: bem vence")


func test_lady_of_the_lake() -> void:
	var r := _rigged(["merlin", "servo", "servo", "servo", "assassino", "lacaio", "lacaio"], true)
	eq(r.lady, "p6", "Dama começa à direita do líder")
	for q in 2:
		var size: int = r.quest_sizes()[r.quest]
		_team_and_vote(r, ["p0", "p1", "p2", "p3"].slice(0, size))
		_play_quest(r, {} if q == 0 else {"p4": true})
	# a missão 2 teve só gente do bem, então passou; vem a Dama
	eq(r.phase, AvalonRules.PHASE_LADY, "depois da missão 2: Dama")
	check(not r.apply(_as("p0"), {"type": "lady_examine", "id": "p4"}).ok, "só quem tem a Dama examina")
	check(not r.apply(_as("p6"), {"type": "lady_examine", "id": "p6"}).ok, "não examina a si mesmo")
	check(r.apply(_as("p6"), {"type": "lady_examine", "id": "p4"}).ok, "examina")
	eq(r.view_for({"id": "p6"}).lady_seen, [{"id": "p4", "evil": true}], "só o dono vê o resultado")
	eq(r.view_for({"id": "p0"}).lady_seen, [], "os outros não")
	r.apply(_as("p6"), {"type": "continue"})
	eq(r.lady, "p4", "a Dama passa pra quem foi examinado")
	check("p6" in r.lady_used and "p4" in r.lady_used, "os dois já tiveram a Dama")
	eq(r.phase, AvalonRules.PHASE_TEAM, "segue pra missão 3")
	var small := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"], true)
	check(not small.lady_on(), "com 5 a Dama não entra")


func test_timer_view() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	r.config.timer_min = 2
	r.team_since = 1000
	eq(r.view_for({"id": "p0"}, 31000).timer_left_ms, 90000, "faltam 90 s")
	r.config.timer_min = 0
	eq(r.view_for({"id": "p0"}, 31000).timer_left_ms, -1, "desligado")


func test_rematch_new_roles() -> void:
	var r := _rigged(["merlin", "servo", "servo", "assassino", "lacaio"])
	_team_and_vote(r, ["p0", "p1"], false)
	r.phase = AvalonRules.PHASE_GAME_OVER
	eq(r.apply(HOST, {"type": "rematch"}).ok, true, "jogar de novo")
	eq(r.phase, AvalonRules.PHASE_REVEAL, "nova revelação")
	eq(r.history, [], "histórico zerado")
	eq(r.rejects, 0, "recusas zeradas")
