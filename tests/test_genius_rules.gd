extends TestCase
## Testes das regras do Genius (docs/PLANO_GENIUS.md §2, §4 e §5).

const HOST := {"id": "", "host": true, "now": 0}


func _as(id: String, now := 0) -> Dictionary:
	return {"id": id, "host": false, "now": now}


func _game(n: int, local := false) -> GeniusRules:
	var r := GeniusRules.new(7)
	r.local_mode = local
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "" if local else "p%d" % i})
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	return r


## Repete a sequência inteira certo (ou erra na última cor).
func _play(r: GeniusRules, id: String, right := true, now := 0) -> void:
	var s: Array = r.seq.duplicate()
	for i in s.size():
		var c: int = s[i]
		if not right and i == s.size() - 1:
			c = (c + 1) % GeniusRules.COLORS
		r.apply(_as(id, now), {"type": "press", "color": c, "i": i})


func test_speed() -> void:
	eq(GeniusRules.light_ms(1), 420, "1 a 5")
	eq(GeniusRules.light_ms(5), 420, "5")
	eq(GeniusRules.light_ms(6), 320, "6 a 13")
	eq(GeniusRules.light_ms(13), 320, "13")
	eq(GeniusRules.light_ms(14), 220, "14+")
	eq(GeniusRules.light_ms(80), 220, "não acelera mais")
	eq(GeniusRules.playback_ms(3), 3 * 470, "tocar 3 cores")


func test_setup() -> void:
	var r := GeniusRules.new(1)
	r.apply(HOST, {"type": "add_player", "name": "A", "id": "a"})
	check(r.can_start() != "", "1 não joga")
	for i in 12:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "x%d" % i})
	eq(r.players.size(), 12, "máximo 12")
	check(not r.apply(_as("a"), {"type": "start"}).ok, "só o host começa")


func test_pass_grows_each_turn() -> void:
	var r := _game(3, true)
	eq(r.phase, "turn", "vez de alguém")
	eq(r.seq.size(), 1, "começa com 1 cor")
	var first := r.turn
	_play(r, first)
	eq(r.seq.size(), 2, "acertou: +1 cor")
	check(r.turn != first, "passa pro próximo")
	var ids: Array = r.players.map(func(p): return p.id)
	eq(r.turn, ids[(ids.find(first) + 1) % 3], "na ordem da mesa")
	eq(r.player(first).best, 1, "recorde de quem acertou")


func test_pass_fail_keeps_sequence() -> void:
	var r := _game(3, true)
	var a := r.turn
	_play(r, a)
	var b := r.turn
	var before: Array = r.seq.duplicate()
	_play(r, b, false)
	eq(r.player(b).out_round >= 0, true, "quem errou sai")
	eq(r.seq, before, "o próximo recebe a mesma sequência")
	var c := r.turn
	check(c != b and c != a, "vez do terceiro")
	_play(r, c)
	eq(r.turn, a, "pula quem saiu")
	_play(r, a, false)
	eq(r.phase, "game_over", "sobrou um")
	eq(r.winners, [c], "vence quem sobrou")
	var rk: Array = r.ranking()
	eq(rk.map(func(x): return x.id), [c, a, b], "classificação: quem saiu por último vem antes")


func test_pass_wrong_press_ignored_out_of_turn() -> void:
	var r := _game(2, true)
	check(r.apply(HOST, {"type": "press", "color": 9}).ok == false, "cor inválida")
	# Toque repetido (mesmo i) não conta duas vezes.
	var s: Array = r.seq
	r.apply(HOST, {"type": "press", "color": s[0], "i": 5})
	eq(r.seq.size(), 1, "i errado é ignorado")


func test_race_round() -> void:
	var r := _game(3)
	eq(r.phase, "round", "rodada")
	eq(r.round_at, GeniusRules.FIRST_COUNTDOWN_MS, "contagem antes de tocar")
	_play(r, "p0")
	eq(r.phase, "round", "espera todo mundo")
	eq(r.view_for({"id": "p1"}).pending, 2, "faltam 2")
	_play(r, "p1", false)
	_play(r, "p2")
	eq(r.phase, "round_end", "fim da rodada")
	eq(r.last.passed, ["p0", "p2"], "passaram")
	eq(r.last.failed, ["p1"], "errou")
	check(r.player("p1").out_round == 1, "p1 saiu na rodada 1")
	r.tick(r.round_end_until - 1)
	eq(r.phase, "round_end", "ainda mostrando")
	r.tick(r.round_end_until)
	eq(r.phase, "round", "próxima rodada")
	eq(r.seq.size(), 2, "uma cor a mais")
	check(r.apply(_as("p1"), {"type": "press", "color": r.seq[0], "i": 0}).ok == false, "quem saiu não joga")


func test_race_all_fail_repeats() -> void:
	var r := _game(2)
	var before: Array = r.seq.duplicate()
	_play(r, "p0", false)
	_play(r, "p1", false)
	eq(r.phase, "round_end", "fim")
	eq(r.last.repeat, true, "todos erraram: repete")
	eq(r.alive(), ["p0", "p1"], "ninguém sai")
	r.tick(r.round_end_until)
	eq(r.seq, before, "mesma sequência")
	eq(r.round_no, 1, "mesma rodada")


func test_race_winner_and_ties() -> void:
	var r := _game(4)
	_play(r, "p0")
	_play(r, "p1")
	_play(r, "p2", false)
	_play(r, "p3", false)
	r.tick(r.round_end_until)
	_play(r, "p0")
	_play(r, "p1", false)
	eq(r.phase, "game_over", "só um passou")
	eq(r.winners, ["p0"], "vencedor")
	var rk: Array = r.ranking()
	eq(rk[0], {"id": "p0", "pos": 1, "best": 2}, "1º")
	eq(rk[1].id, "p1", "2º")
	eq(rk[2].pos, 3, "p2 e p3 empatam em 3º")
	eq(rk[3].pos, 3, "empate")


func test_race_drop_and_disconnect() -> void:
	var r := _game(3)
	_play(r, "p0")
	_play(r, "p1")
	check(not r.apply(_as("p0"), {"type": "drop_player", "id": "p2"}).ok, "só o host desiste de alguém")
	check(r.apply(HOST, {"type": "drop_player", "id": "p2"}).ok, "host desiste de p2")
	eq(r.phase, "round_end", "rodada fecha")
	eq(r.last.forfeit, ["p2"], "p2 saiu")
	r.tick(r.round_end_until)
	# p1 cai no meio da rodada; p0 termina. Espera o tempo de volta e depois desiste dele.
	r.set_connected("p1", false)
	_play(r, "p0", true, 1000)
	r.tick(1000)
	eq(r.phase, "round", "espera quem caiu")
	r.tick(1000 + GeniusRules.DROP_GRACE_MS - 1)
	eq(r.phase, "round", "ainda espera")
	r.tick(1000 + GeniusRules.DROP_GRACE_MS)
	eq(r.phase, "game_over", "desistiu de quem caiu")
	eq(r.winners, ["p0"], "p0 vence")


func test_race_reconnect_continues() -> void:
	var r := _game(2)
	r.set_connected("p1", false)
	_play(r, "p0")
	r.tick(5000)
	r.set_connected("p1", true)
	r.tick(5000 + GeniusRules.DROP_GRACE_MS)
	eq(r.phase, "round", "voltou: não desiste")
	_play(r, "p1")
	eq(r.phase, "round_end", "voltou e terminou a rodada")
	eq(r.last.passed, ["p0", "p1"], "os dois passaram")
