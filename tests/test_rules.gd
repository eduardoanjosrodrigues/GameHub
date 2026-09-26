extends TestCase
## Testes das regras do Chapéu (docs/PLANO_FASE_1.md §3).

const HOST := {"id": "", "host": true}
const LISTS := {
	"t1": {"nome": "Tema 1", "palavras": ["Pelé", "Xuxa", "Banana", "Gato", "Sol", "Lua", "Mar", "Rio", "Céu", "Pão", "Mão", "Pé"]},
}


func _game(mode := "local", wpp := 1, names := ["Ana", "Bia", "Caio", "Duda"], teams := ["azul", "azul", "vermelho", "vermelho"]) -> ChapeuRules:
	var r := ChapeuRules.new(mode, LISTS, 42)
	for i in names.size():
		r.apply(HOST, {"type": "add_player", "name": names[i], "id": "p%d" % i, "team": teams[i]})
	r.apply(HOST, {"type": "set_config", "words_per_player": wpp})
	return r


func _start_with_words(r: ChapeuRules, word_sets: Array) -> void:
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	for i in r.players.size():
		var res := r.apply(HOST, {"type": "submit_words", "id": r.players[i].id, "words": word_sets[i]})
		check(res.ok, "submit %d: %s" % [i, res.error])


func test_can_start_validations() -> void:
	var r := ChapeuRules.new("local", LISTS, 1)
	check(r.can_start() != "", "sem jogadores não começa")
	for n in ["A", "B", "C"]:
		r.apply(HOST, {"type": "add_player", "name": n, "team": "azul"})
	r.apply(HOST, {"type": "add_player", "name": "D", "team": "vermelho"})
	check(r.can_start().contains("Cada time"), "time com 1 jogador não começa: " + r.can_start())
	r.apply(HOST, {"type": "set_team", "id": "p3", "team": "vermelho"})
	eq(r.can_start(), "", "2 x 2 começa")
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start ok")
	eq(r.phase, ChapeuRules.PHASE_WRITING, "vai pra escrita")


func test_max_players() -> void:
	var r := ChapeuRules.new("local", LISTS, 1)
	for i in 12:
		check(r.apply(HOST, {"type": "add_player", "name": "J%d" % i}).ok, "add %d" % i)
	check(not r.apply(HOST, {"type": "add_player", "name": "Extra"}).ok, "13º jogador recusado")


func test_duplicates_allowed() -> void:
	var r := _game()
	_start_with_words(r, [["Pelé"], ["Pelé"], ["Gato"], ["pelé "]])
	eq(r.words.size(), 4, "duplicadas entram todas")
	eq(r.phase, ChapeuRules.PHASE_ROUND_INTRO, "todas enviadas -> abertura da rodada")


func test_word_validation() -> void:
	var r := _game("local", 2)
	r.apply(HOST, {"type": "start"})
	check(not r.apply(HOST, {"type": "submit_words", "id": "p0", "words": ["Um"]}).ok, "quantidade errada recusada")
	check(not r.apply(HOST, {"type": "submit_words", "id": "p0", "words": ["Um", "  "]}).ok, "vazia recusada")
	check(not r.apply(HOST, {"type": "submit_words", "id": "p0", "words": ["Um", "x".repeat(41)]}).ok, "longa recusada")
	check(r.apply(HOST, {"type": "submit_words", "id": "p0", "words": ["  Dois   espaços ", "Três"]}).ok, "válida aceita")
	eq(r.submitted.p0[0], "Dois espaços", "espaços limpos")


func test_blue_team_starts_and_alternates() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	eq(r.phase, ChapeuRules.PHASE_TURN_READY, "preparação da vez")
	eq(r.current_team(), "azul", "Time Azul começa")
	r.apply(HOST, {"type": "choose_explainer", "id": "p0"})
	r.apply(HOST, {"type": "start_turn"})
	r.tick(60000)
	eq(r.phase, ChapeuRules.PHASE_TURN_SUMMARY, "tempo acabou -> resumo")
	r.apply(HOST, {"type": "next"})
	eq(r.current_team(), "vermelho", "depois vem o vermelho")


