extends TestCase
## Testes da Corrida (Wordle e Senha) e do Duelo do Senha pela rede (docs/PLANO_WORDLE_SENHA.md §4.4, §5).

const HOST := {"id": "", "host": true, "now": 0}


func _as(id: String, now := 0) -> Dictionary:
	return {"id": id, "host": false, "now": now}


func _race(rules: RaceRules, n: int, cfg := {}) -> RaceRules:
	for i in n:
		rules.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	if not cfg.is_empty():
		var a := cfg.duplicate()
		a.type = "set_config"
		check(rules.apply(HOST, a).ok, "config")
	check(rules.apply(HOST, {"type": "start"}).ok, "start")
	eq(rules.phase, "countdown", "contagem")
	rules.tick(rules.start_at)
	eq(rules.phase, "play", "valendo")
	return rules


func _g(rules: RaceRules, id: String, a: Dictionary, t: int) -> Array:
	var x := a.duplicate()
	x.type = "guess"
	x.player = id
	x.t = rules.start_at + t
	return rules.resolve_timed([x], rules.start_at + t).events


func _wrong_word(secret: String) -> String:
	for w in ["carta", "barco", "praia", "livro"]:
		if w != secret:
			return w
	return "sonho"


func test_wordle_corrida_menos_tentativas() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(3), 3)
	var s := r.secret
	check(WordleWords.is_valid(s), "segredo é palavra")
	check(s != WordleWords.norm(WordleWords.daily(Desafio.day_index())), "não é a do dia")
	var ev := _g(r, "p0", {"word": "xqzwk"}, 100)
	eq(ev[0].type, "rejected", "palavra inválida")
	eq(r.boards.p0.guesses.size(), 0, "não gastou tentativa")
	var bad := _wrong_word(s)
	_g(r, "p0", {"word": bad}, 200)
	_g(r, "p0", {"word": s}, 300) # p0: 2 tentativas, 300 ms
	_g(r, "p1", {"word": s}, 150) # p1: 1 tentativa
	var v := r.view_for({"id": "p2", "role": "player"})
	eq(v.secret, null, "segredo escondido")
	var o0: Dictionary = v.others.filter(func(o): return o.id == "p0")[0]
	eq(o0.c.size(), 2, "cores do outro")
	check(not JSON.stringify(v).contains(bad), "letras dos outros não vazam")
	for i in 6:
		_g(r, "p2", {"word": bad}, 400 + i)
	eq(r.phase, "game_over", "todos terminaram")
	eq(r.results[0].id, "p1", "1ª: menos tentativas")
	eq(r.results[1].id, "p0", "2º")
	eq(r.results[2].id, "p2", "quem não acertou fica atrás")
	eq(r.view_for({"id": "p2", "role": "player"}).secret, WordleWords.display(s), "revela no fim")


func test_primeiro_a_acertar_e_os_outros_continuam() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(4), 3, {"criterio": "primeiro"})
	var s := r.secret
	var bad := _wrong_word(s)
	_g(r, "p0", {"word": bad}, 100)
	_g(r, "p0", {"word": s}, 200)
	eq(r.phase, "play", "os outros continuam")
	_g(r, "p1", {"word": s}, 900)
	_g(r, "p2", {"word": s}, 500)
	eq(r.results.map(func(x): return x.id), ["p0", "p2", "p1"], "ordem de chegada")


func test_janela_decide_pela_hora() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(5), 2, {"criterio": "primeiro"})
	var s := r.secret
	var list := [
		{"type": "guess", "player": "p0", "word": s, "t": r.start_at + 250},
		{"type": "guess", "player": "p1", "word": s, "t": r.start_at + 240},
	]
	r.resolve_timed(list, r.start_at + 300)
	eq(r.results[0].id, "p1", "chegou depois, mas tocou antes")


func test_pontos_em_rodadas() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(6), 2, {"criterio": "pontos", "rodadas": 3})
	var first := r.secret
	_g(r, "p0", {"word": first}, 100) # 6 + 1 - 1 + 3 = 9
	_g(r, "p1", {"word": _wrong_word(first)}, 100)
	_g(r, "p1", {"word": first}, 200) # 6 + 1 - 2 + 2 = 7
	eq(r.phase, "round_end", "fim da rodada")
	eq(int(r.player("p0").score), 9, "pontos p0")
	eq(int(r.player("p1").score), 7, "pontos p1")
	check(not r.apply(_as("p1"), {"type": "next_round"}).ok, "só o host chama")
	check(r.apply({"id": "", "host": true, "now": 5000}, {"type": "next_round"}).ok, "próxima")
	check(r.secret != first, "palavra nova")
	for k in 2:
		r.tick(r.start_at)
		var s := r.secret
		_g(r, "p1", {"word": s}, 50)
		_g(r, "p0", {"word": s}, 60)
		if r.phase == "round_end":
			r.apply({"id": "", "host": true, "now": 9000 * (k + 1)}, {"type": "next_round"})
	eq(r.phase, "game_over", "3 rodadas")
	eq(int(r.player("p0").score), int(r.player("p1").score), "25 a 25")
	eq(r.standings()[0].id, "p0", "empate: ganha quem somou menos tempo")


