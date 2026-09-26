extends Screen
## Histórico das partidas jogadas neste aparelho.

const HistoryDetail := preload("res://app/screens/history_detail.gd")

var _col: VBoxContainer


func _ready() -> void:
	_col = make_column()
	_build()


func _build() -> void:
	UI.clear(_col)
	make_header(_col, "Histórico")
	if History.entries.is_empty():
		var c := UI.card()
		var v := UI.vbox(12)
		c.add_child(v)
		var ic := UI.texture("history", 72, Tokens.TINTA_SUAVE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(UI.subtitle("Nenhuma partida ainda"))
		v.add_child(UI.caption("As partidas jogadas neste aparelho aparecem aqui."))
		_col.add_child(c)
		return
	for e in History.entries:
		_col.add_child(_entry_card(e))
	_col.add_child(UI.spacer(8))
	_col.add_child(UI.small_button("Apagar histórico", AppButton.Variant.SECONDARY, func():
		App.confirm("Apagar histórico?", "Todas as partidas salvas neste aparelho serão apagadas.", "Apagar", func():
			History.clear()
			_build()), "trash"))


func _mode_name(e: Dictionary) -> String:
	match e.get("mode", ""):
		"local":
			return "Passa-e-joga"
		"table":
			return "Na mesa"
	return "Wi-Fi"


func _entry_card(e: Dictionary) -> Control:
	if e.get("game", "") == "halli":
		return _halli_card(e)
	if e.get("game", "") == "avalon":
		return _avalon_card(e)
	if e.get("game", "") == "secret_hitler":
		return _sh_card(e)
	if e.has("summary"):
		return _summary_card(e)
	var winner: String = e.get("winner", "")
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var v := UI.vbox(8)
	c.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label("%s · %s" % [e.get("game_name", "Chapéu"), _mode_name(e)], 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var date := UI.label(_format_date(e.get("date", "")), 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(date)
	v.add_child(head)
	var totals: Dictionary = e.get("totals", {})
	var line := UI.hbox(10)
	for team in ["azul", "vermelho"]:
		var chip := UI.card(Tokens.team_color(team), 12)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_child(UI.label("%s  %d" % [Tokens.team_name(team), int(totals.get(team, 0))], 18, Tokens.TINTA, Fonts.body_bold(), HORIZONTAL_ALIGNMENT_CENTER))
		if winner != "" and winner != team:
			chip.modulate = Color(1, 1, 1, 0.5)
		line.add_child(chip)
	v.add_child(line)
	var result_text := "Empate!" if winner == "" else "Venceu o %s" % Tokens.team_name(winner)
	v.add_child(UI.label(result_text, 17, Tokens.TINTA_SUAVE, Fonts.body_bold()))
	var open := UI.small_button("Ver detalhes", AppButton.Variant.SECONDARY, func(): App.push(HistoryDetail.new(e)))
	v.add_child(open)
	return c


## Sintonia e Ito: o resumo da partida e quem jogou.
func _summary_card(e: Dictionary) -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var v := UI.vbox(8)
	c.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label("%s · %s" % [e.get("game_name", ""), _mode_name(e)], 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var date := UI.label(_format_date(e.get("date", "")), 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(date)
	v.add_child(head)
	v.add_child(UI.label(e.get("summary", ""), 18, Tokens.TINTA, Fonts.body_bold()))
	var names: Array = e.get("players", []).map(func(p): return p.get("name", ""))
	v.add_child(UI.label(", ".join(names), 15, Tokens.TINTA_SUAVE))
	return c


## Halli Galli: vencedor e quantos jogaram.
func _halli_card(e: Dictionary) -> Control:
	var c := UI.card(Tokens.SUPERFICIE, 20)
	var v := UI.vbox(8)
	c.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label("Halli Galli · %s" % _mode_name(e), 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var date := UI.label(_format_date(e.get("date", "")), 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(date)
	v.add_child(head)
	var players: Array = e.get("players", [])
	var win: String = e.get("winner_name", "")
	v.add_child(UI.label("Venceu %s" % win if win != "" else "Sem vencedor", 18, Tokens.TINTA, Fonts.body_bold()))
	v.add_child(UI.label("%d jogadores" % players.size(), 16, Tokens.TINTA_SUAVE))
	v.add_child(UI.small_button("Ver detalhes", AppButton.Variant.SECONDARY, func(): App.push(HistoryDetail.new(e))))
	return c


## Avalon: qual lado venceu e como.
func _avalon_card(e: Dictionary) -> Control:
	var good: bool = e.get("winner_side", "") == "bem"
	var c := UI.card(AvalonArt.side_color(good), 20)
	var v := UI.vbox(8)
	c.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label("Avalon · Wi-Fi", 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var date := UI.label(_format_date(e.get("date", "")), 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(date)
	v.add_child(head)
	v.add_child(UI.label("O %s venceu" % ("bem" if good else "mal"), 18, Tokens.TINTA, Fonts.body_bold()))
	v.add_child(UI.label(AvalonArt.REASONS.get(e.get("reason", ""), ""), 16, Tokens.TINTA_SUAVE))
	v.add_child(UI.label(", ".join(e.get("players", []).map(func(p): return "%s (%s)" % [p.get("name", ""), AvalonArt.role_name(p.get("role", ""))])), 15, Tokens.TINTA_SUAVE))
	return c


func _sh_card(e: Dictionary) -> Control:
	var lib: bool = e.get("winner_side", "") == "liberal"
	var c := UI.card(Tokens.tint(ShArt.party_color(lib), 0.45), 20)
	var v := UI.vbox(8)
	c.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label("Secret Hitler · Wi-Fi", 20, Tokens.TINTA, Fonts.title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var date := UI.label(_format_date(e.get("date", "")), 15, Tokens.TINTA_SUAVE, Fonts.body_bold())
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(date)
	v.add_child(head)
	v.add_child(UI.label("Os %s venceram" % ("liberais" if lib else "fascistas"), 18, Tokens.TINTA, Fonts.body_bold()))
	v.add_child(UI.label(ShArt.REASONS.get(e.get("reason", ""), ""), 16, Tokens.TINTA_SUAVE))
	v.add_child(UI.label(", ".join(e.get("players", []).map(func(p): return "%s (%s)" % [p.get("name", ""), ShArt.role_name(p.get("role", ""))])), 15, Tokens.TINTA_SUAVE))
	return c


static func _format_date(iso: String) -> String:
	# "2026-09-25T21:40:00" -> "25/09 21:40"
	if iso.length() < 16:
		return iso
	return "%s/%s %s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(11, 5)]
