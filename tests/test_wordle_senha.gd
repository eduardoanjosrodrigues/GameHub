extends TestCase
## Testes da lógica do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md §3, §4, §9).


func test_cores_com_letras_repetidas() -> void:
	eq(WordleLogic.score("aaaaa", "carta"), [0, 2, 0, 0, 2], "AAAAA em CARTA")
	eq(WordleLogic.score("arara", "carta"), [1, 1, 0, 0, 2], "ARARA em CARTA")
	eq(WordleLogic.score("carta", "carta"), [2, 2, 2, 2, 2], "acerto")
	eq(WordleLogic.score("totem", "motel"), [0, 2, 2, 2, 1], "TOTEM em MOTEL")
	eq(WordleLogic.score("ossos", "sabor"), [0, 1, 0, 2, 0], "OSSOS em SABOR")
	check(WordleLogic.solved([2, 2, 2, 2, 2]), "resolvido")
	check(not WordleLogic.solved([2, 2, 2, 2, 1]), "não resolvido")


func test_acento_nao_conta() -> void:
	eq(WordleWords.norm("Canção"), "cancao", "sem acento")
	eq(WordleWords.norm("ÓTIMO"), "otimo", "maiúsculas")
	check(WordleWords.is_valid("otimo"), "ótimo é palpite")
	eq(WordleWords.display("otimo"), "ótimo", "mostra com acento")
	check(WordleWords.is_valid("casas"), "plural é palpite")
	check(WordleWords.is_valid("falei"), "verbo conjugado é palpite")
	check(not WordleWords.is_valid("xqzwk"), "letra solta não vale")


func test_respostas_sao_palpites_e_sem_repetir() -> void:
	var seen := {}
	for a in WordleWords.answers():
		var n := WordleWords.norm(a)
		check(n.length() == 5, "%s tem 5 letras" % a)
		check(WordleWords.is_valid(n), "%s está nos palpites" % a)
		check(not seen.has(n), "%s repetida" % a)
		seen[n] = true
	check(WordleWords.answers().size() >= 900, "pelo menos 900 respostas")


func test_palavra_do_dia_fixa_e_sem_repetir() -> void:
	eq(WordleWords.daily(10), WordleWords.daily(10), "mesmo dia, mesma palavra")
	var n := WordleWords.answers().size()
	var seen := {}
	for d in n:
		seen[WordleWords.daily(d)] = true
	eq(seen.size(), n, "nenhuma repete até a lista acabar")
	eq(WordleWords.daily(n), WordleWords.daily(0), "depois recomeça")


func test_treino_evita_as_do_dia() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var today := 3
	var blocked := {}
	for d in range(0, today + WordleWords.TRAINING_GUARD_DAYS + 1):
		blocked[WordleWords.daily(d)] = true
	for i in 200:
		var w: String = WordleWords.random_training(rng, today)[0]
		check(not blocked.has(w), "%s é do dia" % w)
	var four := WordleWords.random_training(rng, today, 4)
	eq(four.size(), 4, "quarteto")
	var uniq := {}
	for w in four:
		uniq[w] = true
	eq(uniq.size(), 4, "quatro diferentes")


func test_dia_vira_a_meia_noite() -> void:
	eq(Desafio.day_index(Desafio.EPOCH), 0, "dia 0")
	eq(Desafio.day_index({"year": 2026, "month": 9, "day": 29}), 1, "dia seguinte")
	eq(Desafio.day_index({"year": 2026, "month": 10, "day": 1}), 3, "virada de mês")
	eq(Desafio.day_index({"year": 2027, "month": 9, "day": 28}), 365, "um ano")
	eq(Desafio.shuffled(10, 1), Desafio.shuffled(10, 1), "embaralhado fixo")


func test_modo_dificil() -> void:
	var h := [{"n": "carta", "c": WordleLogic.score("carta", "barco")}] # _ 2 2 _ _ ; c amarela
	eq(WordleLogic.hard_violation("porta", h), "A 2ª letra precisa ser A", "verde fora do lugar")
	eq(WordleLogic.hard_violation("barra", h), "O palpite precisa ter C", "faltou a amarela")
	eq(WordleLogic.hard_violation("barco", h), "", "vale")


