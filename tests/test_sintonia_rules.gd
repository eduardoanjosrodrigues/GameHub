extends TestCase
## Testes das regras da Sintonia (docs/PLANO_SINTONIA_ITO.md §3, marco T1).

const HOST := {"id": "", "host": true}
const THEMES := ["Frio|Quente", "Barato|Caro", "Fácil|Difícil", "Feio|Bonito"]


func _as(id: String) -> Dictionary:
	return {"id": id, "host": false}


## Times: p0, p2 no azul; p1, p3 no vermelho (entram alternando).
func _game(n := 4, mode := "times", seed_value := 11) -> SintoniaRules:
	var r := SintoniaRules.new(THEMES, seed_value)
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "set_config", "mode": mode})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	return r


## Uma rodada inteira: o alvo vai pra `target`, a agulha pra `pos`, aposta `bet`.
func _round(r: SintoniaRules, target: float, pos: float, bet := "left") -> void:
	check(r.apply(_as(r.psychic), {"type": "pick_theme", "index": 0}).ok, "tema")
	r.target = target
	var turner := _turner(r)
	check(r.apply(_as(turner), {"type": "dial", "pos": pos}).ok, "girar")
	check(r.apply(_as(turner), {"type": "lock"}).ok, "travar")
	if r.config.mode == "times":
		var bettor: String = r.team_members(r.other(r.turn_team))[0].id
		check(r.apply(_as(bettor), {"type": "side", "side": bet}).ok, "apostar")
		check(r.apply(_as(bettor), {"type": "lock_side"}).ok, "travar aposta")
	eq(r.phase, "reveal", "revelou")


func _turner(r: SintoniaRules) -> String:
	for p in r.players:
		if p.id != r.psychic and (r.config.mode == "coop" or p.team == r.turn_team):
			return p.id
	return ""


func test_zones() -> void:
	eq(SintoniaRules.points_for(0.0), 4, "centro")
	eq(SintoniaRules.points_for(2.0), 4, "na linha vale a melhor")
	eq(SintoniaRules.points_for(2.5), 3, "3")
	eq(SintoniaRules.points_for(6.0), 3, "linha do 3")
	eq(SintoniaRules.points_for(9.5), 2, "2")
	eq(SintoniaRules.points_for(10.5), 0, "fora")


func test_teams_setup() -> void:
	var r := SintoniaRules.new(THEMES, 1)
	for i in 3:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	check(r.can_start() != "", "3 não jogam com times")
	r.apply(HOST, {"type": "add_player", "name": "J3", "id": "p3"})
	eq(r.can_start(), "", "4 jogam")
	r.apply(HOST, {"type": "set_team", "id": "p1", "team": "azul"})
	check(r.can_start() != "", "time com 1 não joga")
	check(not r.apply(_as("p0"), {"type": "shuffle_teams"}).ok, "só o host sorteia")
	r.apply(HOST, {"type": "shuffle_teams"})
	eq(r.team_members("azul").size(), 2, "sorteio equilibra")
	r.apply(HOST, {"type": "set_config", "mode": "coop"})
	var c := SintoniaRules.new(THEMES, 1)
	c.apply(HOST, {"type": "set_config", "mode": "coop"})
	c.apply(HOST, {"type": "add_player", "name": "A", "id": "a"})
	check(c.can_start() != "", "cooperativo com 1 não")
	c.apply(HOST, {"type": "add_player", "name": "B", "id": "b"})
	eq(c.can_start(), "", "cooperativo com 2")


func test_start_second_team_gets_point() -> void:
	var r := _game()
	eq(r.scores[r.other(r.turn_team)], 1, "o outro time começa com 1")
	eq(r.scores[r.turn_team], 0, "o da vez com 0")
	eq(r.player(r.psychic).team, r.turn_team, "a dica é do time da vez")
	eq(r.phase, "pick", "escolha do tema")


func test_permissions_and_view() -> void:
	var r := _game()
	var psy := r.psychic
	var mate := _turner(r)
	var rival: String = r.team_members(r.other(r.turn_team))[0].id
	check(not r.apply(_as(mate), {"type": "pick_theme", "index": 0}).ok, "só quem dá a dica escolhe")
	eq(r.view_for({"id": psy, "role": "player"}).options.size(), 2, "quem dá a dica vê 2 temas")
	eq(r.view_for({"id": mate, "role": "player"}).options, [], "os outros não")
	check(r.view_for({"id": psy, "role": "player"}).target >= 10.0, "quem dá a dica vê o alvo")
	eq(r.view_for({"id": mate, "role": "player"}).target, -1.0, "o time não vê o alvo")
	eq(r.view_for({"id": "", "role": "board"}).target, -1.0, "o tabuleiro não vê o alvo")
	check(r.apply(_as(psy), {"type": "custom_theme", "left": "Silencioso", "right": "Barulhento"}).ok, "tema digitado")
	eq(r.theme, ["Silencioso", "Barulhento"], "tema")
	check(not r.apply(_as(psy), {"type": "dial", "pos": 30}).ok, "quem deu a dica não gira")
	check(not r.apply(_as(rival), {"type": "dial", "pos": 30}).ok, "o outro time não gira")
	check(r.apply(_as(mate), {"type": "dial", "pos": 33.3}).ok, "o time gira")
	eq(r.dial, 33.5, "anda de 0,5 em 0,5")
	check(r.apply({"id": "", "board": true}, {"type": "dial", "pos": 120}).ok, "tabuleiro gira")
	eq(r.dial, 100.0, "limite")
	check(not r.apply(_as(mate), {"type": "side", "side": "left"}).ok, "aposta só depois de travar")
	r.apply(_as(mate), {"type": "lock"})
	check(not r.apply(_as(mate), {"type": "side", "side": "left"}).ok, "o time da vez não aposta")
	check(not r.apply(_as(rival), {"type": "lock_side"}).ok, "trava só com aposta")
	check(r.apply(_as(rival), {"type": "side", "side": "left"}).ok, "o outro aposta")


