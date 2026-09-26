class_name PartyLocal
extends PartySession
## Um celular só (docs/PLANO_SINTONIA_ITO.md §5): as regras rodam aqui e o aparelho age por
## qualquer um. A ação pode dizer por quem é ("as": id); o que é secreto só aparece em view_as(id),
## na tela de passar o celular.

var rules


func _init(p_game_id: String, p_rules) -> void:
	game_id = p_game_id
	rules = p_rules
	rules.local_mode = true
	is_host = true
	local_role = "local"
	view = rules.view_for({"id": "", "role": "local"}, Time.get_ticks_msec())


func send(action: Dictionary) -> void:
	var actor := {"id": str(action.get("as", "")), "host": true, "board": false, "local": true, "now": Time.get_ticks_msec()}
	var res: Dictionary = rules.apply(actor, action)
	if not res.ok:
		error.emit(res.error)
		return
	_emit_view(rules.view_for({"id": "", "role": "local"}, Time.get_ticks_msec()), res.events)


func view_as(id: String) -> Dictionary:
	return rules.view_for({"id": id, "role": "player"}, Time.get_ticks_msec())
