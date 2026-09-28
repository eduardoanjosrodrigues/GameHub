class_name SenhaClient
extends PartyClockClient
## Cliente do Senha pelo Wi-Fi: o palpite vai com a hora do host (PartyClockClient).


func _init(ip: String, p_name: String, role := "player") -> void:
	super("senha", ip, p_name, role)
	timed_types = ["guess"]
