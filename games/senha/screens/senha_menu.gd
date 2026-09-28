extends Screen
## Menu do Senha (docs/PLANO_WORDLE_SENHA.md §6): senha do dia por nível, treino, retorno e
## aparência (escolha do jogador no solo), Duelo e Corrida no Wi-Fi, estatísticas e como jogar.

const SenhaSolo := preload("res://games/senha/screens/senha_solo.gd")
const SenhaHowTo := preload("res://games/senha/screens/senha_how_to.gd")
const JoinScreen := preload("res://app/screens/join_screen.gd")

var _col: VBoxContainer


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
	make_header(_col, "Senha")
	var ic := UI.texture("senha", 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(ic)
	_col.add_child(UI.caption("Descubra a sequência secreta de pinos em até 10 tentativas, com as dicas de cada palpite."))
	_col.add_child(_daily_card())
	_col.add_child(_training_card())
	_col.add_child(_look_card())
	_col.add_child(_wifi_card())
	var row := UI.hbox(12)
	var st := UI.small_button("Estatísticas", AppButton.Variant.SECONDARY, func(): App.push(stats_screen()), "trophy")
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(st)
	var how := UI.small_button("Como jogar", AppButton.Variant.SECONDARY, func(): App.push(SenhaHowTo.new()), "book")
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(how)
	_col.add_child(row)


static func stats_screen() -> Screen:
	var sections: Array = []
	for lv in SenhaLogic.LEVEL_ORDER:
		sections.append({"key": "senha_dia_" + lv, "title": "Senha do dia · %s" % SenhaLogic.LEVELS[lv].name, "daily": true, "tries": SenhaLogic.TRIES})
	for lv in SenhaLogic.LEVEL_ORDER:
		sections.append({"key": "senha_treino_" + lv, "title": "Treino · %s" % SenhaLogic.LEVELS[lv].name, "daily": false, "tries": SenhaLogic.TRIES})
	return DesafioStatsScreen.new("Estatísticas do Senha", sections)


func _daily_card() -> Control:
	var today := Desafio.day_index()
	var c := UI.card(Tokens.tint(Tokens.MOSTARDA, 0.3), 22)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label("Senha do dia", 26, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label("Uma por nível, a mesma pra todo mundo. Cada nível tem a sua sequência.", 17, Tokens.TINTA_SUAVE))
	for lv in SenhaLogic.LEVEL_ORDER:
		var key: String = "senha_dia_" + lv
		var g := DesafioStore.today_game(key, today)
		var st := DesafioStore.stats(key, today)
		var n: int = g.get("guesses", []).size()
		var text: String = SenhaLogic.LEVELS[lv].name
		var variant := AppButton.Variant.PRIMARY
		var icon := "play"
		if g.get("finished", false):
			text += " · %s" % ("acertou em %d" % n if g.get("won", false) else "não foi")
			variant = AppButton.Variant.SECONDARY
			icon = "check"
		elif n > 0:
			text += " · continuar (%d/10)" % n
		var row := UI.hbox(12)
		var b := UI.small_button(text, variant, func(): App.push(SenhaSolo.new("dia", lv)), icon)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var streak := UI.label("seq. %d" % st.streak, 16, Tokens.TINTA_SUAVE, Fonts.body_bold())
		streak.custom_minimum_size.x = 70
		streak.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(streak)
		v.add_child(row)
	return c


func _training_card() -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 22)
	var v := UI.vbox(12)
	c.add_child(v)
	v.add_child(UI.label("Treino", 26, Tokens.TINTA, Fonts.title()))
	var lv: String = DesafioStore.pref("senha_nivel", "medio")
	v.add_child(UI.segmented(SenhaLogic.LEVEL_ORDER.map(func(k): return [k, SenhaLogic.LEVELS[k].name]), lv, func(k):
		DesafioStore.set_pref("senha_nivel", k)
		_build()))
	var d: Dictionary = SenhaLogic.LEVELS[lv]
	v.add_child(UI.label("%d pinos, %d símbolos, %s." % [d.pins, d.symbols, "pode repetir" if d.repeat else "sem repetir"], 15, Tokens.TINTA_SUAVE))
	var saved := DesafioStore.load_game("senha_treino_" + lv)
	var going: bool = not saved.is_empty() and not saved.get("finished", false) and not saved.get("guesses", []).is_empty()
	v.add_child(UI.button("Continuar" if going else "Jogar", AppButton.Variant.SUCCESS, func(): App.push(SenhaSolo.new("treino", lv)), "play"))
	return c


func _look_card() -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 22)
	var v := UI.vbox(12)
	c.add_child(v)
	var fb: String = DesafioStore.pref("senha_retorno", "contagem")
	v.add_child(UI.setting_block("Retorno", UI.segmented([["contagem", "Contagem"], ["posicao", "Por posição"]], fb, func(k):
		DesafioStore.set_pref("senha_retorno", k)
		_build()), "Contagem: o clássico, só diz quantos acertou. Por posição: cada pino ganha uma cor, como no Wordle."))
	var look: String = DesafioStore.pref("senha_aparencia", "cores")
	v.add_child(UI.setting_block("Aparência", UI.segmented([["cores", "Cores"], ["numeros", "Números"]], look, func(k):
		DesafioStore.set_pref("senha_aparencia", k)
		_build())))
	return c


func _wifi_card() -> Control:
	var c := UI.card(Tokens.tint(Tokens.AZUL, 0.16), 22)
	var v := UI.vbox(10)
	c.add_child(v)
	v.add_child(UI.label("Duelo e Corrida no Wi-Fi", 26, Tokens.TINTA, Fonts.title()))
	v.add_child(UI.label("Duelo: cada um cria a senha do outro. Corrida: todos tentam a mesma senha. Pelo app ou pelo navegador.", 17, Tokens.TINTA_SUAVE))
	var info := {
		"id": "senha",
		"name": "Senha",
		"host": func(role: String, n: String): return SenhaHost.new(role, n),
		"game": "res://games/senha/screens/senha_net.gd",
	}
	var row := UI.hbox(12)
	var create := UI.small_button("Criar sala", AppButton.Variant.SUCCESS, func(): App.push(PartyCreateRoom.new(info)), "wifi")
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(create)
	var join := UI.small_button("Entrar", AppButton.Variant.ACCENT, func(): App.push(JoinScreen.new()), "enter")
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(join)
	v.add_child(row)
	return c
