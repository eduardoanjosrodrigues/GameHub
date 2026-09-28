class_name GeniusBoard
extends Control
## O tabuleiro do Genius (docs/PLANO_GENIUS.md §7): o círculo com os 4 quartos (verde em cima à
## esquerda, vermelho em cima à direita, amarelo embaixo à esquerda, azul embaixo à direita) e o
## miolo com o placar. Toca a sequência (luz e som) e avisa os toques do jogador.
##
## A sequência é tocada numa hora marcada (ms locais): se o tabuleiro for remontado no meio, ele
## continua de onde estava, sem repetir o que já passou.

signal pressed(color: int)
signal released(color: int)
signal playback_done

const BASE := [Color("#1E9E55"), Color("#D63B2F"), Color("#F2B233"), Color("#2B59C3")]
const RIM := Color("#1F1D1A")
## Nota mínima de um toque (§2): um toque rapidinho ainda acende e soa.
const MIN_PRESS_MS := 150

## Os botões respondem ao toque.
var interactive := false:
	set(value):
		interactive = value
		queue_redraw()
var center_text := "":
	set(value):
		center_text = value
		queue_redraw()
var center_sub := "":
	set(value):
		center_sub = value
		queue_redraw()
var tones: GeniusTones

var _lit := -1 # cor acesa agora (-1 = nenhuma)
var _touch := -1 # cor que o dedo está apertando
var _touch_at := 0
var _release_pending := false
var _seq: Array = []
var _seq_start := -1 # ms locais do início da sequência (-1 = não está tocando)
var _seq_step := -1 # item da sequência que está tocando agora
var _flash_color := -1
var _flash_until := 0


func _init(p_size := 520.0) -> void:
	custom_minimum_size = Vector2(p_size, p_size)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	tones = GeniusTones.new()
	add_child(tones)


## Toca a sequência a partir de `start_ms` (Time.get_ticks_msec()). Pode estar no passado.
func play_sequence(seq: Array, start_ms: int) -> void:
	_seq = seq.duplicate()
	_seq_start = start_ms
	_seq_step = -1
	interactive = false
	_release_touch()


func is_playing() -> bool:
	return _seq_start >= 0


func stop_playback() -> void:
	_seq_start = -1
	_seq_step = -1
	_set_lit(-1)
	tones.release()


## Errou: o buzz e o botão certo piscando (§2).
func show_error(right: int) -> void:
	interactive = false
	_touch = -1
	_release_pending = false
	stop_playback()
	tones.buzz(1500)
	_flash_color = right
	_flash_until = Time.get_ticks_msec() + 1500


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _seq_start >= 0:
		_step_playback(now)
	if _release_pending and now - _touch_at >= MIN_PRESS_MS:
		_release_pending = false
		_end_touch()
	if _flash_color >= 0:
		if now >= _flash_until:
			_flash_color = -1
			_set_lit(-1)
		else:
			# Pisca 3 vezes por segundo.
			_set_lit(_flash_color if (_flash_until - now) % 333 > 140 else -1)


func _step_playback(now: int) -> void:
	var n := _seq.size()
	var light := GeniusRules.light_ms(n)
	var every := light + GeniusRules.GAP_MS
	var t := now - _seq_start
	if t < 0:
		return
	var i := t / every
	if i >= n:
		_seq_start = -1
		_seq_step = -1
		_set_lit(-1)
		playback_done.emit()
		return
	var in_light := t % every < light
	if in_light and i != _seq_step:
		_seq_step = i
		var left := light - t % every
		# Entrou tarde demais nesta cor (tela remontada): só a luz, sem som picado.
		if left > 60:
			tones.press(int(_seq[i]), left)
	_set_lit(int(_seq[i]) if in_light else -1)


func _set_lit(c: int) -> void:
	if c != _lit:
		_lit = c
		queue_redraw()


# --- Toque -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if event.pressed:
		if not interactive or _touch >= 0:
			return
		var c := _hit(event.position)
		if c < 0:
			return
		_touch = c
		_touch_at = Time.get_ticks_msec()
		_release_pending = false
		_set_lit(c)
		tones.press(c)
		Haptics.tap()
		pressed.emit(c)
	elif _touch >= 0:
		if Time.get_ticks_msec() - _touch_at < MIN_PRESS_MS:
			_release_pending = true
		else:
			_end_touch()


