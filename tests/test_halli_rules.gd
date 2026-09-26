extends TestCase
## Testes das regras do Halli Galli (docs/PLANO_HALLI_GALLI.md §3 e §5).

const HOST := {"id": "", "host": true}
const B := 0 # banana
const M := 1 # morango
const L := 2 # limão
const A := 3 # ameixa


static func c(fruit: int, n: int) -> int:
	return HalliRules.make_card(fruit, n)


func _game(n := 3, mode := "table") -> HalliRules:
	var r := HalliRules.new(mode, 7)
	for i in n:
		r.apply(HOST, {"type": "add_player", "name": "J%d" % i, "id": "p%d" % i})
	return r


## Partida começada com montes escolhidos a dedo e a vez com p0.
func _rigged(downs: Array) -> HalliRules:
	var r := _game(downs.size())
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	for i in downs.size():
		r.players[i].down = downs[i].duplicate()
		r.players[i].up = []
	r.turn = "p0"
	r.last_flip_t = -100000
	r.lock_until = 0
	r.resolved_until = -100000
	return r


func _flip(r: HalliRules, id: String, t: int) -> Dictionary:
	return r.apply(HOST, {"type": "flip", "player": id, "t": t})


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func test_deck_composition() -> void:
	var d := HalliRules.build_deck(1)
	eq(d.size(), 56, "56 cartas")
	for f in 4:
		eq(d.filter(func(x): return HalliRules.card_fruit(x) == f).size(), 14, "14 por fruta %d" % f)
	eq(d.filter(func(x): return x == c(B, 5)).size(), 1, "uma carta de 5 bananas")
	eq(d.filter(func(x): return x == c(M, 1)).size(), 5, "cinco cartas de 1 morango")
	eq(HalliRules.build_deck(3).size(), 168, "3 baralhos")


func test_deal_and_auto_decks() -> void:
	var r := _game(3)
	eq(int(r.config.decks), 1, "3 jogadores: 1 baralho")
	eq(r.apply(HOST, {"type": "start"}).ok, true, "start")
	eq(r.players.map(func(p): return p.down.size()), [19, 19, 18], "distribui igual, primeiros com uma a mais")
	var big := _game(7, "wifi")
	eq(int(big.config.decks), 2, "7 jogadores: 2 baralhos")
	big.apply(HOST, {"type": "set_config", "decks": 1})
	big.apply(HOST, {"type": "add_player", "name": "Mais", "id": "x"})
	eq(int(big.config.decks), 1, "escolha do host não muda sozinha")


func test_min_and_max_players() -> void:
	var r := _game(1)
	check(r.can_start() != "", "1 jogador não começa")
	check(not r.apply(HOST, {"type": "start"}).ok, "start recusado")
	var t := _game(6)
	check(not t.apply(HOST, {"type": "add_player", "name": "Sete"}).ok, "mesa: 7º recusado")


func test_turn_and_cooldown() -> void:
	var r := _rigged([[c(B, 1), c(B, 1)], [c(M, 1), c(M, 1)], [c(L, 1), c(L, 1)]])
	check(not _flip(r, "p1", 0).ok, "fora da vez não vira")
	check(_flip(r, "p0", 0).ok, "p0 vira")
	eq(r.turn, "p1", "vez passa pro próximo")
	check(not _flip(r, "p1", 499).ok, "antes de 0,5 s não vira")
	check(_flip(r, "p1", 500).ok, "com 0,5 s vira")
	check(not _flip(r, "p2", 999).ok, "intervalo vale pra qualquer virada")
	check(_flip(r, "p2", 2000).ok, "p2 vira")
	eq(r.turn, "p0", "volta pro primeiro")


func test_wifi_actor_flips_own_card_only() -> void:
	var r := HalliRules.new("wifi", 3)
	r.apply(HOST, {"type": "add_player", "name": "Ana", "id": "a"})
	r.apply(HOST, {"type": "add_player", "name": "Bia", "id": "b"})
	r.apply(HOST, {"type": "start"})
	r.turn = "a"
	r.lock_until = 0
	check(not r.apply({"id": "b", "host": false}, {"type": "flip", "player": "a", "t": 5000}).ok, "cliente não vira pelos outros")
	check(r.apply({"id": "a", "host": false}, {"type": "flip", "t": 5000}).ok, "vira a própria")


