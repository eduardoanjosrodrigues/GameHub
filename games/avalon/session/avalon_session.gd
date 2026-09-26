class_name AvalonSession
extends Node
## Interface comum entre as telas do Avalon e quem roda as regras.
##   AvalonHost:   este aparelho criou a sala (jogador ou tabuleiro).
##   AvalonClient: este aparelho entrou na sala de outro (jogador ou tabuleiro).

signal view_changed(view: Dictionary, events: Array)
signal error(message: String)
## "connected", "reconnecting" ou "lost"
signal connection_changed(state: String)
signal ended(reason: String)
## QR pronto pra passar a vaga de alguém pra outro aparelho (o token vai no link).
signal seat_link(seat: String, token: String)

const GAME_ID := "avalon"

var view := {}
var is_host := false
var local_role := "player" # "player" ou "board"
var local_id := ""
var room_code := ""


func send(_action: Dictionary) -> void:
	pass


## Pede o QR pra passar a vaga de alguém pra outro aparelho (host ou tabuleiro).
func request_seat(_seat: String) -> void:
	pass


func leave() -> void:
	queue_free()


func _emit_view(v: Dictionary, events: Array) -> void:
	view = v
	view_changed.emit(view, events)