func _release_touch() -> void:
	if _touch >= 0:
		_release_pending = false
		_end_touch()


func _end_touch() -> void:
	var c := _touch
	_touch = -1
	if _flash_color < 0 and _seq_start < 0:
		_set_lit(-1)
		tones.release()
	released.emit(c)


## Qual quarto está no ponto (-1 = miolo ou fora).
func _hit(pos: Vector2) -> int:
	var d := pos - size / 2.0
	var r := minf(size.x, size.y) / 2.0
	if d.length() > r or d.length() < r * 0.36:
		return -1
	if d.y < 0:
		return 0 if d.x < 0 else 1
	return 2 if d.x < 0 else 3


# --- Desenho ---------------------------------------------------------------

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var inner := r * 0.36
	var gap := r * 0.05
	draw_circle(c + Vector2(0, r * 0.03), r, Color(0, 0, 0, 0.12))
	draw_circle(c, r, RIM)
	# Ângulos (y para baixo): verde em cima à esquerda, vermelho em cima à direita,
	# amarelo embaixo à esquerda, azul embaixo à direita.
	var spans := [[PI, PI * 1.5], [PI * 1.5, TAU], [PI * 0.5, PI], [0.0, PI * 0.5]]
	for i in 4:
		var base: Color = BASE[i]
		var on := i == _lit
		var col := base.lightened(0.38) if on else base.darkened(0.28 if interactive or _seq_start >= 0 else 0.4)
		var poly := _sector(c, inner + gap, r - gap, spans[i][0], spans[i][1], gap / 2.0)
		if on:
			draw_colored_polygon(_sector(c, inner + gap * 0.4, r - gap * 0.4, spans[i][0], spans[i][1], gap * 0.2), Color(base.lightened(0.6), 0.55))
		draw_colored_polygon(poly, col)
		_symbol(i, c + Vector2.from_angle((spans[i][0] + spans[i][1]) / 2.0) * (inner + r) / 2.0, r * 0.07, Color(1, 1, 1, 0.5 if on else 0.28))
	draw_circle(c, inner - gap * 0.3, Color("#2A2723"))
	draw_arc(c, inner - gap * 0.3, 0, TAU, 64, Color(1, 1, 1, 0.08), 2.0)
	var font := Fonts.display()
	if center_text != "":
		var fs := int(inner * (0.62 if center_text.length() <= 3 else 0.34))
		var w := font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var y := c.y + fs * 0.34 - (inner * 0.12 if center_sub != "" else 0.0)
		draw_string(font, Vector2(c.x - w / 2.0, y), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.SUPERFICIE)
	if center_sub != "":
		var f2 := Fonts.body_bold()
		var fs2 := int(inner * 0.16)
		var w2 := f2.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
		draw_string(f2, Vector2(c.x - w2 / 2.0, c.y + inner * 0.5), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(Tokens.SUPERFICIE, 0.7))


## Um quarto de anel, com o vão entre os quartos da mesma largura em qualquer raio.
func _sector(c: Vector2, r0: float, r1: float, a0: float, a1: float, half_gap: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 28
	var t1 := half_gap / r1
	for k in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0 + t1, a1 - t1, float(k) / steps)) * r1)
	var t0 := half_gap / r0
	for k in range(steps, -1, -1):
		pts.append(c + Vector2.from_angle(lerpf(a0 + t0, a1 - t0, float(k) / steps)) * r0)
	return pts


## Símbolo discreto de cada cor, pra quem é daltônico: ● ▲ ■ ◆.
func _symbol(i: int, p: Vector2, s: float, col: Color) -> void:
	match i:
		0:
			draw_circle(p, s, col)
		1:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.1), p + Vector2(s * 1.05, s * 0.8), p + Vector2(-s * 1.05, s * 0.8)]), col)
		2:
			draw_rect(Rect2(p - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col)
		3:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.2), p + Vector2(s * 1.1, 0), p + Vector2(0, s * 1.2), p + Vector2(-s * 1.1, 0)]), col)
