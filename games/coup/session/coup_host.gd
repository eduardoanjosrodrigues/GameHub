class_name CoupHost
extends PartyClockHost
## Host do Coup: o host com relógio justo dos jogos de tema (docs/PLANO_COUP.md §5). Desafios e
## bloqueios vão pela janela; vale o que foi apertado primeiro (CoupRules.resolve_timed). O tick das
## regras fecha a janela de 5 s.


func _init(role: String, p_name: String) -> void:
	super("coup", "Coup", CoupRules.new(), role, p_name)
	timed_types = ["challenge", "block"]
