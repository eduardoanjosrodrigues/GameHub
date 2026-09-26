class_name ThemeBank
extends RefCounted
## Temas da Sintonia e do Ito (docs/PLANO_SINTONIA_ITO.md §7): um por linha num arquivo de texto.
## Linhas vazias e que começam com # são ignoradas. Sorteia sem repetir até a lista acabar.

var _all: Array = []
var _deck: Array = []


static func load_file(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Não achei os temas em %s" % path)
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		out.append(line)
	return out


func _init(items: Array) -> void:
	_all = items.duplicate()


func size() -> int:
	return _all.size()


## Próximo tema; quando a lista acaba, embaralha tudo de novo.
func draw(rng: RandomNumberGenerator) -> String:
	if _all.is_empty():
		return ""
	if _deck.is_empty():
		_deck = _all.duplicate()
		for i in range(_deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = _deck[i]
			_deck[i] = _deck[j]
			_deck[j] = tmp
	return _deck.pop_back()
