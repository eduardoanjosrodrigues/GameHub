extends Node
## Configurações do aparelho, salvas em user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.7
var sfx_volume := 0.9
var vibration := true
var last_name := ""
var device_id := ""
## Quando cada jogo foi aberto pela última vez (id -> segundos Unix): ordena a tela inicial.
var last_played := {}

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()
	if device_id == "":
		device_id = _new_id()
		save_settings()


func load_settings() -> void:
	if _cfg.load(PATH) != OK:
		return
	music_volume = float(_cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(_cfg.get_value("audio", "sfx_volume", sfx_volume))
	vibration = bool(_cfg.get_value("feedback", "vibration", vibration))
	last_name = str(_cfg.get_value("player", "last_name", last_name))
	device_id = str(_cfg.get_value("device", "id", device_id))
	var lp = _cfg.get_value("played", "last", {})
	last_played = lp if lp is Dictionary else {}


func save_settings() -> void:
	_cfg.set_value("audio", "music_volume", music_volume)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.set_value("feedback", "vibration", vibration)
	_cfg.set_value("player", "last_name", last_name)
	_cfg.set_value("device", "id", device_id)
	_cfg.set_value("played", "last", last_played)
	_cfg.save(PATH)
	changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	save_settings()


func set_vibration(on: bool) -> void:
	vibration = on
	save_settings()


func remember_name(n: String) -> void:
	n = n.strip_edges()
	if n != "" and n != last_name:
		last_name = n
		save_settings()


func mark_played(game_id: String) -> void:
	last_played[game_id] = int(Time.get_unix_time_from_system())
	save_settings()


## Identificador aleatório do aparelho (não tem relação com dados do aparelho).
static func _new_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(12)
	return bytes.hex_encode()
