class_name QuemFoiClient
extends PartyClockClient
## Cliente do Quem Foi?: o toque na corrida vai com a hora do host (PartyClockClient).


func _init(ip: String, p_name: String, role := "player") -> void:
	super("quem_foi", ip, p_name, role)
	timed_types = ["tap"]
