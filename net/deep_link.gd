class_name DeepLink
extends RefCounted
## Link de entrada numa sala, lido pela câmera do celular a partir do QR do host.
## Formato: gamehub://entrar?c=<código da sala>[&v=<token pra assumir a vaga de alguém>]

const PREFIX := "gamehub://entrar"


static func make(code: String, seat_token := "") -> String:
	if seat_token != "":
		return "%s?c=%s&v=%s" % [PREFIX, code, seat_token]
	return "%s?c=%s" % [PREFIX, code]


## Retorna o código da sala, ou "" se o link não for do gamehub.
static func parse(data: String) -> String:
	return _param(data, "c").to_upper()


## Token de troca de aparelho (QR "Trocar aparelho"), ou "".
static func parse_seat(data: String) -> String:
	return _param(data, "v")


static func _param(data: String, key: String) -> String:
	if not data.begins_with(PREFIX):
		return ""
	var q := data.find("?")
	if q < 0:
		return ""
	for part in data.substr(q + 1).split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1].uri_decode()
	return ""