func test_correct_bell_collects_table() -> void:
	var r := _rigged([[c(B, 2), c(A, 1)], [c(B, 3), c(A, 1)], [c(M, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000)
	_flip(r, "p2", 2000)
	var res := r.ring([{"player": "p2", "t": 2300}], 2400)
	var bell: Dictionary = res.events.filter(func(e): return e.type == "bell")[0]
	eq(bell.ok, true, "2 + 3 bananas = 5")
	eq(bell.fruit, B, "fruta banana")
	eq(bell.cards, 3, "leva as 3 cartas da mesa")
	eq(r.players[2].down.size(), 4, "p2 ficou com 1 + 3")
	eq(r.players.map(func(p): return p.up.size()), [0, 0, 0], "mesa limpa")
	eq(r.turn, "p2", "quem ganhou começa")
	check(not _flip(r, "p2", 3000).ok, "trava de 1 s depois do sino")
	check(_flip(r, "p2", 3400).ok, "depois da trava vira")


func test_bell_judged_at_touch_time() -> void:
	var r := _rigged([[c(B, 2), c(A, 1)], [c(B, 3), c(A, 1)], [c(M, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000) # agora tem 5 bananas
	# Tocou em 900, antes da carta que fez o 5 aparecer: errou, mesmo chegando depois.
	var res := r.ring([{"player": "p2", "t": 900}], 1200)
	var bell: Dictionary = res.events.filter(func(e): return e.type == "bell")[0]
	eq(bell.ok, false, "bateu cedo demais")
	eq(r.players[2].down.size(), 0, "pagou 1 pra cada (tinha 2)")
	eq(r.players[0].down.size(), 3, "p0: 1 no monte + a carta da mesa de volta + 1 de punição")
	eq(r.players[1].down.size(), 3, "p1: idem")


func test_bell_after_five_broken_is_wrong() -> void:
	var r := _rigged([[c(B, 5), c(M, 2)], [c(A, 1), c(A, 1)], [c(L, 1), c(L, 1)]])
	_flip(r, "p0", 0) # 5 bananas
	_flip(r, "p1", 1000)
	_flip(r, "p2", 2000)
	_flip(r, "p0", 3000) # troca as 5 bananas por 2 morangos
	var res := r.ring([{"player": "p1", "t": 3100}], 3200)
	eq(res.events.filter(func(e): return e.type == "bell")[0].ok, false, "o 5 já tinha sumido")
	var r2 := _rigged([[c(B, 5), c(M, 2)], [c(A, 1), c(A, 1)], [c(L, 1), c(L, 1)]])
	_flip(r2, "p0", 0)
	_flip(r2, "p1", 1000)
	_flip(r2, "p2", 2000)
	_flip(r2, "p0", 3000)
	var res2 := r2.ring([{"player": "p1", "t": 2900}], 3200)
	var bell: Dictionary = res2.events.filter(func(e): return e.type == "bell")[0]
	eq(bell.ok, true, "tocou quando ainda havia 5 (a virada de depois é desfeita)")
	check("undo_flip" in _types(res2.events), "evento de desfazer virada")
	eq(r2.players[0].down.size(), 1, "carta de 2 morangos voltou pro monte de p0")
	eq(r2.players[1].down.size(), 1 + 3, "p1 levou as 3 cartas que estavam na mesa no instante do toque")


func test_earliest_touch_wins_regardless_of_order() -> void:
	var r := _rigged([[c(B, 5), c(A, 1)], [c(M, 1), c(A, 1)], [c(L, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	# p1 chegou primeiro no host, mas p2 tocou 3 ms antes.
	var res := r.ring([{"player": "p1", "t": 403}, {"player": "p2", "t": 400}], 600)
	var bells: Array = res.events.filter(func(e): return e.type == "bell")
	eq(bells.size(), 1, "só um sino conta")
	eq(bells[0].player, "p2", "vence o horário exato")
	eq(bells[0].margin_ms, 3, "diferença de 3 ms")
	eq(r.players[1].wrong, 0, "quem chegou depois do certo não paga")


func test_first_bell_decides_the_moment() -> void:
	var r := _rigged([[c(B, 2), c(A, 1)], [c(B, 3), c(A, 1)], [c(M, 1), c(M, 1), c(M, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000)
	# p0 bateu antes do 5 aparecer: errou, a mesa volta pros donos e o sino de p2 não conta mais.
	var res := r.ring([{"player": "p2", "t": 1300}, {"player": "p0", "t": 950}], 1400)
	var bells: Array = res.events.filter(func(e): return e.type == "bell")
	eq(bells.size(), 1, "só o primeiro sino conta")
	eq([bells[0].player, bells[0].ok], ["p0", false], "p0 errou")
	eq(r.players[2].ok, 0, "p2 não levou nada")
	eq(r.players.map(func(p): return p.up.size()), [0, 0, 0], "mesa vazia")


func test_wrong_bell_returns_table() -> void:
	var r := _rigged([[c(B, 1), c(A, 1)], [c(M, 2)], [c(L, 3), c(L, 1), c(L, 1), c(L, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000)
	_flip(r, "p2", 2000)
	eq(r.players[1].down.size(), 0, "p1 sem monte, com carta na mesa")
	var res := r.ring([{"player": "p2", "t": 2500}], 2600)
	eq(r.players.map(func(p): return p.up.size()), [0, 0, 0], "mesa voltou toda")
	eq(r.players[0].down, [c(A, 1), c(B, 1), c(L, 1)], "a carta de p0 voltou pro fundo e depois veio a punição")
	eq(r.players[1].down, [c(M, 2), c(L, 1)], "p1 recuperou a sua e ganhou 1")
	eq(r.players[2].down.size(), 3 + 1 - 2, "p2: 3 no monte + a sua de volta − 2 pagas")
	check("bell" in _types(res.events), "evento do sino")


func test_wrong_bell_brings_out_player_back() -> void:
	var r := _rigged([[c(M, 2)], [c(A, 1), c(A, 1)], [c(L, 1), c(L, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000)
	_flip(r, "p2", 2000)
	check(r.players[0].out, "p0 saiu na vez dele, com a carta na mesa")
	var res := r.ring([{"player": "p1", "t": 2500}], 2600)
	check(not r.players[0].out, "a carta voltou e p0 voltou pro jogo")
	check("back_in" in _types(res.events), "evento de volta")
	eq(r.out_order, ["p1"], "p0 saiu da lista; p1 pagou a última carta e saiu")


func test_stale_bell_ignored() -> void:
	var r := _rigged([[c(B, 5), c(A, 1)], [c(M, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	r.ring([{"player": "p1", "t": 300}], 400)
	var res := r.ring([{"player": "p0", "t": 350}], 450)
	eq(res.events.size(), 0, "sino atrasado do mesmo momento não conta")
	eq(r.players[0].wrong, 0, "e não pune")


func test_penalty_with_few_cards() -> void:
	var r := _rigged([[c(M, 1)], [c(L, 1), c(L, 1)], [c(A, 1)], [c(A, 2)]])
	var res := r.ring([{"player": "p0", "t": 100}], 200)
	var bell: Dictionary = res.events.filter(func(e): return e.type == "bell")[0]
	eq(bell.cards, 1, "só tinha 1 pra dar")
	eq(bell.to, ["p1"], "dá seguindo a ordem a partir do próximo")
	check(r.players[0].out, "sem carta nenhuma (nem na mesa): sai")


func test_empty_pile_stays_until_turn_and_can_come_back() -> void:
	var r := _rigged([[c(B, 2)], [c(B, 3), c(M, 1)], [c(L, 1), c(L, 1)]])
	_flip(r, "p0", 0)
	check(not r.players[0].out, "sem monte, mas com carta na mesa: continua")
	_flip(r, "p1", 1000) # 5 bananas
	r.ring([{"player": "p0", "t": 1200}], 1300)
	eq(r.players[0].down.size(), 2, "p0 voltou pro jogo ganhando a mesa")
	eq(r.turn, "p0", "e começa")
	var r2 := _rigged([[c(M, 2)], [c(A, 1), c(A, 1)], [c(L, 1), c(L, 1)]])
	_flip(r2, "p0", 0)
	_flip(r2, "p1", 1000)
	var res := _flip(r2, "p2", 2000)
	check(r2.players[0].out, "chegou a vez sem monte: saiu")
	check("out" in _types(res.events), "evento de saída")
	eq(r2.turn, "p1", "vez pula pro próximo")
	eq(r2.players[0].up.size(), 1, "a carta dele continua na mesa")
	var res2 := r2.ring([{"player": "p0", "t": 2100}], 2200)
	eq(res2.events.size(), 0, "quem saiu não bate")


func test_game_over() -> void:
	var r := _rigged([[c(M, 2)], [c(A, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	var res := _flip(r, "p1", 1000)
	check("game_over" in _types(res.events), "chegou a vez de p0 sem monte: acabou")
	eq(r.phase, HalliRules.PHASE_GAME_OVER, "fase final")
	eq(r.winner, "p1", "vencedor")
	eq(r.out_order, ["p0"], "ordem de saída")
	eq(r.apply(HOST, {"type": "rematch"}).ok, true, "jogar de novo")
	eq(r.phase, HalliRules.PHASE_PLAYING, "nova partida")
	eq(r.players[0].down.size() + r.players[1].down.size(), 56, "baralho novo distribuído")


func test_game_over_by_bell() -> void:
	var r := _rigged([[c(B, 1)], [c(B, 4)], [c(M, 1), c(M, 1)]])
	_flip(r, "p0", 0)
	_flip(r, "p1", 1000)
	eq(r.turn, "p2", "p0 e p1 sem monte, mas com carta na mesa")
	# p2 leva a mesa e os outros dois ficam sem nada.
	var res := r.ring([{"player": "p2", "t": 1300}], 1400)
	check("game_over" in _types(res.events), "acabou no sino")
	eq(r.winner, "p2", "p2 venceu")
	eq(r.out_order, ["p0", "p1"], "os dois saíram")


func test_wrong_bell_can_eliminate() -> void:
	var r := _rigged([[c(B, 1)], [c(M, 1)], [c(A, 1), c(A, 1)]])
	_flip(r, "p0", 0)
	r.ring([{"player": "p1", "t": 100}], 150)
	check(r.players[1].out, "p1 errou com a última carta e saiu")
	eq(r.players[2].down.size(), 3, "a carta foi pra p2")
	eq(r.turn, "p2", "vez pula quem saiu")


func test_multi_deck_sum_across_many_players() -> void:
	var r := _rigged([[c(L, 1), c(A, 1)], [c(L, 1), c(A, 1)], [c(L, 1), c(A, 1)], [c(L, 2), c(A, 1)]])
	for i in 3:
		_flip(r, "p%d" % i, i * 1000)
	eq(HalliRules.five_fruit(r.table_at(2500)), -1, "3 limões ainda não")
	_flip(r, "p3", 3000)
	eq(HalliRules.five_fruit(r.table_at(3000)), L, "1+1+1+2 = 5 limões")
	eq(HalliRules.fruit_sums(r.table_at(3000)), [0, 0, 5, 0], "somas")


func test_pause_on_disconnect() -> void:
	var r := _rigged([[c(B, 1), c(B, 1)], [c(M, 1), c(M, 1)]])
	var ev := r.set_connected("p1", false, 0)
	check(r.paused, "pausou")
	check("paused" in _types(ev), "evento de pausa")
	check(not _flip(r, "p0", 100).ok, "pausado não vira")
	eq(r.ring([{"player": "p0", "t": 100}], 100).events.size(), 0, "pausado não bate")
	ev = r.set_connected("p1", true, 5000)
	check(not r.paused, "voltou")
	check(not _flip(r, "p0", 5500).ok, "trava logo depois de voltar")
	check(_flip(r, "p0", 6000).ok, "depois vira")


func test_remove_player_mid_game() -> void:
	var r := _rigged([[c(B, 1), c(B, 1), c(B, 1)], [c(M, 1)], [c(L, 1)]])
	_flip(r, "p0", 0)
	r.set_connected("p0", false, 100)
	var res := r.apply(HOST, {"type": "remove_player", "id": "p0"})
	check(res.ok, "removeu")
	eq(r.players.size(), 2, "sobram 2")
	eq(r.players[0].down.size() + r.players[1].down.size(), 2 + 3, "cartas dele foram pros outros")
	check(not r.paused, "sem ninguém fora da rede, despausa")


func test_view_filtering() -> void:
	var r := HalliRules.new("wifi", 5)
	r.apply(HOST, {"type": "add_player", "name": "Ana", "id": "a"})
	r.apply(HOST, {"type": "add_player", "name": "Bia", "id": "b"})
	r.apply(HOST, {"type": "start"})
	r.turn = "a"
	r.lock_until = 0
	var next_a: int = r.players[0].down[0]
	var va := r.view_for({"id": "a", "role": "player"})
	eq(va.next, next_a, "sabe a próxima carta do próprio monte")
	check(not va.players[1].has("top"), "não recebe a carta dos outros")
	r.apply({"id": "a", "host": false}, {"type": "flip", "t": 100})
	eq(r.view_for({"id": "a", "role": "player"}).top, next_a, "vê a própria carta")
	eq(r.view_for({"id": "b", "role": "player"}).top, -1, "b não vê a carta de a")
	eq(r.view_for({"role": "table"}).players[0].top, next_a, "no modo mesa vê tudo")


func test_move_player_order() -> void:
	var r := _game(3)
	r.apply(HOST, {"type": "move_player", "id": "p2", "dir": -1})
	eq(r.players.map(func(p): return p.id), ["p0", "p2", "p1"], "subiu uma posição")
	r.apply(HOST, {"type": "move_player", "id": "p0", "dir": -1})
	eq(r.players[0].id, "p0", "primeiro não sobe mais")


func test_late_wrong_bell_during_lock_is_free() -> void:
	var r := _rigged([[c(B, 5), c(A, 1)], [c(M, 1), c(A, 1)], [c(L, 1), c(L, 1)]])
	_flip(r, "p0", 0)
	r.ring([{"player": "p1", "t": 300}], 400)
	# p2 bateu 250 ms depois de a mesa já ter sido levada: não paga.
	var res := r.ring([{"player": "p2", "t": 650}], 700)
	eq(res.events.size(), 0, "sino atrasado na trava não conta")
	eq(r.players[2].wrong, 0, "e não pune")
	# Passada a trava, sino errado pune normalmente.
	res = r.ring([{"player": "p2", "t": 1500}], 1500)
	eq(r.players[2].wrong, 1, "fora da trava, pune")
