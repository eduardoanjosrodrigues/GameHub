extends PartyGameScreen
## Partida do Genius com mais gente (docs/PLANO_GENIUS.md §4 e §5):
##   Passa o aparelho (PartyLocal): "Vez de Fulano" → Pronto → o Genius toca → a pessoa repete.
##   Corrida (GeniusHost/GeniusClient): a sequência toca na mesma hora em todo celular (relógio do
##     host) e cada um repete no seu. A rodada espera todo mundo.
## O aparelho confere cada toque na hora (pra luz e o erro saírem sem atraso) e manda pro host, que
## decide de verdade.

## Passa o aparelho: pausa entre "Pronto" e a sequência, e antes de passar a vez.
const LOCAL_LEAD_MS := 1000
const AFTER_OK_MS := 700
const AFTER_FAIL_MS := 1700

var _board_ui: GeniusBoard
var _status: Label
var _pending_box: VBoxContainer
var _ready_round := -1 # Passa o aparelho: a vez em que a pessoa já tocou em Pronto
var _key := "" # rodada (ou vez) em que _i e _state valem
var _i := 0 # quantas cores este aparelho já acertou nesta rodada
var _state := "" # "", "ok" ou "fail" nesta rodada
var _sending := false # Passa o aparelho: o último toque espera a animação


func _menu_path() -> String:
	return "res://games/genius/screens/genius_menu.gd"


func _game_title() -> String:
	return "Genius"


func _lobby_title() -> String:
	return "Sala do Genius"


func _icon() -> String:
	return "genius"


func _config_card() -> Control:
	var c := UI.card(Tokens.PAPEL, 20)
	var cv := UI.vbox(8)
	c.add_child(cv)
	if _local:
		cv.add_child(UI.label("Na sua vez, repita a sequência. Acertou, ela ganha uma cor e passa pro próximo; errou, você sai. Ganha quem sobrar.", 16, Tokens.TINTA_SUAVE))
	else:
		cv.add_child(UI.label("A sequência toca junto em todos os celulares e cada um repete no seu. Quem errar sai. Ganha quem sobrar.", 16, Tokens.TINTA_SUAVE))
	cv.add_child(UI.label("De 2 a 12 pessoas.", 15, Tokens.TINTA_SUAVE))
	return c


# --- Relógio ---------------------------------------------------------------

func _host_now() -> int:
	if session is PartyClockClient:
		return (session as PartyClockClient).host_now_ms()
	return Time.get_ticks_msec()


## Hora do host → Time.get_ticks_msec() deste aparelho.
func _to_local(host_ms: int) -> int:
	return Time.get_ticks_msec() + host_ms - _host_now()


# --- Fases -----------------------------------------------------------------

func _before_rebuild(events: Array) -> void:
	if events.any(func(e): return e.get("type", "") == "started"):
		_ready_round = -1
	var key := "%s|%d|%d" % [v.phase, int(v.round_no), int(v.round_at)]
	if v.phase in ["turn", "round"] and key != _key:
		_key = key
		_i = 0
		_state = ""
		_sending = false


func _live_events() -> Array:
	return ["press", "you_ok", "you_fail", "forfeit", "player_connection"]


func _live_update(_events: Array) -> bool:
	if not is_instance_valid(_status):
		return false
	if v.phase == "round":
		_update_status()
		return true
	# Passa o aparelho: cada toque certo não muda a tela.
	return v.phase == "turn"


func _build_phase() -> void:
	_board_ui = null
	_status = null
	_pending_box = null
	match v.phase:
		"turn":
			_build_turn()
		"round":
			_build_round()
		"round_end":
			_build_round_end()
		"game_over":
			_build_game_over()


func _new_board() -> GeniusBoard:
	var w := minf(600.0, get_viewport_rect().size.x - 40.0)
	var b := GeniusBoard.new(w)
	b.pressed.connect(_on_press)
	b.playback_done.connect(_on_playback_done)
	_board_ui = b
	return b


