class_name RoomProbe
extends Node
## Pergunta a uma sala (pelo IP) de qual jogo ela é, antes de entrar de verdade.
## Usado quando a pessoa entra por código, IP ou QR e a descoberta não disse o jogo.

signal found(game: String)
signal failed

var _ip := ""
var _done := false


func _init(ip: String) -> void:
	_ip = ip


func _ready() -> void:
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_failed)
	Net.host_lost.connect(_on_failed)
	Net.message.connect(_on_message)
	if Net.join(_ip) != OK:
		_on_failed()


func _exit_tree() -> void:
	Net.joined.disconnect(_on_joined)
	Net.join_failed.disconnect(_on_failed)
	Net.host_lost.disconnect(_on_failed)
	Net.message.disconnect(_on_message)


func _on_joined() -> void:
	Net.send_to_host({"type": "qual_jogo"})


func _on_message(_peer: int, msg: Dictionary) -> void:
	if _done or msg.get("type", "") != "jogo":
		return
	_done = true
	Net.close()
	found.emit(str(msg.get("jogo", "chapeu")))
	queue_free()


func _on_failed(_reason := "") -> void:
	if _done:
		return
	_done = true
	Net.close()
	failed.emit()
	queue_free()
