extends PartyGameScreen
## Partida do Coup (docs/PLANO_COUP.md §4). Serve o celular do jogador e o tabuleiro. Desafiar e
## bloquear vão com a hora do toque (janela justa do host); a barrinha mostra quanto falta dos 5 s.

var _hide_cards := false
var _exchange_keep: Array = [] # Embaixador: índices escolhidos pra ficar
var _bar: ProgressBar
var _bar_left := 0.0 # ms que faltavam quando a tela montou
var _bar_total := float(CoupRules.WINDOW_MS)
var _reacted := false # este aparelho já reagiu nesta janela


func _menu_path() -> String:
	return "res://games/coup/screens/coup_menu.gd"


func _game_title() -> String:
	return "Coup"


func _lobby_title() -> String:
	return "Sala do Coup"


func _icon() -> String:
	return "coup"


func _ready() -> void:
	super()
	var mesa := CoupArt.art("mesa") if _board else null
	if mesa:
		var bg := TextureRect.new()
		bg.texture = mesa
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate.a = 0.1
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)


func _process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_bar) and _bar_left > 0:
		_bar_left = maxf(0.0, _bar_left - delta * 1000.0)
		_bar.value = _bar_left / _bar_total * 100.0


func _playing() -> bool:
	return not _board and _me() != ""


func _pl(id: String) -> Dictionary:
	return _player(id)


func _my_cards() -> Array:
	return _pl(_me()).get("cards", [])


func _my_hidden() -> Array:
	return _my_cards().filter(func(c): return not c.up)


func _has(role: String) -> bool:
	return _my_hidden().any(func(c): return c.role == role)


func _pcol(id: String) -> Color:
	return CoupArt.player_color(int(_pl(id).get("color", 0)))


func _variant(id: String) -> int:
	return maxi(0, v.players.map(func(p): return p.id).find(id))


# --- Sala ------------------------------------------------------------------

func _config_card() -> Control:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var fifth: String = v.config.fifth
	if session.is_host:
		cv.add_child(UI.setting_block("Quinto personagem", UI.segmented([["embaixador", "Embaixador"], ["inquisidor", "Inquisidor"]], fifth, func(k): session.send({"type": "set_config", "fifth": k})),
			"O Inquisidor (variante oficial) troca 1 carta e pode examinar a carta de alguém."))
	else:
		cv.add_child(UI.label("Quinto personagem: %s" % CoupArt.role_name(fifth), 18, Tokens.TINTA, Fonts.body_bold()))
	var n: int = v.players.size()
	cv.add_child(UI.label("De 2 a 6. Com 2, cada um escolhe a primeira carta e quem começa tem 1 moeda." if n != 2 else "Com 2: cada um escolhe a primeira carta entre as 5, e quem começa tem 1 moeda.", 15, Tokens.TINTA_SUAVE))
	return c


# --- Partes da tela --------------------------------------------------------

