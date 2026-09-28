extends Screen
## Menu do Wordle (docs/PLANO_WORDLE_SENHA.md §6): palavra do dia, treino (palavra, Dueto e
## Quarteto), modo difícil, Corrida no Wi-Fi, estatísticas e como jogar.

const WordleSolo := preload("res://games/wordle/screens/wordle_solo.gd")
const WordleHowTo := preload("res://games/wordle/screens/wordle_how_to.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")
const NET_INFO := {
	"id": "wordle",
	"name": "Wordle",
	"game": "res://games/wordle/screens/wordle_net.gd",
}

var _col: VBoxContainer
var _clock: Label


func _ready() -> void:
	visibility_changed.connect(func(): if visible: _build())
	_build()


func _build() -> void:
	# Remonta no mesmo ponto da rolagem (ex: depois de trocar uma opção).
	var old: Array = find_children("*", "ScrollContainer", true, false)
	var keep: int = old[0].scroll_vertical if not old.is_empty() else 0
	for ch in get_children():
		ch.queue_free()
	_col = make_column()
	var sc: Array = find_children("*", "ScrollContainer", true, false).filter(func(s): return not s in old)
	if not sc.is_empty():
		(func(): sc[0].scroll_vertical = keep).call_deferred()
	_clock = null
	make_header(_col, "Wordle")
	var ic := UI.texture("wordle", 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(ic)
	_col.add_child(UI.caption("Descubra a palavra de 5 letras. Verde: letra certa no lugar certo. Amarelo: a letra existe, mas em outro lugar."))
	_col.add_child(_daily_card())
	_col.add_child(_training_card())
	_col.add_child(_hard_card())
	_col.add_child(_wifi_card())
	var row := UI.hbox(12)
	var st := UI.small_button("Estatísticas", AppButton.Variant.SECONDARY, func(): App.push(stats_screen()), "trophy")
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(st)
	var how := UI.small_button("Como jogar", AppButton.Variant.SECONDARY, func(): App.push(WordleHowTo.new()), "book")
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(how)
	_col.add_child(row)


static func stats_screen() -> Screen:
	return DesafioStatsScreen.new("Estatísticas do Wordle", [
		{"key": "wordle_dia", "title": "Palavra do dia", "daily": true, "tries": 6},
		{"key": "wordle_treino", "title": "Treino", "daily": false, "tries": 6},
		{"key": "wordle_dueto", "title": "Dueto", "daily": false, "tries": 7},
		{"key": "wordle_quarteto", "title": "Quarteto", "daily": false, "tries": 9},
	])


func _process(_d: float) -> void:
	if _clock and is_instance_valid(_clock):
		_clock.text = "Próxima palavra em %s" % Desafio.mmss(Desafio.seconds_to_midnight())


func _daily_card() -> Control:
	var today := Desafio.day_index()
	var g := DesafioStore.today_game("wordle_dia", today)
	var c := UI.card(Tokens.tint(Tokens.SALVIA, 0.22), 22)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label("Palavra do dia", 26, Tokens.TINTA, Fonts.title()))
	var st := DesafioStore.stats("wordle_dia", today)
	var tries: int = g.get("guesses", []).size()
	if g.get("finished", false):
		v.add_child(UI.label(("Acertou em %d! " % tries if g.get("won", false) else "Não foi dessa vez. ") + "Sequência: %d" % st.streak, 18, Tokens.TINTA, Fonts.body_bold()))
		_clock = UI.label("", 17, Tokens.TINTA_SUAVE, Fonts.body_bold())
		v.add_child(_clock)
		v.add_child(UI.button("Ver o resultado", AppButton.Variant.SECONDARY, func(): App.push(WordleSolo.new("dia")), "check"))
	else:
		v.add_child(UI.label("A mesma palavra pra todo mundo, uma por dia. Sequência: %d" % st.streak, 17, Tokens.TINTA_SUAVE))
		var label := "Continuar (%d de 6)" % tries if tries > 0 else "Jogar"
		var b := UI.button(label, AppButton.Variant.SUCCESS, func(): App.push(WordleSolo.new("dia")), "play")
		b.height = 76
		v.add_child(b)
	return c


func _training_card() -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 22)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label("Treino", 26, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label("Quantas quiser, sem mexer na sequência do dia.", 17, Tokens.TINTA_SUAVE))
	for m in [["treino", "Uma palavra", "6 tentativas"], ["dueto", "Dueto", "2 palavras ao mesmo tempo, 7 tentativas"], ["quarteto", "Quarteto", "4 palavras ao mesmo tempo, 9 tentativas"]]:
		var saved := DesafioStore.load_game("wordle_" + m[0])
		var going: bool = not saved.is_empty() and not saved.get("finished", false) and not saved.get("guesses", []).is_empty()
		var row := UI.hbox(12)
		var b := UI.small_button(m[1] + (" · continuar" if going else ""), AppButton.Variant.PRIMARY if m[0] == "treino" else AppButton.Variant.SECONDARY, func(): App.push(WordleSolo.new(m[0])), "play")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		v.add_child(row)
		v.add_child(UI.label(m[2], 15, Tokens.TINTA_SUAVE))
	return c


func _hard_card() -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var row := UI.hbox(12)
	c.add_child(row)
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.label("Modo difícil", 20, Tokens.TINTA, Fonts.body_bold()))
	tv.add_child(UI.label("As dicas reveladas precisam ser usadas nos próximos palpites. Muda só antes do 1º palpite.", 15, Tokens.TINTA_SUAVE))
	row.add_child(tv)
	var on: bool = DesafioStore.pref("wordle_dificil", false)
	row.add_child(UI.toggle(on, func(x):
		DesafioStore.set_pref("wordle_dificil", x)
		_build()))
	return c


func _wifi_card() -> Control:
	var c := UI.card(Tokens.tint(Tokens.AZUL, 0.16), 22)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label("Corrida no Wi-Fi", 26, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label("Todo mundo tenta a mesma palavra, cada um no seu celular (ou no navegador).", 17, Tokens.TINTA_SUAVE))
	var row := UI.hbox(12)
	var info := NET_INFO.duplicate()
	info.host = func(role: String, n: String): return WordleHost.new(role, n)
	var create := UI.small_button("Criar sala", AppButton.Variant.SUCCESS, func(): App.push(PartyCreateRoom.new(info)), "wifi")
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(create)
	var join := UI.small_button("Entrar", AppButton.Variant.ACCENT, func(): App.push(JoinScreen.new()), "enter")
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(join)
	v.add_child(row)
	return c
