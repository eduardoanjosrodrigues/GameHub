class_name SenhaHost
extends PartyClockHost
## Host do Senha pelo Wi-Fi (Corrida e Duelo): o palpite vai pela janela do relógio justo.


func _init(role: String, p_name: String) -> void:
	super("senha", "Senha", SenhaNetRules.new(), role, p_name)
	timed_types = ["guess"]
