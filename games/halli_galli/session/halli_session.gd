class_name HalliSession
extends Node
## Interface comum entre as telas do Halli Galli e quem roda as regras.
##   HalliLocal:  aparelho na mesa, regras neste aparelho.
##   HalliHost:   Wi-Fi, este aparelho criou a sala (e joga).
##   HalliClient: Wi-Fi, este aparelho entrou na sala de outro.
##
## Ações da tela: {"type": "flip"} e {"type": "bell", "local_us": Time.get_ticks_usec() do toque}
## (mais "player" no modo mesa). A sessão carimba o horário no relógio do host.

signal view_changed(view: Dictionary, events: Array)
signal error(message: String)
## Uma ação deste aparelho foi recusada pelas regras (ex: virou fora do tempo). O estado certo vem junto.
signal rejected(message: String)
## "connected", "reconnecting" ou "lost"
signal connection_changed(state: String)
## A sessão acabou (ex: host sumiu de vez, partida em andamento).
signal ended(reason: String)
## QR pronto pra passar a vaga de alguém pra outro aparelho (o token vai no link).
signal seat_link(seat: String, token: String)

const GAME_ID := "halli"

var view := {}
var is_host := false
var local_id := ""
var room_code := ""
var mode := "table"


func send(_action: Dictionary) -> void:
	pass


## Agora, no relógio do host (ms).
func now_ms() -> int:
	return Time.get_ticks_usec() / 1000


## Sinal fraco com o host (só faz sentido no cliente).
func weak_signal() -> bool:
	return false


## Pede o QR pra passar a vaga de alguém pra outro aparelho (host ou tabuleiro).
func request_seat(_seat: String) -> void:
	pass


func leave() -> void:
	queue_free()


func _emit_view(v: Dictionary, events: Array) -> void:
	view = v
	view_changed.emit(view, events)
