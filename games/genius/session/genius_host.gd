class_name GeniusHost
extends PartyClockHost
## Host da Corrida do Genius (docs/PLANO_GENIUS.md §6): o host com relógio dos jogos de tema. O
## relógio serve pra sequência tocar na mesma hora em todo aparelho; o tick passa as rodadas.


func _init(p_name: String) -> void:
	super("genius", "Genius", GeniusRules.new(), "player", p_name)
