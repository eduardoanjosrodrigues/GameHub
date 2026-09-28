class_name WordleClient
extends PartyClockClient
## Cliente da Corrida do Wordle: o palpite vai com a hora do host (PartyClockClient).


func _init(ip: String, p_name: String, role := "player") -> void:
	super("wordle", ip, p_name, role)
	timed_types = ["guess"]
