class_name Fonts
extends RefCounted
## Fontes do app (variáveis, licença OFL):
##   Fraunces — serifada com personalidade, pra títulos e pras palavras do jogo (cara de carta impressa).
##   Manrope  — sem-serifa limpa, pra interface e texto.

const FRAUNCES := "res://design/fonts/Fraunces.ttf"
const MANROPE := "res://design/fonts/Manrope.ttf"

static var _cache := {}


## Títulos grandes.
static func display() -> Font:
	return _variation(FRAUNCES, {"wght": 650, "opsz": 72, "SOFT": 100, "WONK": 0})


## Títulos menores e palavra da vez.
static func title() -> Font:
	return _variation(FRAUNCES, {"wght": 600, "opsz": 36, "SOFT": 100, "WONK": 0})


## Destaques em itálico (ex: logo).

## Botões e rótulos.
static func ui() -> Font:
	return _variation(MANROPE, {"wght": 700})


static func body() -> Font:
	return _variation(MANROPE, {"wght": 500})


static func body_bold() -> Font:
	return _variation(MANROPE, {"wght": 700})


# Compatibilidade com nomes antigos usados nas telas.
static func title_bold() -> Font:
	return display()


static func _variation(path: String, axes: Dictionary, italic := false) -> Font:
	var key := "%s:%s:%s" % [path, str(axes), italic]
	if _cache.has(key):
		return _cache[key]
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	var va := {}
	for axis in axes:
		va[ts.name_to_tag(axis)] = axes[axis]
	fv.variation_opentype = va
	if italic:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2.ZERO)
	_cache[key] = fv
	return fv
