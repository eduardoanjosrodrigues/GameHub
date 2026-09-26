class_name Fonts
extends RefCounted
## Fontes do app: Fredoka (títulos e botões) e Nunito (texto), ambas variáveis.

static var _cache := {}


static func title() -> Font:
	return _variation("res://design/fonts/Fredoka.ttf", 600)


static func title_bold() -> Font:
	return _variation("res://design/fonts/Fredoka.ttf", 700)


static func body() -> Font:
	return _variation("res://design/fonts/Nunito.ttf", 500)


static func body_bold() -> Font:
	return _variation("res://design/fonts/Nunito.ttf", 800)


static func _variation(path: String, weight: int) -> Font:
	var key := "%s:%d" % [path, weight]
	if _cache.has(key):
		return _cache[key]
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	_cache[key] = fv
	return fv