func test_skip_penalty_and_word_returns() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "choose_explainer", "id": "p0"})
	r.apply(HOST, {"type": "start_turn"})
	var first := r.current
	r.apply(HOST, {"type": "skip"})
	eq(r.scores[0][0], -1, "pular tira 1 ponto")
	eq(r.hat.size(), 4, "palavra pulada volta pro chapéu")
	check(r.current != first, "próxima palavra é outra")
	r.apply(HOST, {"type": "skip"})
	r.apply(HOST, {"type": "skip"})
	eq(r.totals().azul, -3, "pontuação pode ficar negativa")


func test_time_up_returns_word() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "choose_explainer", "id": "p0"})
	r.apply(HOST, {"type": "start_turn"})
	r.apply(HOST, {"type": "hit"})
	r.tick(30000)
	eq(r.phase, ChapeuRules.PHASE_TURN, "ainda na vez aos 30 s")
	var ev := r.tick(30000)
	eq(r.phase, ChapeuRules.PHASE_TURN_SUMMARY, "fim da vez")
	eq(ev[0].type, "time_up", "evento de tempo esgotado")
	eq(r.hat.size(), 3, "palavra da tela voltou (só a acertada saiu)")
	eq(r.view_for({"role": "local"}).hit_words.size(), 1, "resumo mostra a acertada")


func test_pause_freezes_timer() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "choose_explainer", "id": "p0"})
	r.apply(HOST, {"type": "start_turn"})
	r.apply(HOST, {"type": "pause"})
	r.tick(60000)
	eq(r.time_ms, 60000, "pausado não conta tempo")
	check(not r.apply(HOST, {"type": "hit"}).ok, "não acerta pausado")
	eq(r.view_for({"role": "local"}).word, "", "palavra escondida na pausa")
	r.apply(HOST, {"type": "resume"})
	r.tick(1000)
	eq(r.time_ms, 59000, "volta a contar")


func test_hat_empty_carries_time_to_next_round() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "choose_explainer", "id": "p1"})
	r.apply(HOST, {"type": "start_turn"})
	r.tick(20000)
	for i in 4:
		r.apply(HOST, {"type": "hit"})
	eq(r.phase, ChapeuRules.PHASE_TURN_SUMMARY, "chapéu vazio -> resumo")
	eq(r.turn_round_over, true, "rodada acabou")
	eq(r.carry.get("ms", 0), 40000, "guarda 40 s")
	r.apply(HOST, {"type": "next"})
	eq(r.phase, ChapeuRules.PHASE_ROUND_END, "placar da rodada")
	r.apply(HOST, {"type": "next"})
	eq(r.phase, ChapeuRules.PHASE_ROUND_INTRO, "abertura da rodada 2")
	eq(r.round_idx, 1, "rodada 2")
	eq(r.hat.size(), 4, "todas as palavras voltaram")
	r.apply(HOST, {"type": "next"})
	eq(r.explainer, "p1", "mesma pessoa continua")
	eq(r.current_team(), "azul", "mesmo time")
	eq(r.time_ms, 40000, "com o tempo que sobrou")
	check(not r.apply(HOST, {"type": "choose_explainer", "id": "p0"}).ok, "não dá pra trocar quem tem tempo guardado")
	r.apply(HOST, {"type": "start_turn"})
	eq(r.player("p1").explained, 1, "continuação não conta como nova vez")
	eq(r.time_ms, 40000, "começa com 40 s")


func test_no_carry_alternates_team_next_round() -> void:
	var r := _game()
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "choose_explainer", "id": "p0"})
	r.apply(HOST, {"type": "start_turn"})
	r.tick(59500)
	for i in 4:
		r.apply(HOST, {"type": "hit"})
	check(r.carry.is_empty(), "menos de 1 s não é guardado")
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "next"})
	r.apply(HOST, {"type": "next"})
	eq(r.current_team(), "vermelho", "sem tempo guardado, vez do outro time")
	eq(r.explainer, "", "time escolhe quem explica")


