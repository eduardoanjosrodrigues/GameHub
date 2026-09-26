extends Screen
## Detalhe de uma partida do histórico: times, jogadores e pontos por rodada.

const ROUND_NAMES := ["Descrever", "Uma palavra", "Mímica"]

var entry: Dictionary


func _init(p_entry: Dictionary) -> void:
	super()
	entry = p_entry


func _ready() -> void:
	var col := make_column()
	make_header(col, "Partida")
	col.add_child(UI.caption("%s · %s" % [entry.get("date", "").replace("T", " ").left(16), "Passa-e-joga" if entry.get("mode", "") == "local" else "Wi-Fi"]))
	var winner: String = entry.get("winner", "")
	var headline := "Empate!" if winner == "" else "Venceu o %s!" % Tokens.team_name(winner)
	col.add_child(UI.title(headline, 36))
	col.add_child(Scoreboard.new(entry.get("totals", {}), false, winner))

	var table := UI.card()
	var tv := UI.vbox(12)
	table.add_child(tv)
	tv.add_child(UI.label("Pontos por rodada", 22, Tokens.TINTA, Fonts.title()))
	var scores: Array = entry.get("scores", [])
	for i in scores.size():
		var row := UI.hbox(10)
		var name := UI.label(ROUND_NAMES[i] if i < ROUND_NAMES.size() else "Rodada %d" % (i + 1), 19, Tokens.TINTA, Fonts.body_bold())
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		for t in 2:
			var l := UI.label(str(scores[i][t]), 22, Tokens.team_color(["azul", "vermelho"][t]).darkened(0.25), Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
			l.custom_minimum_size.x = 64
			row.add_child(l)
		tv.add_child(row)
	col.add_child(table)

	for team in ["azul", "vermelho"]:
		var c := UI.card()
		var v := UI.vbox(10)
		c.add_child(v)
		v.add_child(UI.label(Tokens.team_name(team), 22, Tokens.TINTA, Fonts.title()))
		for p in entry.get("players", []):
			if p.get("team", "") == team:
				v.add_child(UI.player_row(p.get("name", ""), Tokens.team_color(team)))
		col.add_child(c)
