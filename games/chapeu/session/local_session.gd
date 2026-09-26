class_name LocalSession
extends ChapeuSession
## Passa-e-joga: um aparelho só, regras rodando aqui.

const ACTOR := {"id": "", "host": true}

var rules: ChapeuRules
var _last_tick := 0


func _init() -> void:
	mode = "local"
	is_host = true
	local_role = "local"
	rules = ChapeuRules.new("local", WordBank.load_all())
	view = rules.view_for({"role": "local"})


func send(action: Dictionary) -> void:
	var res := rules.apply(ACTOR, action)
	if not res.ok:
		error.emit(res.error)
		return
	_emit_view(rules.view_for({"role": "local"}), res.events)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := now - _last_tick if _last_tick > 0 else 0
	_last_tick = now
	if rules.phase != ChapeuRules.PHASE_TURN or rules.paused:
		return
	var events := rules.tick(dt)
	if events.is_empty():
		time_changed.emit(rules.time_ms)
	else:
		_emit_view(rules.view_for({"role": "local"}), events)
