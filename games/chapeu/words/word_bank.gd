class_name WordBank
extends RefCounted
## Carrega as listas prontas de palavras (JSON nesta pasta).

const FILES := ["famosos", "coisas", "cultura"]

static var _cache := {}


## Retorna {id: {"nome": String, "palavras": Array}}.
static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for id in FILES:
		var path := "res://games/chapeu/words/%s.json" % id
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("Lista de palavras não encontrada: " + path)
			continue
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			_cache[id] = {"nome": data.nome, "palavras": data.palavras}
	return _cache
