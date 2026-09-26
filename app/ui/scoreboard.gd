class_name Scoreboard
extends HBoxContainer
## Placar dos dois times lado a lado: cartões sólidos na cor do time, números serifados.

var _labels := {}


func _init(scores := {"azul": 0, "vermelho": 0}, big := false, highlight := "") -> void:
	add_theme_constant_override("separation", 14)
	for team in ["azul", "vermelho"]:
		var c := PanelContainer.new()
		var st := ThemeBuilder.solid_style(Tokens.team_color(team), 20)
		st.content_margin_top = 14
		st.content_margin_bottom = 12
		c.add_theme_stylebox_override("panel", st)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(0)
		v.add_child(UI.label(Tokens.team_name(team).to_upper(), 20 if big else 14, Tokens.SUPERFICIE, Fonts.ui(), HORIZONTAL_ALIGNMENT_CENTER))
		var n := UI.label(str(scores.get(team, 0)), 104 if big else 52, Tokens.SUPERFICIE, Fonts.display(), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(n)
		c.add_child(v)
		add_child(c)
		_labels[team] = n
		if highlight != "" and highlight != team:
			c.modulate = Color(1, 1, 1, 0.45)


func set_scores(scores: Dictionary) -> void:
	for team in _labels:
		var new_text := str(scores.get(team, 0))
		if _labels[team].text != new_text:
			_labels[team].text = new_text
			var tw := create_tween()
			_labels[team].pivot_offset = _labels[team].size / 2.0
			tw.tween_property(_labels[team], "scale", Vector2(1.18, 1.18), 0.08)
			tw.tween_property(_labels[team], "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
