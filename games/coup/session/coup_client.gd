class_name CoupClient
extends PartyClockClient
## Cliente do Coup: desafio e bloqueio vão com a hora do host (PartyClockClient).


func _init(ip: String, p_name: String, role := "player") -> void:
	super("coup", ip, p_name, role)
	timed_types = ["challenge", "block"]