func test_scoring_and_side_bet() -> void:
	var r := _game()
	var t := r.turn_team
	var before: Dictionary = r.scores.duplicate()
	_round(r, 50.0, 55.0, "left") # 5 de distância: 3 pontos; alvo à esquerda: aposta certa
	eq(r.last.points, 3, "3 pontos")
	eq(r.last.side_points, 1, "aposta certa")
	eq(r.scores[t], before[t] + 3, "placar do time")
	eq(r.scores[r.other(t)], before[r.other(t)] + 1, "placar do outro")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.turn_team, r.other(t), "vez do outro time")
	var t2 := r.turn_team
	var b2: Dictionary = r.scores.duplicate()
	_round(r, 40.0, 40.0, "left") # centro: o outro time não pontua
	eq(r.last.points, 4, "centro")
	eq(r.last.side_points, 0, "centro anula a aposta")
	eq(r.scores[r.other(t2)], b2[r.other(t2)], "outro time sem ponto")


func test_catch_up() -> void:
	var r := _game()
	var t := r.turn_team
	r.scores[t] = 0
	r.scores[r.other(t)] = 6
	_round(r, 50.0, 50.0, "right")
	check(r.last.catch_up, "recuperação")
	var psy := r.psychic
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.turn_team, t, "joga de novo")
	check(r.psychic != psy, "outra pessoa dá a dica")


func test_win_and_sudden_death() -> void:
	var r := _game()
	var t := r.turn_team
	r.scores[t] = 7
	r.scores[r.other(t)] = 5
	_round(r, 50.0, 55.0, "right") # 3 pontos, aposta errada: 10 x 5
	eq(r.winner, t, "chegou a 10")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.phase, "game_over", "fim")
	# Empate em 10: morte súbita, uma rodada pra cada.
	var s := _game(4, "times", 21)
	var a := s.turn_team
	s.scores[a] = 7
	s.scores[s.other(a)] = 9
	_round(s, 50.0, 55.0, "left") # 3 pra um, 1 pro outro: 10 x 10
	eq(s.winner, "", "empate não termina")
	check(s.sudden, "morte súbita")
	s.apply(_as("p0"), {"type": "continue"})
	eq(s.turn_team, s.other(a), "vez do outro")
	_round(s, 50.0, 80.0, "left") # 0 pro time, aposta certa +1 pro outro: 11 x 10
	eq(s.winner, "", "só depois das duas rodadas")
	s.apply(_as("p0"), {"type": "continue"})
	_round(s, 50.0, 90.0, "right") # 0 e aposta errada: 11 x 10
	eq(s.winner, a, "vence quem ficou na frente")


func test_coop() -> void:
	var r := _game(3, "coop")
	eq(r.turn_team, "", "sem time")
	eq(r.cards_left, 7, "7 rodadas")
	var psy := r.psychic
	check(not r.apply(_as(psy), {"type": "dial", "pos": 10}).ok, "quem dá a dica não gira")
	_round(r, 50.0, 50.0)
	eq(r.last.points, 3, "centro vale 3")
	check(r.last.bonus, "rodada extra")
	eq(r.cards_left, 7, "ganhou uma rodada")
	eq(r.coop_score, 3, "pontos")
	for k in 7:
		r.apply(_as("p0"), {"type": "continue"})
		_round(r, 50.0, 70.0)
	eq(r.cards_left, 0, "acabaram as rodadas")
	eq(r.winner, "coop", "fim do cooperativo")
	r.apply(_as("p0"), {"type": "continue"})
	eq(r.phase, "game_over", "fim")
	check(r.apply(HOST, {"type": "rematch"}).ok, "revanche")
	eq(r.cards_left, 7, "7 de novo")


func test_local_mode() -> void:
	var r := SintoniaRules.new(THEMES, 5)
	r.local_mode = true
	var L := {"id": "", "host": true, "local": true}
	for n in ["Ana", "Bia", "Caio", "Duda"]:
		r.apply(L, {"type": "add_player", "name": n})
	check(r.apply(L, {"type": "start"}).ok, "começa")
	eq(r.view_for({"id": "", "role": "local"}).target, -1.0, "mesa não vê o alvo")
	check(r.view_for({"id": r.psychic, "role": "player"}).target >= 10.0, "quem dá a dica vê")
	check(r.apply(L, {"type": "pick_theme", "index": 1}).ok, "escolhe por quem dá a dica")
	check(r.apply(L, {"type": "dial", "pos": 20}).ok, "gira")
	check(r.apply(L, {"type": "lock"}).ok, "trava")
	check(r.apply(L, {"type": "side", "side": "right"}).ok, "aposta")
	check(r.apply(L, {"type": "lock_side"}).ok, "trava a aposta")
	eq(r.phase, "reveal", "revela")
