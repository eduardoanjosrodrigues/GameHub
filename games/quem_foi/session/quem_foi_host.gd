class_name QuemFoiHost
extends PartyClockHost
## Host do Quem Foi?: o host com relógio justo dos jogos de tema (docs/PLANO_QUEM_FOI.md §5). O toque
## na corrida vai pela janela; as regras decidem pelo horário do toque (QuemFoiRules.resolve_timed).


func _init(role: String, p_name: String) -> void:
	super("quem_foi", "Quem Foi?", QuemFoiRules.new(), role, p_name)
	timed_types = ["tap"]
