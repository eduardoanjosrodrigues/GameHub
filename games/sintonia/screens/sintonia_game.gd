extends PartyGameScreen
## Partida da Sintonia (docs/PLANO_SINTONIA_ITO.md §3 e §6.1). Serve o celular do jogador, o
## tabuleiro e o celular só. A agulha é ao vivo: quem gira manda a posição algumas vezes por
## segundo, e as outras telas só movem a agulha, sem remontar.

## Nota do cooperativo (tabela oficial, traduzida).
const COOP_RATING := [[3, "Tá ligado na tomada?"], [6, "Desliga e liga de novo"], [9, "Assopra o cartucho"],
	[12, "Nada mal. Nada bom, mas nada mal"], [15, "Quase!"], [18, "Vocês venceram!"], [21, "Na mesma sintonia"],
	[24, "Cérebro galáctico"], [999, "Cabeça explodindo"]]

var _dial: SintoniaDial
var _dial_by: Label
var _psy_open := false # celular só: quem dá a dica está com o celular
var _psy_done := -1 # celular só: rodada em que quem deu a dica já escondeu o alvo


func _menu_path() -> String:
	return "res://games/sintonia/screens/sintonia_menu.gd"


func _game_title() -> String:
	return "Sintonia"


func _lobby_title() -> String:
	return "Sala da Sintonia"


func _icon() -> String:
	return "sintonia"


func _timer_text(s: int) -> String:
	return "Tempo esgotado! Travem a agulha." if s <= 0 else "Tempo: %d:%02d" % [s / 60, s % 60]


func _live_events() -> Array:
	return ["dial"]


func _live_update(_events: Array) -> bool:
	if not is_instance_valid(_dial) or not _dial.is_inside_tree():
		return false
	_dial.set_pos(float(v.dial))
	_update_dial_by()
	return true


func _times() -> bool:
	return v.config.mode == "times"


func _round_key() -> int:
	return v.rounds.size()


func _is_psy() -> bool:
	return not _local and not _board and _me() != "" and _me() == v.psychic


func _can_turn() -> bool:
	if _local or _board:
		return true
	if _me() == "" or _me() == v.psychic:
		return false
	return not _times() or v.my_team == v.turn_team


func _can_bet() -> bool:
	if _local or _board:
		return true
	return _me() != "" and v.my_team != "" and v.my_team != v.turn_team


func _member() -> bool:
	return _local or _board or _me() != ""


func _team_name(t: String) -> String:
	return Tokens.team_name(t)


## Ação por quem dá a dica: no celular só, o aparelho age por essa pessoa.
func _psy_send(a: Dictionary) -> void:
	if _local:
		a["as"] = v.psychic
	session.send(a)


# --- Sala ------------------------------------------------------------------

func _config_card() -> Control:
	var cfg: Dictionary = v.config
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var modes := [["times", "Times"], ["coop", "Cooperativo"]]
	if session.is_host:
		cv.add_child(UI.segmented(modes, cfg.mode, func(k): session.send({"type": "set_config", "mode": k})))
	else:
		cv.add_child(UI.label("Modo: %s" % ("Times" if cfg.mode == "times" else "Cooperativo"), 18, Tokens.TINTA, Fonts.body_bold()))
	if cfg.mode == "times":
		cv.add_child(UI.label("Dois times. O outro time aposta se o alvo está à esquerda ou à direita da agulha. Ganha quem fizer 10 pontos.", 16, Tokens.TINTA_SUAVE))
	else:
		cv.add_child(UI.label("Todo mundo junto, 7 rodadas. Acertar o centro dá uma rodada extra. No fim, a nota do grupo.", 16, Tokens.TINTA_SUAVE))
	cv.add_child(_timer_setting(cfg, "0 = desligado. Conta enquanto o time gira a agulha; é só um aviso."))
	return c


