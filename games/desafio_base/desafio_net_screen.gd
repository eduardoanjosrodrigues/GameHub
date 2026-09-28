class_name DesafioNetScreen
extends PartyGameScreen
## Base das telas de rede do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md §5): contagem, a sua grade
## com a entrada (teclado ou paleta), as mini-grades dos outros só com as cores, e o resultado.
## Os palpites dos outros chegam ao vivo sem remontar a tela (o que você está digitando não some).
## Cada jogo define a grade, a entrada e como o segredo aparece.

var _count_end := -1.0
var _count_label: Label
var _my_board: Control
var _minis: HFlowContainer
var _status: Label
var _pending := false # palpite enviado, esperando a resposta do host


# --- O que cada jogo define ------------------------------------------------

## Grade de um jogador. kind: "mine" (a sua, grande), "mini" (só as cores) ou "result" (fim).
func _make_board(_kind: String) -> Control:
	return Control.new()


func _reveal(board: Control) -> void:
	if board.has_method("reveal_last"):
		board.reveal_last()


func _set_board(_board: Control, _bv: Dictionary, _active: bool) -> void:
	pass


## Teclado ou paleta.
func _make_input() -> Control:
	return Control.new()


## Atualiza a entrada (cores do teclado, travar quando terminou...).
func _update_input(_done: bool) -> void:
	pass


## O segredo revelado no fim.
func _secret_widget() -> Control:
	return UI.spacer()


## Palpite aceito (limpa o que foi digitado) ou recusado.
func _guess_result(_accepted: bool) -> void:
	pass


func _config_lines() -> Array:
	return []


# --- Fases -----------------------------------------------------------------

func _ready() -> void:
	super()
	# Ação recusada pelo host (ex: senha inválida): libera pra tentar de novo.
	session.error.connect(func(_m): _pending = false)


func _lobby_title() -> String:
	return "Sala do %s" % _game_title()


func _live_events() -> Array:
	return ["guess", "rejected", "solved", "out", "player_connection", "turn"]


func _live_update(events: Array) -> bool:
	if v.phase != "play" or not is_instance_valid(_my_board):
		return false
	_update_play(events)
	return true


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"round":
				Audio.sfx("start")
			"go":
				Audio.sfx("round")
				Haptics.countdown_pulse()
			"solved":
				if e.id == _me():
					Audio.sfx("win")
					Haptics.hit()
				else:
					App.toast("%s acertou!" % _name(e.id), Tokens.SALVIA)
			"time_up":
				Audio.sfx("buzzer")
				Haptics.time_up()
			"game_over":
				Audio.sfx("win")


func _before_rebuild(events: Array) -> void:
	for e in events:
		if e.get("type", "") in ["round", "started"]:
			_pending = false
			_guess_result(true)


func _process(delta: float) -> void:
	super(delta)
	if _count_label and is_instance_valid(_count_label) and _count_end > 0:
		var left := _count_end - Time.get_ticks_msec()
		_count_label.text = str(maxi(1, int(ceil(left / 1000.0)))) if left > 0 else "Já!"


func _build_phase() -> void:
	match v.phase:
		"countdown":
			_build_countdown()
		"play":
			_build_play()
		"round_end", "game_over":
			_build_results()


