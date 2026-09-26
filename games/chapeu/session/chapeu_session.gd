class_name ChapeuSession
extends Node
## Interface comum entre a tela do jogo e quem roda as regras.
##   LocalSession: passa-e-joga, regras neste aparelho.
##   HostSession:  Wi-Fi, este aparelho é o host (jogador ou tabuleiro).
##   ClientSession: Wi-Fi, este aparelho entrou na sala de outro.

## Estado novo + eventos (sons, animações).
signal view_changed(view: Dictionary, events: Array)
## Atualização só do cronômetro.
signal time_changed(ms: int)
signal error(message: String)
## "connected", "reconnecting" ou "lost"
signal connection_changed(state: String)
## A sessão acabou (ex: host sumiu de vez, partida em andamento).
signal ended(reason: String)

var view := {}
var is_host := false
var local_role := "local" # "local", "player" ou "board"
var local_id := ""
var room_code := ""
var mode := "local"


func send(_action: Dictionary) -> void:
	pass


func leave() -> void:
	queue_free()


func _emit_view(v: Dictionary, events: Array) -> void:
	view = v
	view_changed.emit(view, events)