## Com times: cada um no seu time; o host troca e sorteia.
func _players_card() -> Control:
	if not _times():
		return super()
	var pc := UI.card()
	var pv := UI.vbox(10)
	pc.add_child(pv)
	pv.add_child(UI.label("Times (%d)" % v.players.size(), 22, Tokens.TINTA, Fonts.title()))
	if session.is_host:
		pv.add_child(UI.label("Toque no time de alguém pra trocar. A dica roda dentro de cada time, de cima pra baixo.", 16, Tokens.TINTA_SUAVE))
		pv.add_child(UI.small_button("Sortear times", AppButton.Variant.SECONDARY, func(): session.send({"type": "shuffle_teams"}), "shuffle"))
	for team in SintoniaRules.TEAMS:
		var members: Array = v.players.filter(func(p): return p.team == team)
		var head := UI.card(Tokens.tint(Tokens.team_color(team), 0.3), 14)
		var hv := UI.vbox(8)
		head.add_child(hv)
		hv.add_child(UI.label("%s (%d)" % [_team_name(team), members.size()], 20, Tokens.team_dark(team), Fonts.title_bold()))
		for p in members:
			var i: int = v.players.find(p)
			var extra := "desconectado" if not p.connected else ("você" if p.id == _me() else "")
			var row := UI.player_row(p.name, HalliArt.player_color(int(p.color)), p.connected, extra)
			if session.is_host:
				var pid: String = p.id
				var to := SintoniaRules.other(team)
				row.add_child(UI.small_button("→ %s" % ("Azul" if to == "azul" else "Vermelho"), AppButton.Variant.TEAM_AZUL if to == "azul" else AppButton.Variant.TEAM_VERMELHO, func(): session.send({"type": "set_team", "id": pid, "team": to})))
				_order_buttons(row, pid, i, v.players.size())
			hv.add_child(row)
		if members.is_empty():
			hv.add_child(UI.caption("Ninguém ainda."))
		pv.add_child(head)
	return pc


# --- Placar e disco --------------------------------------------------------