## Minhas cartas, grandes, com "Esconder".
func _my_block() -> void:
	if not _playing():
		return
	var c := UI.card(Tokens.SUPERFICIE, 16)
	var cv := UI.vbox(10)
	c.add_child(cv)
	var head := UI.hbox(10)
	var t := UI.label("Suas cartas", 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(CoupArt.coin(28))
	var cl := UI.label("%d" % int(_pl(_me()).get("coins", 0)), 24, Tokens.TINTA, Fonts.title_bold())
	cl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(cl)
	head.add_child(UI.small_button("Mostrar" if _hide_cards else "Esconder", AppButton.Variant.SECONDARY, func():
		_hide_cards = not _hide_cards
		_rebuild()))
	cv.add_child(head)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for card in _my_cards():
		var shown: bool = card.up or not _hide_cards
		row.add_child(CoupArt.card(card.role if shown else "", 130, card.up, _variant(_me())))
	cv.add_child(row)
	if not _pl(_me()).get("alive", true):
		cv.add_child(UI.label("Você está fora: agora só assiste.", 16, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(c)


## A mesa: cada um com as moedas e as cartas (viradas só as perdidas).
func _table() -> void:
	var c := UI.card(Tokens.PAPEL, 14)
	var cv := UI.vbox(8)
	c.add_child(cv)
	for p in v.players:
		if p.id == _me() and not _board:
			continue
		var row := UI.hbox(8)
		var av := Avatar.new(p.name, CoupArt.player_color(int(p.color)), _fs(40, 56))
		av.connected = p.connected
		row.add_child(av)
		var nv := UI.vbox(0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UI.label(p.name + ("  · vez" if p.id == v.turn and v.phase != "game_over" else ""), _fs(18, 26), Tokens.TINTA if p.alive else Tokens.TEXTO_DESABILITADO, Fonts.body_bold())
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.clip_text = true
		nv.add_child(nl)
		if not p.alive:
			nv.add_child(UI.label("fora", _fs(14, 20), Tokens.TINTA_SUAVE, Fonts.body_bold()))
		row.add_child(nv)
		row.add_child(CoupArt.coin(_fs(24, 34)))
		var cl := UI.label("%d" % int(p.coins), _fs(20, 30), Tokens.TINTA, Fonts.title_bold())
		cl.autowrap_mode = TextServer.AUTOWRAP_OFF
		cl.custom_minimum_size.x = _fs(28, 40)
		row.add_child(cl)
		for card in p.cards:
			row.add_child(CoupArt.card(card.role if card.up else "", _fs(42, 64), card.up, _variant(p.id)))
		if p.id == v.turn and v.phase != "game_over":
			var hl := UI.card(Tokens.tint(Tokens.MOSTARDA, 0.5), 8)
			hl.add_child(row)
			cv.add_child(hl)
		else:
			cv.add_child(row)
	_root.add_child(c)


func _claim_text(p: Dictionary) -> String:
	var who := _name(p.actor)
	var act: String = CoupArt.ACTION_NAMES.get(p.action, p.action)
	var tgt := " em %s" % _name(p.target) if p.get("target", "") != "" else ""
	if p.get("claim", "") != "":
		return "%s diz ter %s: %s%s" % [who, CoupArt.WITH_ARTICLE[p.claim], act, tgt]
	return "%s pede %s%s" % [who, act, tgt]


func _bar_row(left_ms: int) -> void:
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 14
	_bar.max_value = 100
	_bar_left = float(left_ms)
	_bar_total = float(v.pending.get("window_total_ms", CoupRules.WINDOW_MS))
	_bar.value = _bar_left / _bar_total * 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Tokens.MOSTARDA
	fill.set_corner_radius_all(7)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Tokens.LINHA
	bg.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	_root.add_child(_bar)


func _log_block() -> void:
	var lines: Array = []
	for e in v.log:
		lines.append(_log_line(e))
	if lines.is_empty():
		return
	var c := UI.card(Tokens.PAPEL, 14)
	var cv := UI.vbox(4)
	c.add_child(cv)
	cv.add_child(UI.label("O que aconteceu", 17, Tokens.TINTA, Fonts.title()))
	var start := maxi(0, lines.size() - 6)
	for i in range(lines.size() - 1, start - 1, -1):
		cv.add_child(UI.label(lines[i], 15, Tokens.TINTA if i == lines.size() - 1 else Tokens.TINTA_SUAVE, Fonts.body_bold()))
	_root.add_child(c)


func _log_line(e: Dictionary) -> String:
	var who := _name(e.get("id", ""))
	match e.get("k", ""):
		"declared":
			var a: String = CoupArt.ACTION_NAMES.get(e.action, e.action)
			var tgt := " em %s" % _name(e.target) if e.get("target", "") != "" else ""
			return "%s: %s%s%s" % [who, a, tgt, " (diz ter %s)" % CoupArt.WITH_ARTICLE[e.claim] if e.get("claim", "") != "" else ""]
		"challenge":
			return "%s desafiou %s: %s" % [who, _name(e.target), "tinha %s!" % CoupArt.WITH_ARTICLE[e.role] if e.had else "era blefe!"]
		"blocked":
			return "%s bloqueou com %s" % [who, CoupArt.WITH_ARTICLE[e.role]]
		"lost":
			return "%s perdeu %s" % [who, CoupArt.WITH_ARTICLE[e.role]]
		"exchanged":
			return "%s trocou cartas" % who
		"examined":
			return "%s examinou %s%s" % [who, _name(e.target), " e mandou trocar" if e.force else ""]
		"done":
			return "%s: %s aconteceu" % [who, CoupArt.ACTION_NAMES.get(e.action, e.action)]
	return ""


# --- Fases -----------------------------------------------------------------

func _build_phase() -> void:
	_bar = null
	match v.phase:
		"pick_first":
			_build_pick_first()
		"game_over":
			_build_game_over()
		_:
			_header("Coup")
			_center()
			_my_block()
			_table()
			_log_block()


## O meio da tela, conforme a fase.
func _center() -> void:
	match v.phase:
		"turn":
			if _playing() and v.turn == _me():
				_build_actions()
			else:
				_root.add_child(_big("Vez de %s" % _name(v.turn), Tokens.SUPERFICIE, "Escolhendo a ação..."))
		"window":
			_build_window()
		"block":
			_build_block()
		"lose":
			if _playing() and v.loser == _me():
				_root.add_child(_big("Você perde uma carta", Tokens.tint(Tokens.VERMELHO, 0.35), "Escolha qual vai virar pra cima."))
				var row := UI.hbox(14)
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				var cards: Array = _my_cards()
				for i in cards.size():
					if cards[i].up:
						continue
					var idx := i
					var cp := CoupArt.card(cards[i].role, 140, false, _variant(_me()))
					cp.tapped.connect(func():
						App.confirm("Perder %s?" % CoupArt.WITH_ARTICLE[cards[idx].role], "A carta vira pra cima e fica à mostra.", "Perder", func(): session.send({"type": "lose", "index": idx})))
					row.add_child(cp)
				_root.add_child(row)
			else:
				_root.add_child(_big("%s perde uma carta" % _name(v.loser), Tokens.SUPERFICIE, "Escolhendo qual vira..."))
		"exchange":
			_build_exchange()
		"examine_show":
			if _playing() and v.pending.target == _me():
				_root.add_child(_big("Mostre uma carta pra %s" % _name(v.pending.actor), Tokens.MOSTARDA, "Só %s vai ver. Toque na carta." % _name(v.pending.actor)))
				var row := UI.hbox(14)
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				var cards: Array = _my_cards()
				for i in cards.size():
					if cards[i].up:
						continue
					var idx := i
					var cp := CoupArt.card(cards[i].role, 140, false, _variant(_me()))
					cp.tapped.connect(func(): session.send({"type": "show", "index": idx}))
					row.add_child(cp)
				_root.add_child(row)
			else:
				_root.add_child(_big("%s examina %s" % [_name(v.pending.actor), _name(v.pending.target)], Tokens.SUPERFICIE, "%s escolhe a carta que mostra..." % _name(v.pending.target)))
		"examine_decide":
			if _playing() and v.pending.actor == _me() and v.examined != "":
				_root.add_child(_big("A carta de %s" % _name(v.pending.target), Tokens.MOSTARDA, "Só você vê. Devolve, ou obriga a trocar por outra do baralho?"))
				var cc := CenterContainer.new()
				cc.add_child(CoupArt.card(v.examined, 150))
				_root.add_child(cc)
				var row2 := UI.hbox(12)
				var keep := UI.button("Devolver", AppButton.Variant.SECONDARY, func(): session.send({"type": "examine", "force": false}))
				var force := UI.button("Obrigar a trocar", AppButton.Variant.PRIMARY, func(): session.send({"type": "examine", "force": true}))
				row2.add_child(keep)
				row2.add_child(force)
				_root.add_child(row2)
			else:
				_root.add_child(_big("%s examina %s" % [_name(v.pending.actor), _name(v.pending.target)], Tokens.SUPERFICIE, "Decidindo..."))


func _build_actions() -> void:
	var coins_now: int = int(_pl(_me()).coins)
	var must: bool = coins_now >= CoupRules.MUST_COUP
	_root.add_child(_big("Sua vez", Tokens.MOSTARDA, "Com 10 moedas, o Golpe é obrigatório." if must else "Escolha uma ação. Pode dizer que tem qualquer personagem."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var claims := {"imposto": "duque", "assassinar": "assassino", "extorquir": "capitao", "trocar": v.config.fifth, "examinar": "inquisidor"}
	var costs := {"golpe": CoupRules.COUP_COST, "assassinar": CoupRules.ASSASSIN_COST}
	for a in v.actions:
		var claim: String = claims.get(a, "")
		var cost: int = costs.get(a, 0)
		var box := UI.card(Tokens.tint(CoupArt.role_color(claim), 0.3) if claim != "" else Tokens.SUPERFICIE, 12)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bv := UI.vbox(4)
		box.add_child(bv)
		var an: String = a
		var b := UI.button(CoupArt.ACTION_NAMES[a], AppButton.Variant.PRIMARY if claim == "" or _has(claim) else AppButton.Variant.SECONDARY, func(): _choose_action(an))
		b.height = 64
		b.font_size = 19
		b.disabled = (must and a != "golpe") or coins_now < cost
		bv.add_child(b)
		var info: String = CoupArt.ACTION_INFO[a]
		if a == "extorquir":
			info = info % CoupArt.role_name(v.config.fifth)
		if claim != "" and not _has(claim):
			info += " (blefe: você não tem)"
		bv.add_child(UI.label(info, 13, Tokens.TINTA_SUAVE, Fonts.body_bold()))
		grid.add_child(box)
	_root.add_child(grid)


func _choose_action(a: String) -> void:
	var needs_target := a in ["golpe", "assassinar", "extorquir", "examinar"]
	if not needs_target:
		session.send({"type": "act", "action": a})
		return
	var col := _open_panel()
	col.add_child(UI.title("%s em quem?" % CoupArt.ACTION_NAMES[a], 30))
	for p in v.players:
		if p.id == _me() or not p.alive:
			continue
		var pid: String = p.id
		col.add_child(UI.button("%s · %d moeda%s" % [p.name, int(p.coins), "" if int(p.coins) == 1 else "s"], AppButton.Variant.SECONDARY, func():
			_close_panel()
			session.send({"type": "act", "action": a, "target": pid})))
	col.add_child(UI.button("Cancelar", AppButton.Variant.SECONDARY, _close_panel))


func _react(type: String, role := "") -> void:
	var t_us := Time.get_ticks_usec()
	if _reacted:
		return
	_reacted = true
	var a := {"type": type, "local_us": t_us}
	if role != "":
		a.role = role
	session.send(a)
	Haptics.tap()
	_rebuild()


func _build_window() -> void:
	var p: Dictionary = v.pending
	var block_only: bool = p.get("stage", "") == "block_only"
	_root.add_child(_big(_claim_text(p), Tokens.tint(CoupArt.role_color(p.claim), 0.35) if p.claim != "" else Tokens.SUPERFICIE,
		"Ainda dá pra bloquear." if block_only else ("Alguém desafia ou bloqueia?" if p.claim != "" or not v.can_block.is_empty() else "")))
	_bar_row(int(p.get("window_left_ms", 0)))
	if not _playing():
		return
	if _reacted:
		_root.add_child(UI.caption("Foi! Esperando..."))
		return
	var row := UI.hbox(10)
	if v.can_challenge:
		var b := UI.button("Desafiar", AppButton.Variant.DANGER, func(): _react("challenge"), "close")
		b.height = 76
		row.add_child(b)
	for r in v.can_block:
		var role: String = r
		var bb := UI.button("Bloquear com %s" % CoupArt.WITH_ARTICLE[role], AppButton.Variant.PRIMARY, func(): _react("block", role))
		bb.height = 76
		row.add_child(bb)
	if row.get_child_count() > 0:
		_root.add_child(row)
	elif p.actor == _me():
		_root.add_child(UI.caption("Esperando os outros reagirem..."))


func _build_block() -> void:
	var p: Dictionary = v.pending
	_root.add_child(_big("%s bloqueia com %s" % [_name(p.blocker), CoupArt.WITH_ARTICLE[p.block_claim]], Tokens.tint(CoupArt.role_color(p.block_claim), 0.35),
		"%s de %s" % [CoupArt.ACTION_NAMES[p.action], _name(p.actor)]))
	if not p.accepted.is_empty():
		_root.add_child(UI.caption("Aceitaram: %s" % _names(p.accepted)))
	if not _playing() or p.blocker == _me() or not _pl(_me()).alive:
		_root.add_child(UI.caption("Esperando %s aceitar ou alguém desafiar o bloqueio..." % _name(p.actor)))
		return
	if _reacted:
		_root.add_child(UI.caption("Foi! Esperando..."))
		return
	var row := UI.hbox(10)
	if v.can_challenge:
		var b := UI.button("Desafiar o bloqueio", AppButton.Variant.DANGER, func(): _react("challenge"), "close")
		b.height = 76
		row.add_child(b)
	var mine: bool = p.actor == _me()
	if _me() not in p.accepted:
		var acc := UI.button("Aceitar", AppButton.Variant.SUCCESS if mine else AppButton.Variant.SECONDARY, func(): session.send({"type": "accept"}), "check")
		acc.height = 76
		row.add_child(acc)
	_root.add_child(row)
	_root.add_child(UI.caption("Só quando %s aceitar o jogo segue." % ("você" if mine else _name(p.actor))))


func _build_exchange() -> void:
	var p: Dictionary = v.pending
	if not (_playing() and p.actor == _me()):
		_root.add_child(_big("%s está trocando cartas" % _name(p.actor), Tokens.SUPERFICIE, "Com %s." % CoupArt.WITH_ARTICLE[v.config.fifth]))
		return
	var mine: Array = _my_hidden().map(func(c): return c.role)
	if v.config.fifth == "embaixador":
		var pool: Array = mine + v.exchange
		_root.add_child(_big("Escolha %d pra ficar" % mine.size(), Tokens.MOSTARDA, "As outras voltam pro baralho."))
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for i in pool.size():
			var idx := i
			var cp := CoupArt.card(pool[i], 124)
			if idx in _exchange_keep:
				cp.set_bg(Tokens.MOSTARDA)
			cp.tapped.connect(func():
				if idx in _exchange_keep:
					_exchange_keep.erase(idx)
				elif _exchange_keep.size() < mine.size():
					_exchange_keep.append(idx)
				_rebuild())
			flow.add_child(cp)
		_root.add_child(flow)
		var ok := UI.button("Ficar com essas", AppButton.Variant.SUCCESS, func():
			var keep := _exchange_keep.duplicate()
			_exchange_keep = []
			session.send({"type": "exchange", "keep": keep}), "check")
		ok.disabled = _exchange_keep.size() != mine.size()
		_root.add_child(ok)
		return
	# Inquisidor: 1 comprada; troca por uma das suas ou devolve.
	_root.add_child(_big("Você comprou", Tokens.MOSTARDA, "Troque por uma das suas, ou devolva."))
	var cc := CenterContainer.new()
	cc.add_child(CoupArt.card(v.exchange[0] if not v.exchange.is_empty() else "", 130))
	_root.add_child(cc)
	for i in mine.size():
		var idx := i
		_root.add_child(UI.button("Trocar pelo meu %s" % CoupArt.role_name(mine[i]) if mine[i] != "condessa" else "Trocar pela minha Condessa", AppButton.Variant.PRIMARY, func(): session.send({"type": "exchange", "swap": idx})))
	_root.add_child(UI.button("Devolver", AppButton.Variant.SECONDARY, func(): session.send({"type": "exchange", "swap": -1})))


func _build_pick_first() -> void:
	_header("Coup")
	if _playing() and not v.first_options.is_empty():
		_root.add_child(_big("Escolha a sua primeira carta", Tokens.MOSTARDA, "Com 2 jogadores, cada um escolhe uma entre as 5. A outra vem sorteada."))
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for r in v.first_options:
			var role: String = r
			var cp := CoupArt.card(role, 120)
			cp.tapped.connect(func(): session.send({"type": "pick_first", "role": role}))
			flow.add_child(cp)
		_root.add_child(flow)
		return
	_root.add_child(_big("Escolhendo as cartas", Tokens.SUPERFICIE, "Cada um escolhe a primeira carta..."))


func _build_game_over() -> void:
	_root.add_child(UI.spacer(8))
	_root.add_child(_big("%s venceu!" % _name(v.winner), Tokens.tint(Tokens.SALVIA, 0.45), "O último com influência na corte."))
	var c := UI.card(Tokens.PAPEL, 16)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("As cartas de cada um", 20, Tokens.TINTA, Fonts.title()))
	for p in v.players:
		var row := UI.hbox(8)
		var nl := UI.label(p.name, 18, CoupArt.player_color(int(p.color)), Fonts.body_bold())
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		for card in p.cards:
			row.add_child(CoupArt.card(card.role, 56, card.up, _variant(p.id)))
		cv.add_child(row)
	_root.add_child(c)
	_log_block()
	_end_buttons("Mesma mesa, cartas novas.")


# --- Eventos e histórico ---------------------------------------------------

func _before_rebuild(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"phase", "blocked", "block_window":
				_reacted = false
			"started":
				_hide_cards = false
				_exchange_keep = []


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"turn":
				if e.get("id", "") == _me() and _playing():
					Audio.sfx("hg_turn")
					Haptics.hg_turn()
			"declared":
				Audio.sfx("pop")
			"challenge":
				Audio.sfx("buzzer" if not e.get("had", false) else "hit")
				Haptics.hit()
			"blocked":
				Audio.sfx("hg_flip")
			"lost":
				Audio.sfx("hg_out")
			"eliminated":
				if e.get("id", "") == _me():
					Haptics.time_up()
			"game_over":
				Audio.sfx("win")
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 50, [Tokens.MOSTARDA, CoupArt.COLORS.duque, CoupArt.COLORS.condessa], 2.4)


func _save_history() -> void:
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "coup",
		"game_name": "Coup",
		"mode": "wifi",
		"summary": "%s venceu" % _name(v.winner),
		"players": v.players.map(func(p): return {"name": p.name}),
	})
