class_name GeniusStore
extends RefCounted
## O recorde do solo (docs/PLANO_GENIUS.md §3), em user://genius.cfg.

const PATH := "user://genius.cfg"

## false no tour de capturas: nada é gravado.
static var persist := true


static func best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value("solo", "best", 0))


## Guarda se for recorde. Retorna true quando é um recorde novo.
static func submit(score: int) -> bool:
	if score <= best() or not persist:
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("solo", "best", score)
	cfg.save(PATH)
	return true
