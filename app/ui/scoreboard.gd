class_name Scoreboard
extends HBoxContainer
## Placar dos dois times lado a lado.

var _labels := {}
var _cards := {}


func _init(scores := {"azul": 0, "vermelho": 0}, big := false, highlight := "") -> void:
	add_theme_constant_override("separation", 16)
	for team in ["azul", "vermelho"]:
		var c := UI.card(Tokens.team_color(team), 16)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(0)
		v.add_child(UI.label(Tokens.team_name(team), 26 if big else 18, Tokens.TINTA, Fonts.title(), HORIZONTAL_ALIGNMENT_CENTER))
		var n := UI.label(str(scores.get(team, 0)), 96 if big else 48, Tokens.TINTA, Fonts.title_bold(), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(n)
		c.add_child(v)
		add_child(c)
		_labels[team] = n
		_cards[team] = c
		if highlight != "" and highlight != team:
			c.modulate = Color(1, 1, 1, 0.55)


func set_scores(scores: Dictionary) -> void:
	for team in _labels:
		var new_text := str(scores.get(team, 0))
		if _labels[team].text != new_text:
			_labels[team].text = new_text
			var tw := create_tween()
			_labels[team].pivot_offset = _labels[team].size / 2.0
			tw.tween_property(_labels[team], "scale", Vector2(1.25, 1.25), 0.08)
			tw.tween_property(_labels[team], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