func _score() -> void:
	if _times():
		var row := UI.hbox(12)
		for t in SintoniaRules.TEAMS:
			var turn: bool = t == v.turn_team and v.phase != "game_over"
			var c := UI.card(Tokens.tint(Tokens.team_color(t), 0.55 if turn else 0.2), 14)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cv := UI.vbox(0)
			c.add_child(cv)
			cv.add_child(UI.label(_team_name(t) + ("  · vez" if turn else ""), _fs(16, 22), Tokens.team_dark(t), Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			cv.add_child(UI.label("%d" % int(v.scores[t]), _fs(40, 60), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
			row.add_child(c)
		_root.add_child(row)
		_root.add_child(UI.label("Ganha quem fizer %d%s" % [int(v.win_at), " · MORTE SÚBITA" if v.sudden else ""], _fs(15, 20), Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var done: int = v.rounds.size()
		var row2 := UI.hbox(16)
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_child(UI.label("%d pontos" % int(v.coop_score), _fs(30, 44), Tokens.TINTA, Fonts.title_bold()))
		var cur: int = done + (0 if v.phase in ["reveal", "game_over"] else 1)
		row2.add_child(UI.label("rodada %d de %d" % [cur, done + int(v.cards_left)], _fs(17, 24), Tokens.TINTA_SUAVE, Fonts.body_bold()))
		for c in row2.get_children():
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
			c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_root.add_child(row2)


## O disco com os dois extremos embaixo.
func _dial_block(show_target: bool, interactive: bool, show_needle := true) -> SintoniaDial:
	var c := UI.card(Tokens.PAPEL, 16)
	var cv := UI.vbox(6)
	c.add_child(cv)
	var d := SintoniaDial.new()
	d.pos = float(v.dial)
	d.target = float(v.target) if show_target else -1.0
	d.show_needle = show_needle
	d.side = v.side if v.phase in ["guess", "reveal"] and _times() else ""
	var turn: String = v.rounds.back().team if v.phase == "reveal" and not v.rounds.is_empty() else v.turn_team
	d.side_color = Tokens.team_color(SintoniaRules.other(turn)) if _times() else Tokens.VERMELHO
	d.set_interactive(interactive)
	if interactive:
		d.moved.connect(func(p): session.send({"type": "dial", "pos": p}))
		d.released.connect(func(p): session.send({"type": "dial", "pos": p}))
	cv.add_child(d)
	if v.theme.size() == 2:
		var row := UI.hbox(10)
		var l := UI.label(v.theme[0], _fs(20, 30), Tokens.AZUL_ESCURO, Fonts.title_bold())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r := UI.label(v.theme[1], _fs(20, 30), Tokens.VERMELHO_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_RIGHT)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(r)
		cv.add_child(row)
	_root.add_child(c)
	_dial = d
	return d


func _update_dial_by() -> void:
	if not is_instance_valid(_dial_by):
		return
	var by: String = v.dial_by
	_dial_by.text = "%s está mexendo" % _name(by) if by != "" and by != _me() and not _local else ""


# --- Fases -----------------------------------------------------------------

func _build_phase() -> void:
	_dial = null
	_dial_by = null
	match v.phase:
		"pick":
			_build_pick()
		"dial":
			_build_dial()
		"guess":
			_build_guess()
		"reveal":
			_build_reveal()
		"game_over":
			_build_game_over()


func _psy_line() -> String:
	var who := _name(v.psychic)
	return "%s (%s)" % [who, _team_name(v.turn_team)] if _times() else who


func _build_pick() -> void:
	_header("Sintonia")
	_score()
	if _local and not _psy_open:
		_gate(_name(v.psychic), "Quem dá a dica vê o alvo e escolhe o tema. Os outros não olham!", func():
			_psy_open = true
			_rebuild())
		return
	if _is_psy() or _local:
		_root.add_child(_big("Você dá a dica", Tokens.MOSTARDA, "Veja onde está o alvo e escolha um dos temas."))
		var d := _dial_block(true, false, false)
		var opts: Array = v.options
		if _local:
			var pv := session.view_as(v.psychic)
			opts = pv.options
			d.target = float(pv.target)
		for i in opts.size():
			var opt: Array = opts[i]
			var idx: int = i
			var t := TapPanel.new(Tokens.SUPERFICIE, 20, Tokens.TINTA, 3)
			var row := UI.hbox(10)
			var l := UI.label(opt[0], 22, Tokens.AZUL_ESCURO, Fonts.title_bold())
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r := UI.label(opt[1], 22, Tokens.VERMELHO_ESCURO, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_RIGHT)
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(r)
			t.add_child(row)
			t.tapped.connect(func(): _psy_send({"type": "pick_theme", "index": idx}))
			_root.add_child(t)
		_root.add_child(UI.small_button("Digitar outro tema", AppButton.Variant.SECONDARY, _ask_theme, "plus"))
		_root.add_child(UI.caption("Toque num tema. Depois, fale uma dica que leve a agulha até o alvo."))
		return
	_root.add_child(_big("%s vai dar a dica" % _psy_line(), Tokens.SUPERFICIE, "Escolhendo o tema..."))
	_dial_block(false, false, false)


func _ask_theme() -> void:
	_prompt("Tema", "Os dois extremos: um de cada lado do disco.", [["Esquerda (ex: Frio)", ""], ["Direita (ex: Quente)", ""]], _send_theme, SintoniaRules.SIDE_MAX)


func _send_theme(vals: Array) -> void:
	_psy_send({"type": "custom_theme", "left": vals[0], "right": vals[1]})


func _build_dial() -> void:
	_header("Sintonia")
	_score()
	if _local and _psy_done != _round_key():
		# Quem deu a dica ainda está com o celular: olha o alvo de novo e esconde.
		_root.add_child(_big("Hora da dica!", Tokens.MOSTARDA, "Fale a sua dica em voz alta. Depois esconda o alvo e ponha o celular no meio da mesa."))
		var d := _dial_block(true, false, false)
		d.target = float(session.view_as(v.psychic).target)
		var b := UI.button("Esconder o alvo e pôr no meio", AppButton.Variant.PRIMARY, func():
			_psy_open = false
			_psy_done = _round_key()
			_rebuild(), "check")
		b.height = 80
		_root.add_child(b)
		return
	_timer_row()
	if _is_psy():
		_root.add_child(_big("Fale a sua dica!", Tokens.MOSTARDA, "Depois, nada de ajudar: nem cara, nem som."))
		_dial_block(true, false)
		_dial_by = UI.label("", 16, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		_root.add_child(_dial_by)
		_update_dial_by()
		return
	var turning := _can_turn()
	var team_txt := "O %s gira a agulha" % _team_name(v.turn_team) if _times() else "Todo mundo gira a agulha"
	_root.add_child(UI.label("Dica de %s" % _psy_line(), _fs(20, 30), Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_dial_block(false, turning)
	_dial_by = UI.label("", 16, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_dial_by)
	_update_dial_by()
	if turning:
		_root.add_child(UI.caption("%s. Arraste no disco. Quando concordarem, travem." % team_txt))
		var b := UI.button("Travar a agulha", AppButton.Variant.SUCCESS, func():
			App.confirm("Travar a agulha?", "Todo mundo do time concorda?", "Travar", func(): session.send({"type": "lock"}), "Ainda não", false), "check")
		b.height = 80
		_root.add_child(b)
	else:
		_root.add_child(UI.caption("%s. Vocês ficam só olhando." % team_txt))


func _build_guess() -> void:
	_header("Sintonia")
	_score()
	var rival := SintoniaRules.other(v.turn_team)
	_dial_block(_is_psy(), false)
	if _can_bet():
		_root.add_child(_big("%s: esquerda ou direita?" % _team_name(rival), Tokens.tint(Tokens.team_color(rival), 0.35), "O centro do alvo está pra que lado da agulha? Acertando, 1 ponto."))
		var row := UI.hbox(12)
		for s in [["left", "← Esquerda"], ["right", "Direita →"]]:
			var key: String = s[0]
			var b := UI.button(s[1], AppButton.Variant.PRIMARY if v.side == key else AppButton.Variant.SECONDARY, func(): session.send({"type": "side", "side": key}))
			b.height = 84
			b.font_size = 24
			row.add_child(b)
		_root.add_child(row)
		var lock := UI.button("Travar a aposta", AppButton.Variant.SUCCESS, func(): session.send({"type": "lock_side"}), "check")
		lock.disabled = v.side == ""
		lock.height = 76
		_root.add_child(lock)
		return
	var sub := "Apostando..." if v.side == "" else "Por enquanto: %s" % ("esquerda" if v.side == "left" else "direita")
	_root.add_child(_big("O %s está apostando" % _team_name(rival), Tokens.SUPERFICIE, sub))


func _build_reveal() -> void:
	_header("Revelação")
	_score()
	_dial_block(true, false)
	var last: Dictionary = v.last
	var pts: int = int(last.get("points", 0))
	var title := "No centro!" if pts == 4 or last.get("bonus", false) else ("+%d ponto%s" % [pts, "" if pts == 1 else "s"] if pts > 0 else "Passou longe!")
	var lines: Array = []
	if _times():
		lines.append("%s fez %d." % [_team_name(v.rounds.back().team), pts])
		var rival := SintoniaRules.other(v.rounds.back().team)
		if v.rounds.back().side != "":
			if int(last.get("side_points", 0)) > 0:
				lines.append("%s acertou o lado: +1." % _team_name(rival))
			elif pts == 4:
				lines.append("Centro: a aposta do %s não vale." % _team_name(rival))
			else:
				lines.append("%s errou o lado." % _team_name(rival))
		if last.get("catch_up", false):
			lines.append("Recuperação! O %s joga de novo." % _team_name(v.rounds.back().team))
		if v.sudden and v.winner == "":
			lines.append("Empate: morte súbita!")
	else:
		if last.get("bonus", false):
			lines.append("Centro vale 3 e dá uma rodada extra!")
	if v.winner != "":
		lines.append("Fim de jogo!")
	var color := Tokens.tint(Tokens.SALVIA, 0.45) if pts >= 3 else (Tokens.MOSTARDA if pts > 0 else Tokens.tint(Tokens.VERMELHO, 0.3))
	_root.add_child(_big(title, color, " ".join(lines)))
	if _member():
		var b := UI.button("Ver o resultado" if v.winner != "" else "Próxima rodada", AppButton.Variant.SUCCESS, func(): session.send({"type": "continue"}), "play")
		b.height = 80
		_root.add_child(b)


func _coop_rating(score: int) -> String:
	for r in COOP_RATING:
		if score <= r[0]:
			return r[1]
	return ""


func _build_game_over() -> void:
	_root.add_child(UI.spacer(8))
	if _times():
		var w: String = v.winner
		_root.add_child(_big("%s venceu!" % _team_name(w), Tokens.tint(Tokens.team_color(w), 0.45), "%d a %d" % [int(v.scores[w]), int(v.scores[SintoniaRules.other(w)])]))
	else:
		_root.add_child(_big("%d pontos" % int(v.coop_score), Tokens.MOSTARDA, _coop_rating(int(v.coop_score))))
	_score()
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("As rodadas", 22, Tokens.TINTA, Fonts.title()))
	var k := 0
	for r in v.rounds:
		k += 1
		var who := _name(r.psychic)
		var head := "%d. %s – %s · dica de %s" % [k, r.theme[0], r.theme[1], who]
		cv.add_child(UI.label(head, 17, Tokens.TINTA, Fonts.body_bold()))
		cv.add_child(UI.label("   alvo %s, agulha %s: %d ponto%s%s" % [_num(r.target), _num(r.dial), int(r.points), "" if int(r.points) == 1 else "s", " · aposta certa" if int(r.side_points) > 0 else ""], 15, Tokens.TINTA_SUAVE))
	_root.add_child(c)
	_end_buttons("Mesmos times e mesmo modo." if _times() else "Mesma mesa, 7 rodadas de novo.")


func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x


# --- Eventos e histórico ---------------------------------------------------

func _before_rebuild(events: Array) -> void:
	for e in events:
		if e.get("type", "") in ["started", "round"]:
			_psy_open = false
		if e.get("type", "") == "started":
			_psy_done = -1


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"round":
				if e.get("psychic", "") == _me() and not _board and not _local:
					Audio.sfx("hg_turn")
					Haptics.hg_turn()
				else:
					Audio.sfx("pop")
			"locked", "side_locked":
				Audio.sfx("tap")
			"revealed":
				var p: int = int(e.get("points", 0))
				Audio.sfx("win" if p >= 4 or e.get("bonus", false) else ("hit" if p > 0 else "skip"))
				Haptics.hit()
				if p >= 4 or e.get("bonus", false):
					Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.3), 40, [Tokens.AZUL, Tokens.MOSTARDA, Tokens.VERMELHO], 2.0)
			"game_over":
				Audio.sfx("win")


func _save_history() -> void:
	var summary := ""
	if _times():
		var w: String = v.winner
		summary = "%s venceu, %d a %d" % [_team_name(w), int(v.scores[w]), int(v.scores[SintoniaRules.other(w)])]
	else:
		summary = "Cooperativo: %d pontos (%s)" % [int(v.coop_score), _coop_rating(int(v.coop_score))]
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "sintonia",
		"game_name": "Sintonia",
		"mode": "local" if _local else "wifi",
		"summary": summary,
		"players": v.players.map(func(p): return {"name": p.name, "team": p.get("team", "")}),
	})
