class_name GeniusClient
extends PartyClockClient
## Cliente da Corrida do Genius: acerta o relógio com o host pra tocar a sequência junto.


func _init(ip: String, p_name: String) -> void:
	super("genius", ip, p_name, "player")
