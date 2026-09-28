extends PartyGameScreen
## Partida do Quem Foi? (docs/PLANO_QUEM_FOI.md §4). Serve o celular do jogador e o tabuleiro.
## Na corrida, a mão aparece embaralhada: tocar no bicho acusado manda o toque (com a hora, pra
## corrida justa); tocar em outro trava a mão por 1 s.

var _open_play := "" # abertura: o bicho que a pessoa escolheu jogar, antes de acusar
var _lock_until := 0 # ms locais até quando a mão está travada (tocou errado)
var _sent_race := -1 # corrida em que este aparelho já mandou o toque certo
var _hand_box: Control
var _flash := "" # nome de quem ganhou a última corrida (tabuleiro)


func _menu_path() -> String:
	return "res://games/quem_foi/screens/quem_foi_menu.gd"


func _game_title() -> String:
	return "Quem Foi?"


func _lobby_title() -> String:
	return "Sala do Quem Foi?"


func _icon() -> String:
	return "quem_foi"


func _ready() -> void:
	super()
	var mesa := QuemFoiArt.art("mesa") if _board else null
	if mesa:
		var bg := TextureRect.new()
		bg.texture = mesa
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate.a = 0.12
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)


func _me_playing() -> bool:
	return not _board and _me() != ""


func _pcolor(id: String) -> Color:
	return QuemFoiArt.color(int(_player(id).get("color", 0)))


# --- Sala ------------------------------------------------------------------

func _config_card() -> Control:
	var cfg: Dictionary = v.config
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		cv.add_child(UI.setting_block("Cocôs pra acabar", UI.stepper(int(cfg.max_poops), 2, 5, 1, func(x): session.send({"type": "set_config", "max_poops": x})), "3 é o oficial. Ganha quem tiver menos cocôs no fim."))
		var row := UI.hbox(12)
		var l := UI.label("Ajuda de memória", 20, Tokens.TINTA, Fonts.body_bold())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.toggle(bool(cfg.memory_help), func(on): session.send({"type": "set_config", "memory_help": on})))
		cv.add_child(row)
		cv.add_child(UI.label("Mostra quantos de cada bicho já saíram. Bom pra jogar com criança; sem ela, é preciso lembrar.", 15, Tokens.TINTA_SUAVE))
	else:
		cv.add_child(UI.label("Acaba com %d cocôs · ajuda de memória %s" % [int(cfg.max_poops), "ligada" if cfg.memory_help else "desligada"], 17, Tokens.TINTA, Fonts.body_bold()))
	cv.add_child(UI.label("De 3 a 6 pessoas, cada uma com os 6 bichos de uma cor.", 15, Tokens.TINTA_SUAVE))
	return c


# --- Partes da tela --------------------------------------------------------

## Placar: cada um com a cor, quantas cartas ainda tem e os cocôs.
func _score() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	for p in v.players:
		var col := QuemFoiArt.color(int(p.color))
		var c := UI.card(Tokens.tint(col, 0.25 if p.id != v.accuser else 0.5), 10)
		var row := UI.hbox(6)
		c.add_child(row)
		var av := Avatar.new(p.name, col, _fs(34, 48))
		av.connected = p.connected
		row.add_child(av)
		var tv := UI.vbox(0)
		var nl := UI.label(p.name, _fs(16, 22), Tokens.TINTA, Fonts.body_bold())
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tv.add_child(nl)
		var cards: int = int(p.cards)
		var cl := UI.label("%d bicho%s" % [cards, "" if cards == 1 else "s"] if cards > 0 else "a salvo", _fs(13, 18), Tokens.TINTA_SUAVE, Fonts.body_bold())
		cl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tv.add_child(cl)
		row.add_child(tv)
		if int(p.poops) > 0:
			row.add_child(QuemFoiArt.poops(int(p.poops), _fs(26, 38)))
		flow.add_child(c)
	_root.add_child(flow)


## A pilha: a carta do topo (ou o cocô no meio da sala, se ainda não saiu nada).
func _pile() -> void:
	var box := CenterContainer.new()
	var side := _fs(170, 280)
	if v.top.is_empty():
		var p := QuemFoiArt.picture("coco", side)
		box.add_child(p)
	else:
		box.add_child(QuemFoiArt.card(v.top.animal, _pcolor(v.top.owner), side))
	_root.add_child(box)


