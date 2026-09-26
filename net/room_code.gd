class_name RoomCode
extends RefCounted
## Código de sala de 6 caracteres que guarda o IP do host (a porta é sempre a padrão).
##
## 30 bits = tipo de rede (2) + IP compactado (24) + verificação (4).
##   tipo 0: 192.168.A.B      tipo 1: 10.A.B.C      tipo 2: 172.(16+N).A.B
## Alfabeto Crockford (sem I, L, O, U) pra não confundir na hora de digitar.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH := 6


## Retorna "" se o IP não for de rede local conhecida.
static func encode(ip: String) -> String:
	var p := ip.split(".")
	if p.size() != 4:
		return ""
	var o := []
	for s in p:
		if not s.is_valid_int():
			return ""
		o.append(int(s))
	var type := -1
	var payload := 0
	if o[0] == 192 and o[1] == 168:
		type = 0
		payload = (o[2] << 8) | o[3]
	elif o[0] == 10:
		type = 1
		payload = (o[1] << 16) | (o[2] << 8) | o[3]
	elif o[0] == 172 and o[1] >= 16 and o[1] <= 31:
		type = 2
		payload = ((o[1] - 16) << 16) | (o[2] << 8) | o[3]
	if type < 0:
		return ""
	var body := (type << 24) | payload
	var value := (body << 4) | _check(body)
	var out := ""
	for i in LENGTH:
		out = ALPHABET[value & 31] + out
		value >>= 5
	return out


## Retorna o IP, ou "" se o código for inválido.
static func decode(code: String) -> String:
	var c := normalize(code)
	if c.length() != LENGTH:
		return ""
	var value := 0
	for ch in c:
		var i := ALPHABET.find(ch)
		if i < 0:
			return ""
		value = (value << 5) | i
	var check := value & 15
	var body := value >> 4
	if _check(body) != check:
		return ""
	var type := body >> 24
	var payload := body & 0xFFFFFF
	match type:
		0:
			if payload > 0xFFFF:
				return ""
			return "192.168.%d.%d" % [payload >> 8, payload & 255]
		1:
			return "10.%d.%d.%d" % [payload >> 16, (payload >> 8) & 255, payload & 255]
		2:
			if (payload >> 16) > 15:
				return ""
			return "172.%d.%d.%d" % [16 + (payload >> 16), (payload >> 8) & 255, payload & 255]
	return ""


## Aceita minúsculas, espaços e traços; troca O→0 e I/L→1.
static func normalize(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		match ch:
			" ", "-":
				continue
			"O":
				out += "0"
			"I", "L":
				out += "1"
			_:
				out += ch
	return out


## Formata pra exibição: "ABC-123".
static func pretty(code: String) -> String:
	if code.length() != LENGTH:
		return code
	return code.substr(0, 3) + "-" + code.substr(3)


static func _check(body: int) -> int:
	var x := body
	var s := 0
	while x > 0:
		s = (s * 7 + (x & 15)) % 16
		x >>= 4
	return (s + 5) % 16
