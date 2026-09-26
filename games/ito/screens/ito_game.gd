extends PartyGameScreen
## Partida do Ito (docs/PLANO_SINTONIA_ITO.md §4 e §6.2). Serve o celular do jogador, o tabuleiro e
## o celular só. A fila é uma coluna com o fio vermelho: toque numa carta (da mão ou da fila) e
## depois em "Colocar aqui" pra pôr ou mudar de lugar.

const REVEAL_STEP_S := 0.6

var _sel := "" # carta escolhida pra pôr ou mudar de lugar
var _sel_new := false # veio da mão (pôr) ou da fila (mover)
var _pass_round := 0 # celular só: rodada em que todos já viram os números
var _pass_i := 0
var _pass_open := false
var _anim_round := -1 # rodada cuja revelação já foi animada


func _menu_path() -> String:
	return "res://games/ito/screens/ito_menu.gd"


func _game_title() -> String:
	return "Ito"


func _lobby_title() -> String:
	return "Sala do Ito"


func _icon() -> String:
	return "ito"


func _timer_text(s: int) -> String:
	return "Tempo esgotado! Hora de revelar." if s <= 0 else "Tempo: %d:%02d" % [s / 60, s % 60]


func _desafio() -> bool:
	return v.config.mode == "desafio"


func _member() -> bool:
	return _local or (not _board and _me() != "")


# --- Sala ------------------------------------------------------------------

func _config_card() -> Control:
	var cfg: Dictionary = v.config
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var modes := [["desafio", "Desafio"], ["solta", "Rodada solta"]]
	if session.is_host:
		cv.add_child(UI.segmented(modes, cfg.mode, func(k): session.send({"type": "set_config", "mode": k})))
	else:
		cv.add_child(UI.label("Modo: %s" % ("Desafio" if cfg.mode == "desafio" else "Rodada solta"), 18, Tokens.TINTA, Fonts.body_bold()))
	if cfg.mode == "desafio":
		var txt := "Começa com 1 carta cada e 3 vidas. A cada acerto, uma pessoa ganha +1 carta. Cada número fora de ordem custa 1 vida."
		txt += " Quando todos tiverem 2, o jogo termina com vitória." if _local else " Depois que todos tiverem 2, vem o modo extremo: a fila não mostra de quem é cada carta."
		cv.add_child(UI.label(txt, 16, Tokens.TINTA_SUAVE))
	else:
		cv.add_child(UI.label("Sem vidas: cada rodada vale por si. Revela e vê quantos ficaram fora de ordem.", 16, Tokens.TINTA_SUAVE))
		if session.is_host:
			cv.add_child(UI.setting_block("Cartas por pessoa", UI.stepper(int(cfg.cards), 1, 3, 1, func(x): session.send({"type": "set_config", "cards": x}))))
		else:
			cv.add_child(UI.label("Cartas por pessoa: %d" % cfg.cards, 17, Tokens.TINTA, Fonts.body_bold()))
	cv.add_child(_timer_setting(cfg, "0 = desligado. Conta a partir da escolha do tema; é só um aviso."))
	return c


# --- Fases -----------------------------------------------------------------

func _build_phase() -> void:
	match v.phase:
		"theme", "play":
			if _local and _pass_round != int(v.round_no):
				_build_pass()
			else:
				_build_table()
		"reveal":
			_build_reveal()
		"game_over":
			_build_game_over()


func _status() -> void:
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _desafio():
		row.add_child(UI.label("Nível %d" % int(v.level), _fs(24, 34), Tokens.TINTA, Fonts.title_bold()))
		row.add_child(ItoArt.Hearts.new(int(v.lives), int(v.max_lives), _fs(28, 40)))
		if int(v.best) > 0:
			row.add_child(UI.label("recorde %d" % int(v.best), _fs(16, 22), Tokens.TINTA_SUAVE, Fonts.body_bold()))
	else:
		row.add_child(UI.label("Rodada %d" % int(v.round_no), _fs(24, 34), Tokens.TINTA, Fonts.title_bold()))
	for c in row.get_children():
		if c is Label:
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
			c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(row)
	if v.extreme:
		_root.add_child(UI.label("Modo extremo: a fila não mostra de quem é cada carta.", _fs(16, 22), ItoArt.FIO, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))


