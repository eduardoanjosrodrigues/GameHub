class_name HalliLocal
extends HalliSession
## Aparelho na mesa: um aparelho só, todo mundo em volta, regras rodando aqui.

var rules: HalliRules


func _init() -> void:
	mode = "table"
	is_host = true
	rules = HalliRules.new("table")
	view = rules.view_for({"role": "table"})


func send(action: Dictionary) -> void:
	var now := now_ms()
	var res: Dictionary
	match action.get("type", ""):
		"bell":
			# No mesmo aparelho não há rede: o toque que o app viu primeiro é o primeiro.
			var t := int(action.get("local_us", now * 1000)) / 1000
			res = rules.ring([{"player": action.get("player", ""), "t": t}], now)
		"flip":
			var a := action.duplicate()
			a.t = now
			res = rules.apply({"id": "", "host": true}, a)
		_:
			res = rules.apply({"id": "", "host": true, "now": now}, action)
	if not res.ok:
		rejected.emit(res.error)
		return
	_emit_view(rules.view_for({"role": "table"}), res.events)
