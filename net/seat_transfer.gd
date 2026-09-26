class_name SeatTransfer
extends RefCounted
## Passar a vaga de um jogador para outro aparelho no meio da partida (bateria acabou, celular
## travou). O host ou o tabuleiro abre um QR que só serve pra vaga daquela pessoa; o aparelho que
## ler entra como ela, com o mesmo papel e o mesmo estado. O aparelho antigo perde a vaga.
##
## Cada jogo continua usando o id do jogador ("vaga") como antes; aqui fica só a tradução
## aparelho -> vaga e os QRs abertos. Usado pelos hosts do Chapéu, Halli Galli e Avalon.

const TTL_MS := 5 * 60 * 1000

var _alias := {} # aparelho -> vaga (aparelhos que assumiram a vaga de outro)
var _revoked := {} # aparelho -> vaga que ele perdeu
var _tokens := {} # token -> {seat, until, by}


## Abre um QR pra vaga. Retorna o token (vai no link).
func issue(seat: String, now: int) -> String:
	for t in _tokens.keys():
		if _tokens[t].seat == seat and _tokens[t].by == "":
			_tokens.erase(t)
	var token := _random_token()
	_tokens[token] = {"seat": seat, "until": now + TTL_MS, "by": ""}
	return token


## De que vaga é este aparelho ("" se ele perdeu a vaga).
func seat_of(device: String) -> String:
	if _revoked.has(device):
		return ""
	return _alias.get(device, device)


## Chamado no "hello". has_player(vaga) diz se a vaga existe na partida.
## Retorna {seat, taken} ou {erro, mensagem}. taken: este aparelho acabou de assumir a vaga.
func on_hello(device: String, token: String, has_player: Callable, now: int) -> Dictionary:
	if token == "":
		if _revoked.has(device):
			return {"erro": "vaga_passada", "mensagem": "Seu lugar na partida foi passado para outro aparelho."}
		return {"seat": seat_of(device), "taken": false}
	var t: Dictionary = _tokens.get(token, {})
	if t.is_empty() or not has_player.call(t.seat):
		return {"erro": "vaga_invalida", "mensagem": "Esse QR não vale mais. Peça pra abrirem de novo."}
	if t.by == device and seat_of(device) == t.seat:
		return {"seat": t.seat, "taken": false} # o mesmo aparelho reconectando pelo mesmo link
	if t.by != "" or now > int(t.until):
		return {"erro": "vaga_invalida", "mensagem": "Esse QR já foi usado ou venceu. Peça pra abrirem de novo."}
	var current := seat_of(device)
	if current != "" and current != t.seat and has_player.call(current):
		return {"erro": "vaga_invalida", "mensagem": "Este aparelho já está na partida como outra pessoa. Leia o QR em outro aparelho."}
	_assign(device, t.seat)
	t.by = device
	return {"seat": t.seat, "taken": true}


func _assign(device: String, seat: String) -> void:
	# Todo aparelho que era desta vaga perde ela (inclusive o original, cujo id é a própria vaga).
	for d in _alias.keys():
		if _alias[d] == seat and d != device:
			_alias.erase(d)
			_revoked[d] = seat
	if device != seat:
		_revoked[seat] = seat
		_alias[device] = seat
	_revoked.erase(device)


static func _random_token() -> String:
	var chars := "abcdefghjkmnpqrstuvwxyz23456789"
	var out := ""
	for i in 10:
		out += chars[randi() % chars.length()]
	return out