func _play_round(r: ChapeuRules, azul_hits: int, verm_hits: int) -> void:
	# Joga uma rodada inteira: azul acerta azul_hits, depois o vermelho acerta o resto.
	r.apply(HOST, {"type": "next"}) # round_intro -> turn_ready
	if r.explainer == "":
		r.apply(HOST, {"type": "choose_explainer", "id": r.team_players(r.current_team())[0].id})
	r.apply(HOST, {"type": "start_turn"})
	var first_team := r.current_team()
	var n := azul_hits if first_team == "azul" else verm_hits
	for i in n:
		r.apply(HOST, {"type": "hit"})
	if r.phase == ChapeuRules.PHASE_TURN:
		r.tick(60000)
		r.apply(HOST, {"type": "next"})
		r.apply(HOST, {"type": "choose_explainer", "id": r.team_players(r.current_team())[0].id})
		r.apply(HOST, {"type": "start_turn"})
		while r.phase == ChapeuRules.PHASE_TURN:
			r.apply(HOST, {"type": "hit"})
	r.apply(HOST, {"type": "next"}) # summary -> round_end
	r.apply(HOST, {"type": "next"}) # round_end -> próxima rodada ou fim


func test_full_game_winner_by_points() -> void:
	var r := _game("local", 2)
	_start_with_words(r, [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]])
	_play_round(r, 6, 2)
	_play_round(r, 5, 3)
	_play_round(r, 4, 4)
	eq(r.phase, ChapeuRules.PHASE_GAME_OVER, "fim de jogo")
	eq(r.result.criterion, "pontos", "critério: pontos")
	check(r.result.winner != "", "tem vencedor")
	eq(r.result.totals.azul + r.result.totals.vermelho, 24, "8 palavras x 3 rodadas")


func test_tiebreak_rounds_won() -> void:
	var r := ChapeuRules.new("local", LISTS, 1)
	r.scores = [[5, 3], [4, 3], [1, 4]] # 10 x 10; azul venceu 2 rodadas
	var res := r._compute_result()
	eq(res.winner, "azul", "vence quem ganhou mais rodadas")
	eq(res.criterion, "rodadas", "critério rodadas")


func test_tiebreak_mimica() -> void:
	var r := ChapeuRules.new("local", LISTS, 1)
	r.scores = [[5, 3], [3, 5], [2, 2]] # 10 x 10, 1 x 1 rodadas, empate na mímica
	eq(r._compute_result().criterion, "empate", "empate total")
	r.scores = [[6, 4], [2, 5], [3, 2]] # 11 x 11; rodadas 2 x 1 -> rodadas
	eq(r._compute_result().criterion, "rodadas", "rodadas antes da mímica")
	r.scores = [[6, 4], [2, 4], [3, 3]] # 11 x 11; rodadas 1 x 1; mímica empatada
	eq(r._compute_result().criterion, "empate", "empate quando tudo empata")
	r.scores = [[5, 3], [2, 5], [4, 3]] # 11 x 11; rodadas 2 x 1
	eq(r._compute_result().winner, "azul", "azul por rodadas")
	r.scores = [[5, 3], [3, 3], [2, 4]] # 10 x 10; rodadas 1 x 1; mímica vermelho
	var res := r._compute_result()
	eq(res.criterion, "mimica", "desempata na mímica")
	eq(res.winner, "vermelho", "vermelho fez mais na mímica")