func test_teclado_guarda_a_melhor_cor() -> void:
	var h := [{"n": "arara", "c": [1, 1, 0, 0, 2]}]
	var k := WordleLogic.key_colors(h)
	eq(k.a, 2, "A verde")
	eq(k.r, 1, "R amarela")


func test_senha_contagem_e_posicao() -> void:
	eq(SenhaLogic.feedback([0, 1, 2, 3], [0, 1, 2, 3], "contagem"), [4, 0], "acerto")
	eq(SenhaLogic.feedback([3, 2, 1, 0], [0, 1, 2, 3], "contagem"), [0, 4], "tudo fora do lugar")
	eq(SenhaLogic.feedback([0, 0, 1, 1], [0, 1, 0, 2], "contagem"), [1, 2], "repetidos contam uma vez")
	eq(SenhaLogic.feedback([5, 5, 5, 5], [5, 1, 2, 3], "contagem"), [1, 0], "um só")
	eq(SenhaLogic.feedback([0, 0, 1, 1], [0, 1, 0, 2], "posicao"), [2, 1, 1, 0], "por posição")
	check(SenhaLogic.solved([4, 0], "contagem", 4), "resolvido contagem")
	check(SenhaLogic.solved([2, 2, 2, 2, 2], "posicao", 5), "resolvido posição")
	check(not SenhaLogic.solved([3, 1], "contagem", 4), "não resolvido")


func test_senha_niveis() -> void:
	eq(SenhaLogic.check([0, 1, 2, 3], "facil"), "", "fácil sem repetir")
	check(SenhaLogic.check([0, 0, 2, 3], "facil") != "", "fácil não repete")
	eq(SenhaLogic.check([0, 0, 2, 3], "medio"), "", "médio repete")
	check(SenhaLogic.check([0, 1, 2, 6], "medio") != "", "médio só tem 6 símbolos")
	eq(SenhaLogic.check([7, 7, 0, 1, 2], "dificil"), "", "difícil: 5 pinos, 8 símbolos")
	check(SenhaLogic.check([0, 1, 2, 3], "dificil") != "", "difícil pede 5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 100:
		eq(SenhaLogic.check(SenhaLogic.random_code("facil", rng), "facil"), "", "sorteio fácil")
		eq(SenhaLogic.check(SenhaLogic.random_code("dificil", rng), "dificil"), "", "sorteio difícil")
	eq(SenhaLogic.daily_code(4, "medio"), SenhaLogic.daily_code(4, "medio"), "senha do dia fixa")
	check(SenhaLogic.daily_code(4, "medio") != SenhaLogic.daily_code(5, "medio") or SenhaLogic.daily_code(4, "medio") != SenhaLogic.daily_code(6, "medio"), "muda com o dia")


func test_estatisticas_e_sequencia() -> void:
	DesafioStore.reset_for_tests()
	DesafioStore.record("t", true, 3, 10)
	DesafioStore.record("t", true, 4, 11)
	var s := DesafioStore.stats("t", 11)
	eq(s.streak, 2, "sequência de 2")
	eq(s.best, 2, "melhor")
	eq(s.played, 2, "jogos")
	eq(int(s.dist["3"]), 1, "gráfico")
	eq(DesafioStore.stats("t", 13).streak, 0, "pulou um dia")
	DesafioStore.record("t", true, 2, 13)
	eq(DesafioStore.stats("t", 13).streak, 1, "recomeça")
	DesafioStore.record("t", false, 0, 14)
	eq(DesafioStore.stats("t", 14).streak, 0, "perdeu")
	eq(DesafioStore.stats("t", 14).best, 2, "melhor fica")


func test_partida_do_dia_abandonada_vira_derrota() -> void:
	DesafioStore.reset_for_tests()
	DesafioStore.record("d", true, 3, 4)
	DesafioStore.save_game("d", {"day": 5, "finished": false, "guesses": ["carta"]})
	eq(DesafioStore.today_game("d", 5).get("day"), 5, "mesmo dia continua")
	eq(DesafioStore.today_game("d", 6), {}, "no outro dia some")
	var s := DesafioStore.stats("d", 6)
	eq(s.played, 2, "contou como jogo")
	eq(s.won, 1, "derrota")
	eq(s.streak, 0, "zerou")
	DesafioStore.save_game("d", {"day": 6, "finished": true})
	DesafioStore.today_game("d", 7)
	eq(DesafioStore.stats("d", 7).played, 2, "terminada não conta de novo")