func _build_countdown() -> void:
	_header(_game_title())
	_count_end = Time.get_ticks_msec() + float(v.countdown_ms)
	var c := UI.card(Tokens.MOSTARDA, 30)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label(_round_text(), 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_count_label = UI.label("3", 120, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(_count_label)
	cv.add_child(UI.label("Prepare-se!", 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	_root.add_child(UI.spacer(40))
	_root.add_child(c)
	for line in _config_lines():
		_root.add_child(UI.caption(line))


func _round_text() -> String:
	if int(v.rounds_total) > 1:
		return "Rodada %d de %d" % [v.round, v.rounds_total]
	return "Todo mundo tenta o mesmo segredo"


func _build_play() -> void:
	_header(_game_title())
	_timer_row()
	if int(v.rounds_total) > 1:
		_root.add_child(UI.caption(_round_text()))
	_my_board = _make_board("mine")
	_root.add_child(_my_board)
	_status = UI.label("", 19, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_status)
	_root.add_child(_make_input())
	_minis = HFlowContainer.new()
	_minis.add_theme_constant_override("h_separation", 14)
	_minis.add_theme_constant_override("v_separation", 14)
	_minis.alignment = FlowContainer.ALIGNMENT_CENTER
	_root.add_child(_minis)
	_update_play([])


func _update_play(events: Array) -> void:
	var me: Dictionary = v.get("me", {})
	for e in events:
		if e.get("id", "") != _me():
			continue
		match e.type:
			"rejected":
				_pending = false
				_guess_result(false)
				App.toast(e.msg, Tokens.VERMELHO)
				Haptics.skip()
			"guess":
				_pending = false
				_guess_result(true)
	var done: bool = me.get("done", false)
	_set_board(_my_board, me, not done)
	for e in events:
		if e.get("type", "") == "guess" and e.id == _me():
			_reveal(_my_board)
			Audio.sfx("pop")
	_update_input(done)
	if me.get("solved", false):
		_status.text = "Acertou em %d! Esperando os outros..." % me.guesses.size()
	elif done:
		_status.text = "Acabaram suas tentativas. Esperando os outros..."
	else:
		_status.text = ""
	UI.clear(_minis)
	for o in v.get("others", []):
		var box := UI.vbox(4)
		var p := _player(o.id)
		var name := UI.label(("✓ " if o.solved else "") + str(p.get("name", "?")), 15, Tokens.SALVIA_ESCURO if o.solved else (Tokens.TINTA if p.get("connected", true) else Tokens.TEXTO_DESABILITADO), Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		name.custom_minimum_size.x = 110
		box.add_child(name)
		var mb := _make_board("mini")
		box.add_child(mb)
		_set_board(mb, {"guesses": o.c.map(func(c): return {"w": "", "c": c})}, false)
		_minis.add_child(box)


func _build_results() -> void:
	var over: bool = v.phase == "game_over"
	_header("Fim de jogo" if over else "Fim da rodada")
	var sc := UI.card(Tokens.tint(Tokens.SALVIA, 0.25), 22)
	var sv := UI.vbox(10)
	sc.add_child(sv)
	sv.add_child(UI.label("Tempo esgotado! O segredo era:" if v.get("time_up", false) else "O segredo era:", 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(_secret_widget())
	_root.add_child(sc)
	var pontos: bool = v.config.criterio == "pontos"
	if pontos and over:
		_root.add_child(_standings_card())
	_root.add_child(_results_card())
	# As grades completas de todo mundo, agora com as letras.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	for r in v.results:
		var bv: Dictionary = v.boards.get(r.id, {})
		if bv.is_empty():
			continue
		var box := UI.vbox(4)
		box.add_child(UI.label(_name(r.id), 16, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		var b := _make_board("result")
		box.add_child(b)
		_set_board(b, bv, false)
		flow.add_child(box)
	_root.add_child(flow)
	if not over:
		if session.is_host:
			_root.add_child(UI.button("Próxima rodada", AppButton.Variant.SUCCESS, func(): session.send({"type": "next_round"}), "play"))
		else:
			_root.add_child(UI.caption("Esperando o host chamar a próxima rodada..."))
		_root.add_child(UI.button("Sair", AppButton.Variant.SECONDARY, func(): on_back(), "home"))
		return
	_end_buttons("Mesma sala, segredo novo.")


func _results_card() -> Control:
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	var pontos: bool = v.config.criterio == "pontos"
	cv.add_child(UI.label("Resultado da rodada" if pontos else "Classificação", 22, Tokens.TINTA, Fonts.title()))
	for r in v.results:
		var extra: String
		if r.solved:
			extra = "%d tent. · %s" % [r.tries, _secs(int(r.ms))]
			if pontos:
				extra += " · +%d" % r.points
		else:
			extra = "não acertou"
		cv.add_child(UI.player_row("%dº %s" % [r.pos, _name(r.id)], _color(r.id), true, extra))
	return c


func _standings_card() -> Control:
	var c := UI.card(Tokens.tint(Tokens.MOSTARDA, 0.35), 20)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("Placar final", 22, Tokens.TINTA, Fonts.title()))
	var list: Array = v.standings
	for i in list.size():
		cv.add_child(UI.player_row("%dº %s" % [i + 1, _name(list[i].id)], _color(list[i].id), true, "%d pontos" % list[i].score))
	return c


func _secs(ms: int) -> String:
	return "%.1f s" % (ms / 1000.0) if ms < 60000 else Desafio.mmss(ms / 1000)


func _config_card() -> Control:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(14)
	c.add_child(cv)
	cv.add_child(UI.label("Partida", 22, Tokens.TINTA, Fonts.title()))
	var cfg: Dictionary = v.config
	if not session.is_host:
		for line in _config_lines():
			cv.add_child(UI.label(line, 17, Tokens.TINTA, Fonts.body_bold()))
		return c
	_host_config(cv, cfg)
	return c


## Opções do host na sala. Os jogos acrescentam as suas.
func _host_config(cv: VBoxContainer, cfg: Dictionary) -> void:
	var hints := {"tentativas": "Ganha quem acertar com menos palpites; empatando, o mais rápido.", "primeiro": "Ganha quem acertar primeiro. Os outros continuam, pra decidir o 2º e o 3º lugar.", "pontos": "Várias rodadas: quem acerta ganha pontos pelas tentativas que sobraram, mais 3/2/1 pra quem chegou primeiro."}
	cv.add_child(UI.setting_block("Quem vence", UI.segmented([["tentativas", "Tentativas"], ["primeiro", "Primeiro"], ["pontos", "Pontos"]], cfg.criterio, func(k): session.send({"type": "set_config", "criterio": k})), hints[cfg.criterio]))
	if cfg.criterio == "pontos":
		cv.add_child(UI.setting_block("Rodadas", UI.segmented(RaceRules.ROUND_OPTIONS.map(func(n): return [str(n), str(n)]), str(cfg.rodadas), func(k): session.send({"type": "set_config", "rodadas": int(k)}))))
	cv.add_child(_time_block(cfg))


func _time_block(cfg: Dictionary) -> Control:
	return UI.setting_block("Tempo limite", UI.segmented(RaceRules.TIME_OPTIONS.map(func(n): return [str(n), "Sem" if n == 0 else "%d min" % n]), str(cfg.tempo_min), func(k): session.send({"type": "set_config", "tempo_min": int(k)})), "Acabando o tempo, quem não acertou perde a rodada.")


func _race_lines() -> Array:
	var cfg: Dictionary = v.config
	var out: Array = ["Vence: %s" % RaceRules.CRITERIA[cfg.criterio] + (" (%d rodadas)" % cfg.rodadas if cfg.criterio == "pontos" else "")]
	out.append("Tempo: %s" % ("sem limite" if int(cfg.tempo_min) == 0 else "%d min" % cfg.tempo_min))
	return out


func _save_history() -> void:
	var names: Array
	if v.config.criterio == "pontos" and not v.standings.is_empty():
		names = [_name(v.standings[0].id)]
	else:
		names = v.results.filter(func(r): return r.pos == 1 and r.solved).map(func(r): return _name(r.id))
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": session.game_id,
		"game_name": _game_title(),
		"mode": "wifi",
		"summary": ("Venceu %s" % " e ".join(names)) if not names.is_empty() else "Ninguém acertou",
		"players": v.players.map(func(p): return {"name": p.name}),
	})