## Passa o aparelho: a vez de alguém.
func _build_turn() -> void:
	_header("Genius · um celular")
	var who: String = v.turn
	var n: int = v.seq.size()
	if _ready_round != int(v.round_no):
		_root.add_child(UI.spacer(10))
		var c := UI.card(Tokens.MOSTARDA, 28)
		var cv := UI.vbox(10)
		c.add_child(cv)
		cv.add_child(UI.label("Vez de", 22, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.title(_name(who), 52))
		cv.add_child(UI.label("Sequência de %d cor%s" % [n, "" if n == 1 else "es"], 20, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		_root.add_child(c)
		var b := UI.button("Pronto", AppButton.Variant.SUCCESS, func():
			_ready_round = int(v.round_no)
			_rebuild(), "play")
		b.height = 84
		b.font_size = 26
		_root.add_child(b)
		_root.add_child(_alive_card())
		return
	_root.add_child(UI.label("%s · %d cor%s" % [_name(who), n, "" if n == 1 else "es"], 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
	var board := _new_board()
	_root.add_child(board)
	_status = UI.label("Preste atenção...", 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_status)
	board.center_text = str(n)
	board.center_sub = "cores" if n != 1 else "cor"
	board.play_sequence(v.seq, Time.get_ticks_msec() + LOCAL_LEAD_MS)


## Um celular só: aqui ele passa de mão em mão a cada vez.
func _add_player_card() -> Control:
	var c := super()
	for l in c.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Um celular só"):
			(l as Label).text = "Um celular só: ele passa de mão em mão, e cada um joga na sua vez. Todo mundo pode assistir."
	return c


func _alive_card() -> Control:
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("Na mesa", 20, Tokens.TINTA, Fonts.title()))
	for p in v.players:
		var out := int(p.out_round) >= 0
		var extra := "saiu" if out else ("agora" if p.id == v.turn else "")
		var row := UI.player_row(p.name, HalliArt.player_color(int(p.color)), not out, extra)
		cv.add_child(row)
	return c


## Corrida: a rodada.
func _build_round() -> void:
	_header("Genius · rodada %d" % int(v.round_no))
	var n: int = v.seq.size()
	var me_in: bool = _me() in v.alive
	if not me_in:
		_root.add_child(UI.caption("Você saiu. Dá pra assistir até o fim."))
	var board := _new_board()
	_root.add_child(board)
	_status = UI.label("", 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(_status)
	_pending_box = UI.vbox(8)
	_root.add_child(_pending_box)
	board.center_sub = "cores" if n != 1 else "cor"
	var start := _to_local(int(v.round_at))
	if Time.get_ticks_msec() < _to_local(int(v.input_at)):
		board.play_sequence(v.seq, start)
	elif me_in and _state == "" and str(v.mine) == "":
		board.interactive = true
	_update_status()


func _update_status() -> void:
	if not is_instance_valid(_status):
		return
	var me_in: bool = _me() in v.alive
	var mine: String = _state if _state != "" else str(v.mine)
	var playing := is_instance_valid(_board_ui) and _board_ui.is_playing()
	var waiting: int = int(v.pending)
	if not me_in:
		_status.text = "Assistindo · faltam %d" % waiting if not playing else "Assistindo..."
	elif mine == "ok":
		_status.text = "Acertou! Esperando %d pessoa%s" % [waiting, "" if waiting == 1 else "s"] if waiting > 0 else "Acertou!"
	elif mine == "fail" or mine == "forfeit":
		_status.text = "Errou! Esperando %d pessoa%s" % [waiting, "" if waiting == 1 else "s"] if waiting > 0 else "Errou!"
	elif playing or Time.get_ticks_msec() < _to_local(int(v.input_at)):
		_status.text = "Preste atenção..."
	else:
		_status.text = "Sua vez!"
	_host_pending()


## O host vê quem ainda não terminou e pode desistir de esperar (§5, 12).
func _host_pending() -> void:
	if not is_instance_valid(_pending_box):
		return
	UI.clear(_pending_box)
	if not (session is PartyHost) or _local:
		return
	var mine: String = _state if _state != "" else str(v.mine)
	if mine == "" and _me() in v.alive:
		return
	var rules: GeniusRules = (session as PartyHost).rules
	var waiting: Array = rules.pending()
	if waiting.is_empty():
		return
	var c := UI.card(Tokens.PAPEL, 16)
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("Ainda jogando", 18, Tokens.TINTA, Fonts.title()))
	for id in waiting:
		var p := _player(id)
		var row := UI.player_row(p.get("name", "?"), HalliArt.player_color(int(p.get("color", 0))), p.get("connected", true), "" if p.get("connected", true) else "caiu")
		row.add_child(UI.small_button("Não esperar", AppButton.Variant.SECONDARY, func():
			App.confirm("Não esperar %s?" % p.get("name", "?"), "%s sai da partida." % p.get("name", "?"), "Não esperar", func(): session.send({"type": "drop_player", "id": id}))))
		cv.add_child(row)
	_pending_box.add_child(c)


func _process(delta: float) -> void:
	super(delta)
	if v.get("phase", "") != "round" or not is_instance_valid(_board_ui):
		return
	var left := _to_local(int(v.round_at)) - Time.get_ticks_msec()
	if left > 0:
		_board_ui.center_text = str(ceili(left / 1000.0))
		_board_ui.center_sub = "rodada %d" % int(v.round_no) if not v.last.get("repeat", false) or int(v.last.get("round", 0)) != int(v.round_no) else "de novo!"
	else:
		var n: int = v.seq.size()
		_board_ui.center_text = str(n)
		_board_ui.center_sub = "cores" if n != 1 else "cor"


func _on_playback_done() -> void:
	if v.phase == "turn":
		_status.text = "Sua vez, %s!" % _name(v.turn)
		_board_ui.interactive = true
	elif v.phase == "round":
		if _me() in v.alive and _state == "" and str(v.mine) == "":
			_board_ui.interactive = true
		_update_status()


func _on_press(color: int) -> void:
	var seq: Array = v.seq
	if _i >= seq.size() or _sending:
		return
	var right: int = int(seq[_i])
	var i := _i
	var action := {"type": "press", "color": color, "i": i}
	if color != right:
		_state = "fail"
		_board_ui.show_error(right)
		Haptics.time_up()
		if _local:
			_status.text = "Errou! %s saiu." % _name(v.turn)
			_send_later(action, AFTER_FAIL_MS)
		else:
			session.send(action)
			_update_status()
		return
	_i += 1
	if _i < seq.size():
		session.send(action)
		return
	_board_ui.interactive = false
	if _local:
		_status.text = "Isso! Passe pro próximo."
		_send_later(action, AFTER_OK_MS)
	else:
		_state = "ok"
		session.send(action)
		_update_status()


func _send_later(action: Dictionary, ms: int) -> void:
	_sending = true
	var key := _key
	get_tree().create_timer(ms / 1000.0).timeout.connect(func():
		if key == _key and not _leaving:
			session.send(action))


## Corrida: quem passou e quem saiu nesta rodada.
func _build_round_end() -> void:
	_header("Genius · rodada %d" % int(v.last.get("round", v.round_no)))
	var last: Dictionary = v.last
	if last.get("repeat", false):
		_root.add_child(_big("Todos erraram!", Tokens.MOSTARDA, "Ninguém sai: a rodada se repete."))
	else:
		var nxt: int = int(last.get("len", 0)) + 1
		_root.add_child(_big("%d cor%s!" % [int(last.get("len", 0)), "" if int(last.get("len", 0)) == 1 else "es"], Tokens.tint(Tokens.SALVIA, 0.35), "Próxima: %d cores" % nxt))
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	for id in last.get("passed", []):
		cv.add_child(UI.player_row(_name(id), _color(id), true, "✓ passou"))
	for id in last.get("failed", []):
		cv.add_child(UI.player_row(_name(id), _color(id), false, "errou de novo" if last.get("repeat", false) else "✗ saiu"))
	for id in last.get("forfeit", []):
		cv.add_child(UI.player_row(_name(id), _color(id), false, "✗ saiu"))
	_root.add_child(c)


func _build_game_over() -> void:
	_header("Genius")
	var winners: Array = v.winners
	var best := 0
	for r in v.ranking:
		best = maxi(best, int(r.best))
	if winners.is_empty():
		_root.add_child(_big("Fim de jogo", Tokens.MOSTARDA))
	else:
		_root.add_child(_big("%s venceu!" % _names(winners), Tokens.MOSTARDA, "Chegou a %d cor%s" % [best, "" if best == 1 else "es"]))
	var c := UI.card()
	var cv := UI.vbox(8)
	c.add_child(cv)
	cv.add_child(UI.label("Classificação", 22, Tokens.TINTA, Fonts.title()))
	for r in v.ranking:
		var b := int(r.best)
		cv.add_child(UI.player_row(_name(r.id), _color(r.id), true, "%dº · %d cor%s" % [int(r.pos), b, "" if b == 1 else "es"]))
	_root.add_child(c)
	_end_buttons("Todos voltam, com uma sequência nova.")


func _game_events(events: Array) -> void:
	for e in events:
		match e.get("type", ""):
			"game_over":
				Audio.sfx("win")
				Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.2), 50)
			"round_result":
				if _me() in e.get("passed", []):
					Haptics.hit()


func _save_history() -> void:
	var names: Array = v.winners.map(func(id): return _name(id))
	var best := 0
	for r in v.ranking:
		best = maxi(best, int(r.best))
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"game": "genius",
		"game_name": "Genius",
		"mode": "local" if _local else "wifi",
		"summary": "%s venceu com %d cores" % [" e ".join(names), best] if not names.is_empty() else "Fim de jogo",
		"players": v.ranking.map(func(r): return {"name": _name(r.id), "pos": int(r.pos), "best": int(r.best)}),
	})
