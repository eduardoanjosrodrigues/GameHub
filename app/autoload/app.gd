extends Node
## Navegação entre telas, avisos (toast), confirmações, botão voltar e link de entrada (QR).

signal deep_link(code: String)

var main: Control
var _stack: Array[Screen] = []
var _host: Control
var _overlay: Control
var _toast_box: VBoxContainer
var _last_link := ""
var _pending_link := ""
var _modal: Control


func register_main(p_main: Control, host: Control, overlay: Control) -> void:
	main = p_main
	_host = host
	_overlay = overlay
	_toast_box = UI.vbox(10)
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.position.y -= 40
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_toast_box)


func _ready() -> void:
	get_tree().quit_on_go_back = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested()
		NOTIFICATION_APPLICATION_RESUMED:
			check_deep_link()


# --- Navegação -------------------------------------------------------------

func current() -> Screen:
	return _stack.back() if not _stack.is_empty() else null


## Abre uma tela por cima da atual.
func push(screen: Screen) -> void:
	var old := current()
	_stack.append(screen)
	_show(screen, old, 1)


## Troca a tela atual (sem voltar pra ela).
func replace(screen: Screen) -> void:
	var old: Screen = _stack.pop_back() if not _stack.is_empty() else null
	_stack.append(screen)
	_show(screen, old, 1, true)


## Volta pra tela anterior.
func back() -> void:
	if _stack.size() <= 1:
		return
	var old: Screen = _stack.pop_back()
	_show(current(), old, -1, true)


## Volta até a primeira tela (início do hub).
func home() -> void:
	if _stack.size() <= 1:
		return
	var old: Screen = _stack.pop_back()
	while _stack.size() > 1:
		var s: Screen = _stack.pop_back()
		s.queue_free()
	_show(current(), old, -1, true)


## Volta até a primeira tela do tipo (script) informado.
func back_to(script: Script) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].get_script() == script:
			var old: Screen = _stack.pop_back()
			while _stack.size() > i + 1:
				var s: Screen = _stack.pop_back()
				s.queue_free()
			_show(current(), old, -1, true)
			return
	home()


func _show(screen: Screen, old: Screen, dir: int, free_old := false) -> void:
	if screen.get_parent() == null:
		_host.add_child(screen)
	screen.visible = true
	Audio.music(screen.music)
	var w := _host.size.x
	screen.position = Vector2(w * 0.35 * dir, 0)
	screen.modulate.a = 0.0
	var tw := screen.create_tween().set_parallel(true)
	tw.tween_property(screen, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(screen, "modulate:a", 1.0, 0.18)
	if old and old != screen:
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw2 := old.create_tween().set_parallel(true)
		tw2.tween_property(old, "position:x", -w * 0.35 * dir, 0.22)
		tw2.tween_property(old, "modulate:a", 0.0, 0.18)
		if free_old:
			tw2.chain().tween_callback(old.queue_free)
		else:
			tw2.chain().tween_callback(func(): old.visible = false; _host.remove_child(old))


func back_requested() -> void:
	if _modal:
		_close_modal()
		return
	var s := current()
	if s and s.on_back():
		return
	if _stack.size() > 1:
		back()
	else:
		get_tree().quit()


# --- Avisos e confirmações -------------------------------------------------

func toast(text: String, color := Tokens.BRANCO) -> void:
	if _toast_box == null:
		return
	var c := UI.card(color, 18)
	c.custom_minimum_size.x = min(520.0, _host.size.x - 48.0)
	var l := UI.label(text, 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	c.add_child(l)
	_toast_box.add_child(c)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(c, "modulate:a", 0.0, 0.3)
	tw.tween_callback(c.queue_free)


## Janela de confirmação. on_yes é chamado se a pessoa confirmar.
func confirm(title_text: String, body: String, yes_text: String, on_yes: Callable, no_text := "Cancelar", danger := true) -> void:
	_close_modal()
	var shade := ColorRect.new()
	shade.color = Color(Tokens.TINTA, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	_modal = shade
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := UI.card(Tokens.BRANCO, 28)
	card.custom_minimum_size.x = min(560.0, _host.size.x - 48.0)
	center.add_child(card)
	var v := UI.vbox(20)
	card.add_child(v)
	v.add_child(UI.title(title_text, 32))
	if body != "":
		v.add_child(UI.label(body, 20, Tokens.TINTA_SUAVE, Fonts.body(), HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(14)
	row.add_child(UI.button(no_text, CartoonButton.Variant.SECONDARY, _close_modal))
	row.add_child(UI.button(yes_text, CartoonButton.Variant.DANGER if danger else CartoonButton.Variant.PRIMARY, func():
		_close_modal()
		on_yes.call()))
	v.add_child(row)
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.85, 0.85)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


# --- Link de entrada (QR code lido pela câmera do celular) ----------------

func check_deep_link() -> void:
	var data := _read_intent_data()
	if data == "" or data == _last_link:
		return
	_last_link = data
	var code := DeepLink.parse(data)
	if code != "":
		_pending_link = code
		deep_link.emit(code)


## Consome o código pendente vindo de um QR (ou "" se não houver).
func take_pending_link() -> String:
	var c := _pending_link
	_pending_link = ""
	return c


func _read_intent_data() -> String:
	if not Engine.has_singleton("AndroidRuntime"):
		return ""
	var rt = Engine.get_singleton("AndroidRuntime")
	var activity = rt.getActivity()
	if activity == null:
		return ""
	var intent = activity.getIntent()
	if intent == null:
		return ""
	var data = intent.getDataString()
	if data == null:
		return ""
	return str(data)
