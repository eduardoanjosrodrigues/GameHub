class_name HalliResults
extends RefCounted
## Classificação do fim da partida e registro no histórico (Wi-Fi e mesa).


## Jogadores do primeiro ao último: vencedor, quem sobrou, e quem saiu (quem saiu por último vem antes).
static func ranking(v: Dictionary) -> Array:
	var by_id := {}
	for p in v.players:
		by_id[p.id] = p
	var order: Array = [v.winner]
	for p in v.players:
		if not p.out:
			order.append(p.id)
	var gone: Array = v.out_order.duplicate()
	gone.reverse()
	order.append_array(gone)
	var out: Array = []
	var seen := {}
	for id in order:
		if by_id.has(id) and not seen.has(id):
			seen[id] = true
			out.append(by_id[id])
	return out


static func ranking_card(v: Dictionary) -> Control:
	var c := UI.card()
	var cv := UI.vbox(10)
	c.add_child(cv)
	cv.add_child(UI.label("Classificação", 22, Tokens.TINTA, Fonts.title()))
	var list := ranking(v)
	for i in list.size():
		var p: Dictionary = list[i]
		var extra := "%d sino%s certo%s · %d errado%s" % [p.ok, "" if p.ok == 1 else "s", "" if p.ok == 1 else "s", p.wrong, "" if p.wrong == 1 else "s"]
		cv.add_child(UI.player_row("%dº %s" % [i + 1, p.name], HalliArt.player_color(int(p.color)), true, extra))
	return c


static func history_entry(v: Dictionary, mode: String) -> Dictionary:
	var list := ranking(v)
	var win: Dictionary = list[0] if not list.is_empty() and list[0].id == v.winner else {}
	return {
		"date": Time.get_datetime_string_from_system(),
		"game": "halli",
		"game_name": "Halli Galli",
		"mode": mode,
		"winner_name": win.get("name", ""),
		"players": list.map(func(p): return {"name": p.name, "color": p.color, "ok": p.ok, "wrong": p.wrong}),
	}