func _theme_block() -> void:
	if v.phase == "theme":
		var c := UI.card(Tokens.MOSTARDA, 22)
		var cv := UI.vbox(12)
		c.add_child(cv)
		cv.add_child(UI.label("Escolham o tema", _fs(24, 34), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		for i in v.theme_options.size():
			var idx: int = i
			var b := UI.button(v.theme_options[i], AppButton.Variant.SECONDARY, func(): session.send({"type": "pick_theme", "index": idx}))
			b.disabled = not _member()
			b.font_size = _fs(20, 28)
			b.height = _fs(76, 96)
			cv.add_child(b)
		if _member():
			cv.add_child(UI.small_button("Digitar outro tema", AppButton.Variant.SECONDARY, _ask_theme, "plus"))
		else:
			cv.add_child(UI.label("Escolham no celular.", 17, Tokens.TINTA, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(c)
		return
	var t := UI.card(Tokens.tint(Tokens.MOSTARDA, 0.5), 22)
	var tv := UI.vbox(6)
	t.add_child(tv)
	tv.add_child(UI.label("Tema", _fs(15, 20), Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	tv.add_child(UI.label(v.theme, _fs(26, 40), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	tv.add_child(UI.label("1 = o mínimo · 100 = o máximo. Sem falar números!", _fs(15, 20), Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(t)


func _build_table() -> void:
	_header("Ito")
	_status()
	_theme_block()
	if not _local and not _board and not v.hand.is_empty():
		_hand_block(v.hand, "")
	if _local:
		_root.add_child(UI.small_button("Ver o meu número de novo", AppButton.Variant.SECONDARY, _peek_picker, "person"))
	if v.phase == "theme":
		_root.add_child(UI.caption("Olhem os seus números e pensem num exemplo. Depois de escolher o tema, montem a fila."))
		return
	_timer_row()
	if _local and not v.loose.is_empty():
		_loose_block()
	_row_block()
	if v.all_placed:
		if _member():
			var b := UI.button("Revelar", AppButton.Variant.SUCCESS, func():
				App.confirm("Revelar a fila?", "Todo mundo concorda com a ordem?", "Revelar", func(): session.send({"type": "reveal"}), "Ainda não", false), "play")
			b.height = 84
			b.font_size = 26
			_root.add_child(b)
		else:
			_root.add_child(UI.caption("Quando todo mundo concordar, alguém revela no celular."))
	else:
		_root.add_child(UI.caption(_pending_text()))


func _pending_text() -> String:
	var p: Dictionary = v.pending
	if p.is_empty():
		return "Faltam %d carta%s na fila." % [int(v.pending_total), "" if int(v.pending_total) == 1 else "s"]
	var parts: Array = []
	for pl in v.players:
		if p.has(pl.id):
			parts.append("%s (%d)" % [pl.name, int(p[pl.id])] if int(p[pl.id]) > 1 else pl.name)
	return "Falta pôr na fila: %s" % ", ".join(parts)


## As cartas de uma pessoa, com palavra-chave e "Pôr na fila". as_id: celular só.
func _hand_block(hand: Array, as_id: String) -> void:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var cv := UI.vbox(12)
	c.add_child(cv)
	cv.add_child(UI.label("Seu número" if hand.size() == 1 else "Seus números", 22, Tokens.TINTA, Fonts.title()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	for h in hand:
		var box := UI.vbox(8)
		box.custom_minimum_size.x = 150
		var cardv := ItoArt.number_card(int(h.n), 130.0, Tokens.SALVIA if h.placed else ItoArt.FIO)
		cardv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(cardv)
		box.add_child(UI.label(h.word if h.word != "" else "sem palavra-chave", 15, Tokens.TINTA if h.word != "" else Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		var cid: String = h.card
		var cur: String = h.word
		box.add_child(UI.small_button("Palavra-chave", AppButton.Variant.SECONDARY, func(): _ask_word(cid, cur, as_id)))
		if as_id == "" and v.phase == "play":
			if h.placed:
				box.add_child(UI.label("na fila", 15, Tokens.SALVIA_ESCURO, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			else:
				var sel := _sel == cid
				var b := UI.small_button("Escolhida" if sel else "Pôr na fila", AppButton.Variant.PRIMARY if sel else AppButton.Variant.SUCCESS, func(): _select(cid, true))
				box.add_child(b)
		flow.add_child(box)
	cv.add_child(flow)
	if as_id == "" and v.phase == "play" and hand.any(func(h): return not h.placed):
		cv.add_child(UI.caption("Toque em \"Pôr na fila\" e depois em \"Colocar aqui\" no lugar certo da fila."))
	_root.add_child(c)


func _ask_theme() -> void:
	_prompt("Tema", "Uma frase, tipo \"O quão barulhento é um lugar\". 1 é o mínimo e 100 é o máximo.", [["O quão ...", ""]], _send_theme, ItoRules.THEME_MAX)


func _send_theme(vals: Array) -> void:
	if vals[0] != "":
		session.send({"type": "custom_theme", "text": vals[0]})


func _ask_word(cid: String, cur: String, as_id: String) -> void:
	_prompt("Palavra-chave", "Opcional: uma palavra pra lembrar a sua dica (\"tubarão\"). Aparece embaixo da carta na fila. Sem números!", [["ex: tubarão", cur]], _send_word.bind(cid, as_id), ItoRules.WORD_MAX)


func _send_word(vals: Array, cid: String, as_id: String) -> void:
	var a := {"type": "word", "card": cid, "text": vals[0]}
	if as_id != "":
		a["as"] = as_id
	session.send(a)


## Celular só: as cartas que ainda não foram pra fila (sem número), pro grupo pôr.
func _loose_block() -> void:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Fora da fila", 20, Tokens.TINTA, Fonts.title()))
	for l in v.loose:
		var row := UI.hbox(10)
		var txt := "Carta de %s" % _name(l.owner) + (" · %s" % l.word if l.word != "" else "")
		var pr := UI.player_row(txt, _color(l.owner), true, "")
		pr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pr)
		var cid: String = l.card
		var sel := _sel == cid
		row.add_child(UI.small_button("Escolhida" if sel else "Pôr", AppButton.Variant.PRIMARY if sel else AppButton.Variant.SUCCESS, func(): _select(cid, true)))
		cv.add_child(row)
	cv.add_child(UI.caption("Quem é o dono diz onde a carta vai: toque em \"Pôr\" e depois em \"Colocar aqui\"."))
	_root.add_child(c)


func _select(cid: String, from_hand: bool) -> void:
	if _sel == cid:
		_sel = ""
	else:
		_sel = cid
		_sel_new = from_hand
	_rebuild()


## A fila, do 0 (menor) pra cima, com o fio vermelho.
func _row_block() -> void:
	var c := UI.card(Tokens.SUPERFICIE, 18)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("A fila", 22, Tokens.TINTA, Fonts.title()))
	var th := ItoArt.ThreadLine.new()
	th.add_theme_constant_override("separation", 8)
	th.add_child(_end_marker("0 · o mínimo"))
	var row: Array = v.row
	var sel_i := -1
	for i in row.size():
		if row[i].card == _sel:
			sel_i = i
	var can_move := _member()
	for i in row.size() + 1:
		if _sel != "" and can_move and (_sel_new or (i != sel_i and i != sel_i + 1)):
			var to := i if _sel_new or i <= sel_i else i - 1
			var gap := UI.small_button("Colocar aqui", AppButton.Variant.ACCENT, _drop.bind(to), "down")
			gap.custom_minimum_size.x = 0
			var gm := UI.margin(0, 0, 0)
			gm.add_theme_constant_override("margin_left", 52)
			gm.add_child(gap)
			th.add_child(gm)
		if i < row.size():
			th.add_child(_row_card(row[i], can_move))
	th.add_child(_end_marker("100 · o máximo"))
	cv.add_child(th)
	if row.is_empty():
		cv.add_child(UI.caption("Ninguém pôs carta ainda. Quem acha que tem um número bem baixo começa!"))
	_root.add_child(c)


func _end_marker(text: String) -> Control:
	var m := UI.margin(0, 2, 2)
	m.add_theme_constant_override("margin_left", 52)
	m.add_child(UI.label(text, _fs(15, 20), Tokens.TINTA_SUAVE, Fonts.body_bold()))
	m.set_meta("knot", true)
	return m


func _row_card(r: Dictionary, can_move: bool) -> Control:
	var sel: bool = r.card == _sel
	var owner: String = r.owner
	var p := TapPanel.new(Tokens.MOSTARDA if sel else (Tokens.tint(_color(owner), 0.25) if owner != "" else Tokens.PAPEL), 14)
	p.set_meta("knot", true)
	var outer := UI.margin(0, 0, 0)
	outer.add_theme_constant_override("margin_left", 52)
	outer.set_meta("knot", true)
	outer.add_child(p)
	var row := UI.hbox(12)
	p.add_child(row)
	var txt := UI.vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UI.label(_name(owner) if owner != "" else "?", _fs(19, 26), Tokens.TINTA, Fonts.body_bold()))
	if r.word != "":
		txt.add_child(UI.label("“%s”" % r.word, _fs(17, 24), Tokens.TINTA, Fonts.body()))
	row.add_child(txt)
	if int(r.n) >= 0:
		row.add_child(ItoArt.number_card(int(r.n), _fs(52, 70), Tokens.SALVIA))
	if can_move:
		var cid: String = r.card
		p.tapped.connect(func(): _select(cid, false))
		if sel and r.mine:
			row.add_child(UI.small_button("Tirar", AppButton.Variant.SECONDARY, func():
				_sel = ""
				session.send({"type": "take_back", "card": cid})))
	return outer


func _drop(to: int) -> void:
	var cid := _sel
	var fresh := _sel_new
	_sel = ""
	session.send({"type": "place" if fresh else "move", "card": cid, "to": to})
	Haptics.tap()


# --- Celular só ------------------------------------------------------------

func _build_pass() -> void:
	var list: Array = v.players
	if _pass_i >= list.size():
		_pass_i = 0
	var p: Dictionary = list[_pass_i]
	_header("Ito")
	_status()
	if not _pass_open:
		_gate(p.name, "Pra ver o seu número (%d de %d)" % [_pass_i + 1, list.size()], func():
			_pass_open = true
			_rebuild())
		return
	var pv := session.view_as(p.id)
	_root.add_child(UI.label("%s, só você olha!" % p.name, 24, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_hand_block(pv.hand, p.id)
	var last := _pass_i == list.size() - 1
	var b := UI.button("Esconder e passar" if not last else "Esconder e pôr no meio da mesa", AppButton.Variant.PRIMARY, func():
		_pass_open = false
		_pass_i += 1
		if _pass_i >= list.size():
			_pass_i = 0
			_pass_round = int(v.round_no)
		_rebuild(), "check")
	b.height = 80
	_root.add_child(b)


## Celular só: alguém quer ver o próprio número de novo.
func _peek_picker() -> void:
	var col := _open_panel()
	col.add_child(UI.title("Quem vai olhar?", 32))
	for p in v.players:
		var pid: String = p.id
		var pname: String = p.name
		col.add_child(UI.button(pname, AppButton.Variant.SECONDARY, func(): _peek_show(pid, pname)))
	col.add_child(UI.button("Fechar", AppButton.Variant.PRIMARY, _close_panel))


func _peek_show(pid: String, pname: String) -> void:
	var col := _open_panel()
	col.add_child(UI.title("%s, só você olha!" % pname, 30))
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 14)
	for h in session.view_as(pid).hand:
		flow.add_child(ItoArt.number_card(int(h.n), 130.0))
	col.add_child(flow)
	col.add_child(UI.button("Esconder", AppButton.Variant.PRIMARY, _close_panel, "check"))
	var panel := _panel
	get_tree().create_timer(4.0).timeout.connect(func():
		if _panel == panel:
			_close_panel())


# --- Revelação -------------------------------------------------------------

func _build_reveal() -> void:
	_header("Revelação")
	_status()
	_theme_block()
	var res: Dictionary = v.result
	var errors: Array = res.get("errors", [])
	var c := UI.card(Tokens.SUPERFICIE, 18)
	var th := ItoArt.ThreadLine.new()
	th.add_theme_constant_override("separation", 8)
	c.add_child(th)
	th.add_child(_end_marker("0 · o mínimo"))
	var slots: Array = []
	for r in v.row:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", ThemeBuilder.card_style(Tokens.tint(_color(r.owner), 0.25)))
		var row := UI.hbox(12)
		p.add_child(row)
		var txt := UI.vbox(2)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UI.label(_name(r.owner), _fs(19, 26), Tokens.TINTA, Fonts.body_bold()))
		if r.word != "":
			txt.add_child(UI.label("“%s”" % r.word, _fs(17, 24), Tokens.TINTA, Fonts.body()))
		row.add_child(txt)
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(_fs(56, 76), _fs(70, 96))
		row.add_child(holder)
		var m := UI.margin(0, 0, 0)
		m.add_theme_constant_override("margin_left", 52)
		m.add_theme_constant_override("margin_top", 4)
		m.add_theme_constant_override("margin_bottom", 4)
		m.set_meta("knot", true)
		m.add_child(p)
		th.add_child(m)
		slots.append({"holder": holder, "panel": p, "n": int(r.n), "bad": r.card in errors})
	th.add_child(_end_marker("100 · o máximo"))
	_root.add_child(c)
	var result := _result_card(res)
	_root.add_child(result)
	var cont := UI.button("Próxima rodada" if res.get("next", "") == "round" else "Ver o fim", AppButton.Variant.SUCCESS, func(): session.send({"type": "continue"}), "play")
	cont.height = 80
	cont.visible = _member() or _board
	_root.add_child(cont)
	if int(v.round_no) == _anim_round:
		for s in slots:
			_flip(s)
		return
	# Suspense: os números aparecem um por um.
	result.visible = false
	cont.disabled = true
	var tw := create_tween()
	for s in slots:
		tw.tween_interval(REVEAL_STEP_S)
		tw.tween_callback(func():
			if is_instance_valid(s.holder):
				_flip(s)
				Audio.sfx("buzzer" if s.bad else "tick")
				if s.bad:
					Haptics.skip())
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		_anim_round = int(v.round_no)
		if is_instance_valid(result):
			result.visible = true
			cont.disabled = false
			Audio.sfx("win" if res.get("ok", false) else "skip")
			if res.get("ok", false):
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.3), 40, [ItoArt.FIO, Tokens.MOSTARDA, Tokens.SALVIA], 2.0))


func _flip(s: Dictionary) -> void:
	UI.clear(s.holder)
	s.holder.add_child(ItoArt.number_card(s.n, _fs(52, 70), Tokens.VERMELHO if s.bad else Tokens.SALVIA))
	if s.bad:
		(s.panel as PanelContainer).add_theme_stylebox_override("panel", ThemeBuilder.card_style(Tokens.tint(Tokens.VERMELHO, 0.35)))


func _result_card(res: Dictionary) -> Control:
	var errs: int = res.get("errors", []).size()
	if res.get("ok", false):
		var sub := "Todos em ordem!"
		if _desafio():
			sub = "Venceram o Desafio!" if res.get("won", false) else "Próximo nível: uma pessoa ganha mais uma carta."
		return _big("Acertaram!", Tokens.tint(Tokens.SALVIA, 0.45), sub)
	var sub2 := "%d fora de ordem." % errs
	if _desafio():
		sub2 = "%d fora de ordem: −%d vida%s." % [errs, int(res.lost), "" if int(res.lost) == 1 else "s"]
		sub2 += " Acabaram as vidas!" if res.get("next", "") == "game_over" else " O nível se repete com números novos."
	return _big("Quase!", Tokens.tint(Tokens.VERMELHO, 0.35), sub2)


# --- Fim -------------------------------------------------------------------

func _build_game_over() -> void:
	_root.add_child(UI.spacer(8))
	match v.end_reason:
		"won":
			_root.add_child(_big("Vocês venceram!", Tokens.tint(Tokens.SALVIA, 0.45), "Chegaram ao nível %d sem perder todas as vidas." % int(v.best)))
		"lives":
			_root.add_child(_big("Acabaram as vidas", Tokens.tint(Tokens.VERMELHO, 0.3), "Maior nível vencido: %d" % int(v.best) if int(v.best) > 0 else "Nenhum nível vencido. Na próxima vai!"))
		_:
			_root.add_child(_big("Fim de jogo", Tokens.MOSTARDA, "%d rodada%s" % [v.rounds.size(), "" if v.rounds.size() == 1 else "s"]))
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("As rodadas", 22, Tokens.TINTA, Fonts.title()))
	var k := 0
	for r in v.rounds:
		k += 1
		var head := "%d. %s" % [k, r.theme]
		if _desafio():
			head = "%d. Nível %d · %s" % [k, int(r.level), r.theme]
		cv.add_child(UI.label(head, 17, Tokens.TINTA, Fonts.body_bold()))
		var nums: Array = r.cards.map(func(x): return str(int(x.n)))
		cv.add_child(UI.label("   %s · %s" % [" ".join(nums), "tudo em ordem" if int(r.errors) == 0 else "%d fora de ordem" % int(r.errors)], 15, Tokens.TINTA_SUAVE))
	if k == 0:
		cv.add_child(UI.label("Nenhuma rodada revelada.", 16, Tokens.TINTA_SUAVE))
	_root.add_child(c)
	_end_buttons("Mesma mesa, do nível 1." if _desafio() else "Mesma mesa, números novos.")


# --- Eventos e histórico ---------------------------------------------------

func _before_rebuild(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"started":
				_pass_round = 0
				_pass_i = 0
				_pass_open = false
				_anim_round = -1
			"dealt":
				_sel = ""


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"dealt":
				Audio.sfx("round")
				Haptics.hit()
			"theme":
				Audio.sfx("pop")
			"row":
				if e.get("by", "") != _me() and not _local:
					Audio.sfx("tap")


func _save_history() -> void:
	var summary := ""
	match v.end_reason:
		"won":
			summary = "Venceram o Desafio (nível %d)" % int(v.best)
		"lives":
			summary = "Desafio até o nível %d" % int(v.best) if int(v.best) > 0 else "Desafio: nenhum nível vencido"
		_:
			summary = "%d rodadas soltas" % v.rounds.size()
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "ito",
		"game_name": "Ito",
		"mode": "local" if _local else "wifi",
		"summary": summary,
		"players": v.players.map(func(p): return {"name": p.name}),
	})
