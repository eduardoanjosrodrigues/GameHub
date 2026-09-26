extends Screen
## Configurações: música, efeitos, vibração, versão e política de privacidade.

## URL pública da política (preencher quando for hospedada — docs/PLANO_FASE_1.md P12).
const PRIVACY_URL := ""

var _col: VBoxContainer


func _ready() -> void:
	_col = make_column()
	_build()


func _build() -> void:
	UI.clear(_col)
	make_header(_col, "Configurações")
	var card := UI.card()
	var v := UI.vbox(26)
	card.add_child(v)
	v.add_child(_volume_row("Música", "music", Settings.music_volume, Settings.set_music_volume))
	v.add_child(_volume_row("Efeitos sonoros", "sound", Settings.sfx_volume, func(x):
		Settings.set_sfx_volume(x)
		Audio.sfx("hit")))
	var vib := UI.hbox(12)
	vib.add_child(UI.texture("vibrate", 36, Tokens.TINTA))
	var vl := UI.label("Vibração", 22, Tokens.TINTA, Fonts.body_bold())
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vib.add_child(vl)
	vib.add_child(UI.toggle(Settings.vibration, func(on):
		Settings.set_vibration(on)
		Haptics.hit()
		_build()))
	v.add_child(vib)
	_col.add_child(card)

	var about := UI.card()
	var av := UI.vbox(12)
	about.add_child(av)
	av.add_child(UI.label("Sobre", 22, Tokens.TINTA, Fonts.title()))
	av.add_child(UI.label("gamehub versão %s" % ProjectSettings.get_setting("application/config/version", "1.0.0"), 18, Tokens.TINTA_SUAVE))
	av.add_child(UI.label("O app não coleta dados pessoais. Nomes, configurações e histórico ficam só neste aparelho.", 16, Tokens.TINTA_SUAVE))
	if PRIVACY_URL != "":
		av.add_child(UI.small_button("Política de privacidade", AppButton.Variant.SECONDARY, func(): OS.shell_open(PRIVACY_URL)))
	_col.add_child(about)


func _volume_row(title_text: String, icon_name: String, value: float, setter: Callable) -> Control:
	var v := UI.vbox(10)
	var head := UI.hbox(12)
	head.add_child(UI.texture(icon_name, 36, Tokens.TINTA))
	var l := UI.label(title_text, 22, Tokens.TINTA, Fonts.body_bold())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(l)
	var pct := UI.label("%d%%" % roundi(value * 100), 20, Tokens.TINTA_SUAVE, Fonts.body_bold())
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(pct)
	v.add_child(head)
	var steps := UI.hbox(8)
	for i in 6:
		var level := i / 5.0
		var b := UI.small_button("", AppButton.Variant.PRIMARY if value >= level - 0.01 and i > 0 else AppButton.Variant.SECONDARY)
		b.text = "Mudo" if i == 0 else ""
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0
		b.selected = absf(value - level) < 0.01
		b.pressed.connect(func():
			setter.call(level)
			_build())
		steps.add_child(b)
	v.add_child(steps)
	return v
