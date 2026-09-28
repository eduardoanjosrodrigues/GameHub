class_name WordleHost
extends PartyClockHost
## Host da Corrida do Wordle: o palpite vai pela janela do relógio justo (PartyClockHost), e quem
## acertou primeiro é decidido pela hora do host (RaceRules.resolve_timed).


func _init(role: String, p_name: String) -> void:
	super("wordle", "Wordle", WordleNetRules.new(), role, p_name)
	timed_types = ["guess"]
