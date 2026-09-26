class_name DeepLink
extends RefCounted
## Link de entrada numa sala, lido pela câmera do celular a partir do QR do host.
## Formato: gamehub://entrar?c=<código da sala>

const PREFIX := "gamehub://entrar"


static func make(code: String) -> String:
	return "%s?c=%s" % [PREFIX, code]


## Retorna o código da sala, ou "" se o link não for do gamehub.
static func parse(data: String) -> String:
	if not data.begins_with(PREFIX):
		return ""
	var q := data.find("?")
	if q < 0:
		return ""
	for part in data.substr(q + 1).split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == "c":
			return kv[1].uri_decode().to_upper()
	return ""
