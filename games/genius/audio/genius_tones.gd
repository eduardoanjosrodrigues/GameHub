class_name GeniusTones
extends Node
## Os tons do Genius gerados na hora (docs/PLANO_GENIUS.md §2.2): uma onda quadrada suavizada por
## cor, que dura exatamente o tempo do toque, e o "buzz" grave do erro. Sem arquivos de áudio.

## Notas do Simon original: verde, vermelho, amarelo, azul.
const FREQS := [415.0, 310.0, 252.0, 209.0]
const BUZZ_HZ := 42.0
const MIX_RATE := 44100.0
const ATTACK_S := 0.004
const RELEASE_S := 0.03
const LEVEL := 0.32

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _freq := 0.0
var _phase := 0.0
var _env := 0.0
var _on := false
var _lp := 0.0 # filtro passa-baixa de um polo (tira a aspereza da quadrada)
var _stop_at := -1 # ms: solta a nota sozinho (sequência tocada pelo app, erro)


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	# Buffer curto: o som sai logo depois do toque.
	gen.buffer_length = 0.06
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


## Começa a nota da cor (até release(), ou por `ms` se for maior que zero).
func press(color: int, ms := 0) -> void:
	_start(FREQS[clampi(color, 0, 3)], ms)


func buzz(ms := 1500) -> void:
	_start(BUZZ_HZ, ms)


func release() -> void:
	_on = false
	_stop_at = -1


func _start(freq: float, ms: int) -> void:
	_freq = freq
	_on = Settings.sfx_volume > 0.001
	_stop_at = Time.get_ticks_msec() + ms if ms > 0 else -1


func _process(_delta: float) -> void:
	if _stop_at >= 0 and Time.get_ticks_msec() >= _stop_at:
		release()
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var vol := LEVEL * Settings.sfx_volume
	var up := 1.0 / (ATTACK_S * MIX_RATE)
	var down := 1.0 / (RELEASE_S * MIX_RATE)
	var step := _freq / MIX_RATE
	# O buzz é bem grave: filtra menos, senão some.
	var k := 0.5 if _freq < 100.0 else 0.18
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		if _on:
			_env = minf(1.0, _env + up)
		else:
			_env = maxf(0.0, _env - down)
		var s := 0.0
		if _env > 0.0:
			_phase = fmod(_phase + step, 1.0)
			s = 1.0 if _phase < 0.5 else -1.0
		_lp += (s - _lp) * k
		var out := _lp * _env * vol
		frames[i] = Vector2(out, out)
	_playback.push_buffer(frames)
