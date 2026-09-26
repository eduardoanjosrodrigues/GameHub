class_name QrCode
extends RefCounted
## Gerador de QR code (modo byte, correção de erro nível L, versões 1 a 5).
## Suficiente pra links curtos como "gamehub://entrar?c=ABC123" (até 106 bytes).
## Baseado na especificação ISO/IEC 18004 (mesma estrutura da implementação de referência do Nayuki).

const DATA_CODEWORDS := [0, 19, 34, 55, 80, 108] # por versão, nível L, bloco único
const EC_CODEWORDS := [0, 7, 10, 15, 20, 26]
const FORMAT_BITS_L := 1

var size := 0
var modules: Array = [] # [linha][coluna] -> bool (true = escuro)
var _function: Array = []


## Retorna null se o texto não couber.
static func encode(text: String) -> QrCode:
	var data := text.to_utf8_buffer()
	var version := 0
	for v in range(1, 6):
		# 4 bits de modo + 8 bits de tamanho + dados
		if 4 + 8 + data.size() * 8 <= DATA_CODEWORDS[v] * 8:
			version = v
			break
	if version == 0:
		return null
	var qr := QrCode.new()
	qr._build(version, data)
	return qr


func is_dark(row: int, col: int) -> bool:
	return modules[row][col]


func _build(version: int, data: PackedByteArray) -> void:
	size = 17 + version * 4
	modules = []
	_function = []
	for y in size:
		var row := []
		row.resize(size)
		row.fill(false)
		modules.append(row)
		var frow := []
		frow.resize(size)
		frow.fill(false)
		_function.append(frow)

	var codewords := _make_codewords(version, data)
	_draw_function_patterns(version)
	_draw_codewords(codewords)

	var best_mask := 0
	var best_penalty := -1
	for m in 8:
		_apply_mask(m)
		_draw_format(m)
		var p := _penalty()
		if best_penalty < 0 or p < best_penalty:
			best_penalty = p
			best_mask = m
		_apply_mask(m) # desfaz (XOR)
	_apply_mask(best_mask)
	_draw_format(best_mask)


# --- Codewords -------------------------------------------------------------

func _make_codewords(version: int, data: PackedByteArray) -> PackedByteArray:
	var bits: Array[int] = []
	_append_bits(bits, 0b0100, 4)
	_append_bits(bits, data.size(), 8)
	for b in data:
		_append_bits(bits, b, 8)
	var capacity: int = DATA_CODEWORDS[version] * 8
	_append_bits(bits, 0, min(4, capacity - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)
	var out := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var v := 0
		for j in 8:
			v = (v << 1) | bits[i + j]
		out.append(v)
	var pad := 0xEC
	while out.size() < DATA_CODEWORDS[version]:
		out.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	var ec := _rs_remainder(out, _rs_divisor(EC_CODEWORDS[version]))
	out.append_array(ec)
	return out


static func _append_bits(bits: Array[int], value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _gf_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		z ^= ((y >> i) & 1) * x
	return z


static func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result.fill(0)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_mul(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	result.fill(0)
	for b in data:
		var factor := b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in divisor.size():
			result[i] ^= _gf_mul(divisor[i], factor)
	return result


# --- Padrões fixos ---------------------------------------------------------

func _set_fn(x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	_function[y][x] = true


func _draw_function_patterns(version: int) -> void:
	for i in size:
		_set_fn(6, i, i % 2 == 0)
		_set_fn(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(size - 4, 3)
	_draw_finder(3, size - 4)
	if version >= 2:
		var p := 4 * version + 10
		_draw_alignment(p, p)
	_draw_format(0) # reserva a área (valor final vem depois)


func _draw_finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				var dist: int = max(abs(dx), abs(dy))
				_set_fn(x, y, dist != 2 and dist != 4)


func _draw_alignment(cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_fn(cx + dx, cy + dy, max(abs(dx), abs(dy)) != 1)


func _draw_format(mask: int) -> void:
	var data := (FORMAT_BITS_L << 3) | mask
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_fn(8, i, _bit(bits, i))
	_set_fn(8, 7, _bit(bits, 6))
	_set_fn(8, 8, _bit(bits, 7))
	_set_fn(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_fn(14 - i, 8, _bit(bits, i))
	for i in range(0, 8):
		_set_fn(size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_fn(8, size - 15 + i, _bit(bits, i))
	_set_fn(8, size - 8, true) # módulo sempre escuro


static func _bit(x: int, i: int) -> bool:
	return ((x >> i) & 1) != 0


# --- Dados e máscara -------------------------------------------------------

func _draw_codewords(data: PackedByteArray) -> void:
	var i := 0
	var total := data.size() * 8
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if not _function[y][x] and i < total:
					modules[y][x] = _bit(data[i >> 3], 7 - (i & 7))
					i += 1
		right -= 2


func _apply_mask(mask: int) -> void:
	for y in size:
		for x in size:
			if _function[y][x]:
				continue
			var inv := false
			match mask:
				0: inv = (x + y) % 2 == 0
				1: inv = y % 2 == 0
				2: inv = x % 3 == 0
				3: inv = (x + y) % 3 == 0
				4: inv = (x / 3 + y / 2) % 2 == 0
				5: inv = x * y % 2 + x * y % 3 == 0
				6: inv = (x * y % 2 + x * y % 3) % 2 == 0
				7: inv = ((x + y) % 2 + x * y % 3) % 2 == 0
			if inv:
				modules[y][x] = not modules[y][x]


func _penalty() -> int:
	var result := 0
	# Regra 1: sequências de 5+ módulos iguais em linha/coluna.
	for horizontal in [true, false]:
		for a in size:
			var run_color := false
			var run := 0
			for b in size:
				var c: bool = modules[a][b] if horizontal else modules[b][a]
				if b == 0 or c != run_color:
					if run >= 5:
						result += 3 + (run - 5)
					run_color = c
					run = 1
				else:
					run += 1
			if run >= 5:
				result += 3 + (run - 5)
	# Regra 2: blocos 2x2 da mesma cor.
	for y in size - 1:
		for x in size - 1:
			var c: bool = modules[y][x]
			if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1]:
				result += 3
	# Regra 3: padrões parecidos com o localizador (1:1:3:1:1 com 4 claros ao lado).
	var p1 := [true, false, true, true, true, false, true, false, false, false, false]
	var p2 := [false, false, false, false, true, false, true, true, true, false, true]
	for horizontal in [true, false]:
		for a in size:
			for b in size - 10:
				var m1 := true
				var m2 := true
				for k in 11:
					var c: bool = modules[a][b + k] if horizontal else modules[b + k][a]
					if c != p1[k]:
						m1 = false
					if c != p2[k]:
						m2 = false
					if not m1 and not m2:
						break
				if m1:
					result += 40
				if m2:
					result += 40
	# Regra 4: proporção de módulos escuros.
	var dark := 0
	for y in size:
		for x in size:
			if modules[y][x]:
				dark += 1
	var total := size * size
	var k := int(abs(dark * 20 - total * 10) + total - 1) / total - 1
	result += max(k, 0) * 10
	return result


## Gera uma imagem (útil pra testes e pra depurar).
func to_image(scale := 8, border := 4) -> Image:
	var n := (size + border * 2) * scale
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in size:
		for x in size:
			if modules[y][x]:
				img.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), Color.BLACK)
	return img
