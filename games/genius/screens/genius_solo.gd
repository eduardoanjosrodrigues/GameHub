extends Screen
## Genius solo clássico (docs/PLANO_GENIUS.md §3): o aparelho toca, você repete, e a cada acerto a
## sequência ganha uma cor. Errou, acabou. Sair no meio descarta a partida.

const MENU := "res://games/genius/screens/genius_menu.gd"
## Pausa entre acertar e a próxima rodada (§2), e antes da primeira.
const NEXT_MS := 1300
const LEGEND := 31 # o original "vencia" aqui (§2.1)

var _board: GeniusBoard
var _status: Label
var _record: Label
var _end_box: VBoxContainer
var _seq: Array = []
var _i := 0
var _playing := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	music = ""
	_rng.randomize()


func _ready() -> void:
	var col := make_column(false, 20, 18)
	make_header(col, "Genius", func(): on_back())
	_record = UI.label("", 20, Tokens.TINTA_SUAVE, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_record)
	col.add_child(UI.spacer(0, true))
	_board = GeniusBoard.new(minf(620.0, get_viewport_rect().size.x - 40.0))
	_board.pressed.connect(_on_press)
	_board.playback_done.connect(_on_playback_done)
	col.add_child(_board)
	_status = UI.label("", 24, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_status)
	_end_box = UI.vbox(14)
	col.add_child(_end_box)
	col.add_child(UI.spacer(0, true))
	_update_record()
	_idle()


func on_back() -> bool:
	if _playing:
		App.confirm("Sair da partida?", "A partida não fica salva.", "Sair", func(): App.back_to(load(MENU)))
	else:
		App.back_to(load(MENU))
	return true


func _update_record() -> void:
	var b := GeniusStore.best()
	_record.text = "Recorde: %d cor%s" % [b, "" if b == 1 else "es"] if b > 0 else "Sem recorde ainda"


func _idle() -> void:
	UI.clear(_end_box)
	_board.center_text = ""
	_board.center_sub = ""
	_status.text = ""
	_end_box.add_child(_big_button("Começar", AppButton.Variant.SUCCESS, _start, "play"))


func _big_button(text: String, variant: int, on_press: Callable, icon_name: String) -> AppButton:
	var b := UI.button(text, variant, on_press, icon_name)
	b.height = 84
	b.font_size = 26
	return b


func _start() -> void:
	UI.clear(_end_box)
	_playing = true
	_seq = [GeniusRules.random_color(_rng)]
	_play_round(NEXT_MS)


func _play_round(delay_ms: int) -> void:
	_i = 0
	_board.center_text = str(_seq.size() - 1)
	_board.center_sub = "cores"
	_status.text = "Preste atenção..."
	_board.play_sequence(_seq, Time.get_ticks_msec() + delay_ms)


func _on_playback_done() -> void:
	if not _playing:
		return
	_status.text = "Sua vez!"
	_board.interactive = true


func _on_press(color: int) -> void:
	if not _playing:
		return
	if color != int(_seq[_i]):
		_game_over(int(_seq[_i]))
		return
	_i += 1
	if _i < _seq.size():
		return
	_board.interactive = false
	_board.center_text = str(_seq.size())
	if _seq.size() == LEGEND:
		_status.text = "%d cores! Igual ao Genius de verdade!" % LEGEND
		Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.3), 50)
	else:
		_status.text = "Isso!"
	_seq.append(GeniusRules.random_color(_rng))
	_play_round(NEXT_MS)


func _game_over(right: int) -> void:
	_playing = false
	_board.show_error(right)
	Haptics.time_up()
	var score := _seq.size() - 1
	var record := GeniusStore.submit(score)
	_board.center_text = str(score)
	_status.text = "Você chegou a %d cor%s" % [score, "" if score == 1 else "es"]
	if record:
		_status.text += " · Novo recorde!"
		Audio.sfx("win")
		Confetti.burst(self, Vector2(size.x / 2.0, size.y * 0.3), 60)
	_update_record()
	UI.clear(_end_box)
	_end_box.add_child(_big_button("Jogar de novo", AppButton.Variant.SUCCESS, _start, "shuffle"))
	_end_box.add_child(UI.button("Menu", AppButton.Variant.SECONDARY, func(): App.back_to(load(MENU)), "home"))