## A frase da vez.
func _phrase() -> void:
	if v.accused == "" or v.top.is_empty():
		return
	var who := _name(v.accuser)
	var c := UI.card(Tokens.MOSTARDA, 20)
	var cv := UI.vbox(4)
	c.add_child(cv)
	cv.add_child(UI.label("%s: \"Não foi %s…\"" % [who, QuemFoiArt.MINE[v.top.animal]], _fs(17, 24), Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.label("Acho que foi %s de alguém!" % QuemFoiArt.shout(v.accused), _fs(26, 42), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)


func _memory() -> void:
	if not v.config.memory_help or v.played.is_empty():
		return
	var parts: Array = []
	for a in v.animals:
		if v.played.has(a):
			parts.append("%s %d" % [QuemFoiArt.animal_name(a), int(v.played[a])])
	_root.add_child(UI.label("Já saíram: %s (de %d)" % [", ".join(parts), v.players.size()], _fs(15, 22), Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))


## A mão em grade de 3. on_tap(animal) ou Callable() pra só mostrar.
func _hand(animals: Array, on_tap: Callable, dim := false, color := Color.TRANSPARENT) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var side := _fs(170, 200) if animals.size() > 3 else _fs(180, 220)
	var col := color if color != Color.TRANSPARENT else _pcolor(_me())
	for a in animals:
		var cardp := QuemFoiArt.card(a, col, side)
		if dim:
			cardp.modulate = Color(1, 1, 1, 0.45)
		if on_tap.is_valid():
			var an: String = a
			cardp.tapped.connect(func(): on_tap.call(an))
		grid.add_child(cardp)
	var center := CenterContainer.new()
	center.add_child(grid)
	_root.add_child(center)
	_hand_box = grid


# --- Fases -----------------------------------------------------------------

func _build_phase() -> void:
	_hand_box = null
	match v.phase:
		"accuse":
			_build_accuse()
		"race":
			_build_race()
		"round_end":
			_build_round_end()
		"game_over":
			_build_game_over()


func _build_accuse() -> void:
	_header("Quem Foi?")
	_score()
	_pile()
	_memory()
	var mine: bool = _me_playing() and v.accuser == _me()
	if not mine:
		var sub := "Vai jogar um bicho e acusar outro." if v.top.is_empty() else "Ganhou a corrida! Agora acusa o próximo bicho."
		_root.add_child(_big("%s está acusando" % _name(v.accuser), Tokens.SUPERFICIE, sub))
		if _me_playing() and not v.hand.is_empty():
			_root.add_child(UI.caption("Seus bichos:"))
			_hand(v.hand, Callable(), true)
		return
	if v.top.is_empty() and _open_play == "":
		_root.add_child(_big("Você começa!", Tokens.MOSTARDA, "Escolha o bicho que você joga na mesa."))
		_hand(v.hand, func(a):
			_open_play = a
			_rebuild())
		return
	var played: String = _open_play if v.top.is_empty() else v.top.animal
	_root.add_child(_big("\"Não foi %s…\"" % QuemFoiArt.MINE[played], Tokens.MOSTARDA, "…acho que foi de alguém! Toque no bicho que você acusa."))
	var all_col := Tokens.TINTA_SUAVE
	_hand(v.animals, _accuse, false, all_col)
	if v.top.is_empty():
		_root.add_child(UI.small_button("Trocar o bicho que eu jogo", AppButton.Variant.SECONDARY, func():
			_open_play = ""
			_rebuild()))


func _accuse(animal: String) -> void:
	var a := {"type": "accuse", "animal": animal}
	if v.top.is_empty():
		a.play = _open_play
	_open_play = ""
	session.send(a)


func _build_race() -> void:
	_header("Quem Foi?")
	_score()
	_pile()
	_phrase()
	_memory()
	if _board:
		if _flash != "":
			_root.add_child(UI.label(_flash, 26, Tokens.SALVIA_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(UI.caption("Quem tem esse bicho corre pra jogar primeiro!"))
		return
	if v.accuser == _me():
		_root.add_child(UI.caption("Você acusou. Agora é com os outros!"))
		_hand(v.hand, Callable(), true)
		return
	if v.hand.is_empty():
		_root.add_child(_big("Seus bichos são inocentes!", Tokens.tint(Tokens.SALVIA, 0.4), "Agora é só assistir."))
		return
	if _sent_race == int(v.race_no):
		_root.add_child(UI.caption("Foi! Esperando o resultado..."))
	else:
		_root.add_child(UI.caption("Tem esse bicho? Ache e toque, rápido!"))
	_hand(v.hand, _race_tap, _sent_race == int(v.race_no))


func _race_tap(animal: String) -> void:
	var now := Time.get_ticks_msec()
	var t_us := Time.get_ticks_usec()
	if now < _lock_until or _sent_race == int(v.race_no):
		return
	if animal == v.accused:
		_sent_race = int(v.race_no)
		session.send({"type": "tap", "animal": animal, "local_us": t_us})
		Audio.sfx("tap")
		_rebuild()
		return
	# Errou: trava 1 s e treme.
	_lock_until = now + QuemFoiRules.MISS_LOCK_MS
	session.send({"type": "miss"})
	Audio.sfx("hg_wrong")
	Haptics.hg_wrong()
	if is_instance_valid(_hand_box):
		var box := _hand_box
		box.modulate = Color(1, 1, 1, 0.4)
		var x0 := box.position.x
		var tw := box.create_tween()
		for k in 4:
			tw.tween_property(box, "position:x", x0 + (10 if k % 2 == 0 else -10), 0.05)
		tw.tween_property(box, "position:x", x0, 0.05)
		get_tree().create_timer(QuemFoiRules.MISS_LOCK_MS / 1000.0).timeout.connect(func():
			if is_instance_valid(box):
				box.modulate = Color.WHITE)


func _build_round_end() -> void:
	_header("Quem foi?")
	var last: Dictionary = v.last
	var g: String = last.get("guilty", "")
	var gname := _name(g)
	var animal: String = last.get("animal", "")
	var c := UI.card(Tokens.tint(QuemFoiArt.COCO, 0.25), 24)
	var cv := UI.vbox(10)
	c.add_child(cv)
	if last.get("reason", "") == "ninguem_tem":
		cv.add_child(UI.title("Ninguém tem mais %s!" % QuemFoiArt.animal_name(last.get("accused", "")).to_lower(), _fs(28, 46)))
		cv.add_child(UI.label("Então foi %s de %s!" % [QuemFoiArt.WITH_ARTICLE[animal], gname], _fs(22, 34), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		cv.add_child(UI.title("Só %s ficou com bichos!" % gname, _fs(28, 46)))
		cv.add_child(UI.label("Não tem mais ninguém pra quem passar a culpa.", _fs(19, 28), Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Se tiver a versão "culpada" do bicho (opcional), usa ela.
	var pic := "%s_culpado" % animal if QuemFoiArt.art("%s_culpado" % animal) else animal
	row.add_child(QuemFoiArt.card(pic, _pcolor(g), _fs(150, 230), false))
	row.add_child(QuemFoiArt.picture("coco", _fs(110, 170)))
	cv.add_child(row)
	cv.add_child(UI.label("%s leva um cocô." % gname, _fs(20, 30), Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)
	_score()
	# A prova: o que cada um ainda tinha na mão.
	var hc := UI.card(Tokens.PAPEL, 18)
	var hv := UI.vbox(8)
	hc.add_child(hv)
	hv.add_child(UI.label("O que cada um tinha", 20, Tokens.TINTA, Fonts.title()))
	var hands: Dictionary = last.get("hands", {})
	for p in v.players:
		var h: Array = hands.get(p.id, [])
		var line := UI.hbox(6)
		var nl := UI.label(p.name, 17, QuemFoiArt.color(int(p.color)), Fonts.body_bold())
		nl.custom_minimum_size.x = 110
		line.add_child(nl)
		if h.is_empty():
			# Com quebra automática, dentro do hbox o rótulo encolhe até uma letra por linha.
			var safe := UI.label("nada, a salvo", 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
			safe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(safe)
		for a in h:
			line.add_child(QuemFoiArt.picture(a, _fs(40, 56)))
		hv.add_child(line)
	_root.add_child(hc)
	if _me_playing() or _board:
		var b := UI.button("Próxima rodada" if _max_poops() < int(v.max_poops) else "Ver o resultado", AppButton.Variant.SUCCESS, func(): session.send({"type": "continue"}), "play")
		b.height = 80
		_root.add_child(b)


func _max_poops() -> int:
	var m := 0
	for p in v.players:
		m = maxi(m, int(p.poops))
	return m


func _build_game_over() -> void:
	_root.add_child(UI.spacer(8))
	var names: Array = v.winners.map(func(id): return _name(id))
	var title := "%s venceu!" % names[0] if names.size() == 1 else "%s venceram!" % " e ".join(names)
	_root.add_child(_big(title, Tokens.tint(Tokens.SALVIA, 0.45), "Menos cocôs, dono mais cuidadoso."))
	var sorted: Array = v.players.duplicate()
	sorted.sort_custom(func(a, b): return int(a.poops) < int(b.poops))
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	for p in sorted:
		var row := UI.player_row(p.name, QuemFoiArt.color(int(p.color)), true, "")
		row.add_child(QuemFoiArt.poops(int(p.poops), 32))
		if int(p.poops) == 0:
			var nl := UI.label("nenhum!", 16, Tokens.SALVIA_ESCURO, Fonts.body_bold())
			nl.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(nl)
		cv.add_child(row)
	_root.add_child(c)
	_end_buttons("Mesma mesa, cocôs zerados.")


# --- Eventos e histórico ---------------------------------------------------

func _before_rebuild(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"round", "started":
				_open_play = ""
			"accused":
				_lock_until = 0
			"won_race":
				_flash = "%s jogou primeiro!" % _name(e.get("id", ""))


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"accused":
				# O mesmo som e a mesma vibração em todo celular.
				Audio.sfx("qf_pum")
				Haptics.tap()
			"won_race":
				if e.get("id", "") == _me():
					Audio.sfx("qf_plim")
					Haptics.hit()
				else:
					Audio.sfx("pop")
			"guilty":
				Audio.sfx("qf_descarga")
				Haptics.time_up()
			"game_over":
				Audio.sfx("win")
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 50, [Tokens.MOSTARDA, Tokens.SALVIA, QuemFoiArt.COCO], 2.4)


func _save_history() -> void:
	var names: Array = v.winners.map(func(id): return _name(id))
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "quem_foi",
		"game_name": "Quem Foi?",
		"mode": "wifi",
		"summary": "%s com menos cocôs" % " e ".join(names),
		"players": v.players.map(func(p): return {"name": p.name, "poops": int(p.poops)}),
	})