func test_list_and_mix_sources() -> void:
	var r := _game()
	r.apply(HOST, {"type": "set_config", "source": "lista", "list_count": 10})
	r.apply(HOST, {"type": "start"})
	eq(r.phase, ChapeuRules.PHASE_ROUND_INTRO, "só lista pula a escrita")
	eq(r.words.size(), 10, "10 da lista")

	var m := _game()
	m.apply(HOST, {"type": "set_config", "source": "mistura", "list_count": 10})
	_start_with_words(m, [["pele"], ["Gato"], ["X"], ["Y"]])
	eq(m.words.size(), 14, "4 dos jogadores + 10 da lista")
	var norm := m.words.map(func(w): return TextNorm.normalize(w))
	eq(norm.count("pele"), 1, "lista não repete palavra dos jogadores (sem acento)")
	eq(norm.count("gato"), 1, "lista não repete Gato")


func test_wifi_view_filters_word() -> void:
	var r := _game("wifi")
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	check(not r.apply({"id": "p2", "host": false}, {"type": "choose_explainer", "id": "p2"}).ok, "outro time não escolhe")
	check(r.apply({"id": "p1", "host": false}, {"type": "choose_explainer", "id": "p0"}).ok, "time da vez escolhe")
	check(not r.apply({"id": "p1", "host": false}, {"type": "start_turn"}).ok, "só o explicador começa")
	check(r.apply({"id": "p0", "host": false}, {"type": "start_turn"}).ok, "explicador começa")
	check(r.view_for({"id": "p0", "role": "player"}).word != "", "explicador vê")
	eq(r.view_for({"id": "p1", "role": "player"}).word, "", "colega não vê")
	eq(r.view_for({"id": "p2", "role": "player"}).word, "", "adversário não vê (padrão)")
	eq(r.view_for({"id": "", "role": "board"}).word, "", "tabuleiro nunca vê")
	r.config.opponent_sees_word = true
	check(r.view_for({"id": "p2", "role": "player"}).word != "", "adversário vê com a opção ligada")
	eq(r.view_for({"id": "p1", "role": "player"}).word, "", "colega continua sem ver")
	check(not r.apply({"id": "p1", "host": false}, {"type": "hit"}).ok, "só o explicador marca acerto")
	check(not r.apply(HOST, {"type": "hit"}).ok, "host no Wi-Fi não marca pelo explicador")


func test_disconnect_pauses_and_reconnect() -> void:
	var r := _game("wifi")
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	r.apply(HOST, {"type": "next"})
	r.apply({"id": "p0", "host": false}, {"type": "choose_explainer", "id": "p0"})
	r.apply({"id": "p0", "host": false}, {"type": "start_turn"})
	r.set_connected("p0", false)
	eq(r.paused, true, "pausa quando o explicador cai")
	eq(r.pause_reason, "disconnect", "motivo desconexão")
	r.tick(10000)
	eq(r.time_ms, 60000, "tempo parado")
	check(not r.apply({"id": "p0", "host": false}, {"type": "resume"}).ok, "não retoma desconectado")
	r.set_connected("p0", true)
	check(r.apply({"id": "p0", "host": false}, {"type": "resume"}).ok, "retoma depois de voltar")
	r.set_connected("p0", false)
	check(r.apply(HOST, {"type": "end_turn"}).ok, "host pode encerrar a vez")
	eq(r.phase, ChapeuRules.PHASE_TURN_SUMMARY, "vez encerrada")


func test_rematch_keeps_players() -> void:
	var r := _game("local", 1)
	_start_with_words(r, [["A"], ["B"], ["C"], ["D"]])
	for i in 3:
		_play_round(r, 2, 2)
	eq(r.phase, ChapeuRules.PHASE_GAME_OVER, "acabou")
	check(r.apply(HOST, {"type": "rematch"}).ok, "jogar de novo")
	eq(r.phase, ChapeuRules.PHASE_WRITING, "volta pra escrita")
	eq(r.players.size(), 4, "mesmos jogadores")
	eq(r.totals().azul, 0, "placar zerado")


func test_text_norm() -> void:
	eq(TextNorm.normalize("  Pão  de   Açúcar "), "pao de acucar", "normaliza")
	eq(TextNorm.clean("  Pão  de   Açúcar "), "Pão de Açúcar", "limpa")