func test_tempo_limite() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(7), 2, {"tempo_min": 2})
	_g(r, "p0", {"word": r.secret}, 100)
	r.tick(r.start_at + 119000)
	eq(r.phase, "play", "ainda no tempo")
	r.tick(r.start_at + 120000)
	eq(r.phase, "game_over", "acabou o tempo")
	eq(r.results[1].solved, false, "p1 perdeu")


func test_quem_cai_nao_segura_a_rodada() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(8), 2)
	_g(r, "p0", {"word": r.secret}, 100)
	eq(r.phase, "play", "esperando p1")
	r.set_connected("p1", false)
	eq(r.phase, "game_over", "p1 caiu")


func test_modo_dificil_na_corrida() -> void:
	var r: WordleNetRules = _race(WordleNetRules.new(9), 2, {"dificil": true})
	r.secret = "barco"
	_g(r, "p0", {"word": "carta"}, 10)
	var ev := _g(r, "p0", {"word": "porta"}, 20)
	eq(ev[0].type, "rejected", "difícil vale pra todos")


func test_senha_corrida() -> void:
	var r: SenhaNetRules = _race(SenhaNetRules.new(3), 2, {"nivel": "facil", "retorno": "posicao"})
	var ev := _g(r, "p0", {"pins": [0, 0, 1, 2]}, 10)
	eq(ev[0].type, "rejected", "fácil não repete")
	_g(r, "p0", {"pins": r.secret}, 20)
	var v := r.view_for({"id": "p1", "role": "player"})
	eq(v.pins, 4, "pinos")
	eq(v.others[0].c[0], [2, 2, 2, 2], "cores por posição")
	_g(r, "p1", {"pins": r.secret}, 30)
	eq(r.phase, "game_over", "fim")


func _duel(tipo: String) -> SenhaNetRules:
	var r := SenhaNetRules.new(11)
	for i in 3:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	r.apply(HOST, {"type": "set_config", "modo": "duelo", "duelo": tipo, "nivel": "medio"})
	check(not r.apply(HOST, {"type": "start"}).ok, "duelo com 3 não começa")
	r.apply(HOST, {"type": "remove_player", "id": "p2"})
	check(r.apply(HOST, {"type": "start"}).ok, "start")
	eq(r.phase, "create", "criar senhas")
	check(not r.apply(_as("p0"), {"type": "set_code", "pins": [0, 1]}).ok, "senha incompleta")
	check(r.apply(_as("p0"), {"type": "set_code", "pins": [0, 1, 2, 3]}).ok, "senha p0")
	var v := r.view_for({"id": "p1", "role": "player"})
	check(not JSON.stringify(v).contains("[0,1,2,3]"), "p1 não vê a senha de p0")
	check(r.apply(_as("p1", 1000), {"type": "set_code", "pins": [5, 5, 4, 4]}).ok, "senha p1")
	eq(r.phase, "countdown", "contagem")
	r.tick(r.start_at)
	return r


func test_duelo_alternado_com_ultima_chance() -> void:
	var r := _duel("alternado")
	var a := r.starter
	var b := r.other_of(a)
	var code_of := func(id): return r.codes[r.other_of(id)]
	var ev := _g(r, b, {"pins": [0, 0, 0, 0]}, 10)
	eq(ev[0].type, "rejected", "não é a vez")
	_g(r, a, {"pins": code_of.call(a)}, 20)
	eq(r.phase, "play", "quem começou acertou: o outro tem a última chance")
	eq(r.turn, b, "vez do outro")
	var v := r.view_for({"id": b, "role": "player"})
	eq(v.opp_board.guesses.size(), 1, "vê o ataque contra a própria senha")
	_g(r, b, {"pins": code_of.call(b)}, 30)
	eq(r.phase, "game_over", "fim")
	eq(r.winner, "", "os dois acertaram: empate")


func test_duelo_alternado_vitoria() -> void:
	var r := _duel("alternado")
	var a := r.starter
	var b := r.other_of(a)
	_g(r, a, {"pins": [3, 3, 3, 3]}, 10)
	_g(r, b, {"pins": r.codes[a]}, 20)
	eq(r.phase, "game_over", "b acertou fechando a rodada")
	eq(r.winner, b, "b venceu")


func test_duelo_tempo() -> void:
	var r := _duel("tempo")
	var list := [
		{"type": "guess", "player": "p0", "pins": r.codes.p1, "t": r.start_at + 500},
		{"type": "guess", "player": "p1", "pins": r.codes.p0, "t": r.start_at + 400},
	]
	r.resolve_timed(list, r.start_at + 600)
	eq(r.winner, "p1", "quebrou primeiro")
	eq(r.view_for({"id": "p0", "role": "player"}).codes.size(), 2, "revela as duas senhas")
