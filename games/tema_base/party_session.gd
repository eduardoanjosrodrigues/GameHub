class_name PartySession
extends Node
## Interface comum entre as telas da Sintonia e do Ito e quem roda as regras
## (docs/PLANO_SINTONIA_ITO.md §8).
##   PartyHost:   este aparelho criou a sala (jogador ou tabuleiro).
##   PartyClient: este aparelho entrou na sala de outro (jogador ou tabuleiro).
##   PartyLocal:  um celular só, passando de mão em mão.
## As regras de cada jogo seguem o mesmo contrato: apply(ator, ação), view_for(quem, agora),
## player(id), set_connected(id, bool), phase e players.

signal view_changed(view: Dictionary, events: Array)
signal error(message: String)
## "connected", "reconnecting" ou "lost"
signal connection_changed(state: String)
signal ended(reason: String)
## QR pra passar a vaga de alguém pra outro aparelho (o token vai no link).
signal seat_link(seat: String, token: String)

var game_id := ""
var view := {}
var is_host := false
var local_role := "player" # "player", "board" ou "local"
var local_id := ""
var room_code := ""


func send(_action: Dictionary) -> void:
	pass


## Pede o QR pra passar a vaga de alguém pra outro aparelho (host ou tabuleiro).
func request_seat(_seat: String) -> void:
	pass


## Um celular só: o que a pessoa `id` vê quando pega o celular.
func view_as(_id: String) -> Dictionary:
	return {}


func is_local() -> bool:
	return local_role == "local"


func leave() -> void:
	queue_free()


func _emit_view(v: Dictionary, events: Array) -> void:
	view = v
	view_changed.emit(view, events)
