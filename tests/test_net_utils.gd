extends TestCase
## Testes do código de sala e do gerador de QR.


func test_room_code_roundtrip() -> void:
	for ip in ["192.168.0.10", "192.168.1.1", "192.168.43.1", "192.168.255.254", "10.0.0.2", "10.123.45.67", "172.16.0.1", "172.31.200.9", "172.20.5.5"]:
		var code := RoomCode.encode(ip)
		eq(code.length(), 6, "código de 6 letras pra " + ip)
		eq(RoomCode.decode(code), ip, "ida e volta " + ip)
		eq(RoomCode.decode(code.to_lower()), ip, "aceita minúsculas " + ip)
		eq(RoomCode.decode(RoomCode.pretty(code)), ip, "aceita traço " + ip)


func test_room_code_rejects() -> void:
	eq(RoomCode.encode("8.8.8.8"), "", "IP público não gera código")
	eq(RoomCode.encode("172.32.0.1"), "", "fora da faixa 172.16-31")
	eq(RoomCode.decode("ABC"), "", "curto demais")
	var code := RoomCode.encode("192.168.0.10")
	# Troca um caractere: a verificação deve pegar a maioria dos erros de digitação.
	var wrong := 0
	for i in 6:
		var ch := code[i]
		var other := "Z" if ch != "Z" else "Y"
		var typo := code.substr(0, i) + other + code.substr(i + 1)
		if RoomCode.decode(typo) == "":
			wrong += 1
	check(wrong >= 5, "verificação pega erros de digitação (%d/6)" % wrong)


func test_room_code_confusable_letters() -> void:
	eq(RoomCode.normalize("o1l-i"), "0111", "O vira 0, I/L viram 1")


func test_deep_link_parse() -> void:
	eq(DeepLink.parse("gamehub://entrar?c=abc123"), "ABC123", "lê o código do link")
	eq(DeepLink.parse("https://example.com/?c=abc"), "", "ignora outros links")
	eq(DeepLink.parse(DeepLink.make("XYZ789")), "XYZ789", "ida e volta")


func test_qr_sizes_and_patterns() -> void:
	var qr := QrCode.encode("gamehub://entrar?c=ABC123")
	check(qr != null, "gera QR")
	eq(qr.size, 25, "cabe na versão 2 (25x25)")
	# Localizadores nos três cantos: canto escuro, anel claro, centro escuro.
	for c in [Vector2i(0, 0), Vector2i(qr.size - 7, 0), Vector2i(0, qr.size - 7)]:
		check(qr.is_dark(c.y, c.x), "canto do localizador escuro")
		check(not qr.is_dark(c.y + 1, c.x + 1), "anel claro do localizador")
		check(qr.is_dark(c.y + 3, c.x + 3), "centro do localizador escuro")
	check(qr.is_dark(qr.size - 8, 8), "módulo escuro obrigatório")
	eq(QrCode.encode("x".repeat(200)), null, "texto grande demais retorna null")


func test_qr_reed_solomon_known_vector() -> void:
	# Exemplo clássico da especificação ("01234567", versão 1-M): 16 dados -> 10 de correção.
	var data := PackedByteArray([0x10, 0x20, 0x0C, 0x56, 0x61, 0x80, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11])
	var ec := QrCode._rs_remainder(data, QrCode._rs_divisor(10))
	eq(Array(ec), [0xA5, 0x24, 0xD4, 0xC1, 0xED, 0x36, 0xC7, 0x87, 0x2C, 0x55], "correção de erro bate com a especificação")
