extends Node
## Histórico de partidas deste aparelho, salvo em user://history.json.

signal changed

const PATH := "user://history.json"
const MAX_ENTRIES := 100

var entries: Array = []


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		entries = data


func add(entry: Dictionary) -> void:
	entries.push_front(entry)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(entries))
	changed.emit()


func clear() -> void:
	entries.clear()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	changed.emit()
