extends Node
## Música com crossfade e efeitos sonoros com pool de players.

const SFX_DIRS := ["res://app/audio/sfx/", "res://games/chapeu/audio/", "res://games/halli_galli/audio/", "res://games/quem_foi/audio/"]
const MUSIC := {
	"menu": "res://app/audio/music/menu.wav",
	"turn": "res://games/chapeu/audio/turn.wav",
}
const POOL_SIZE := 8

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _music_rate := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music_a = _new_music_player()
	_music_b = _new_music_player()
	Settings.changed.connect(_apply_volumes)


func _new_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.finished.connect(func(): if p.volume_linear > 0.001: p.play())
	add_child(p)
	return p


func _sfx_stream(name: String) -> AudioStream:
	if not _sfx.has(name):
		_sfx[name] = null
		for dir in SFX_DIRS:
			var path: String = dir + name + ".wav"
			if ResourceLoader.exists(path):
				_sfx[name] = load(path)
				break
	return _sfx[name]


func sfx(name: String, pitch := 1.0) -> void:
	if Settings.sfx_volume <= 0.001:
		return
	var stream := _sfx_stream(name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_linear = Settings.sfx_volume
			p.play()
			return


## Troca a trilha: "menu", "turn" ou "" (silêncio). Crossfade de 0,6 s.
func music(key: String) -> void:
	if key == _current_music:
		return
	_current_music = key
	var old := _music_a
	var fresh := _music_b
	_music_a = fresh
	_music_b = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_linear", 0.0, 0.6)
		tw.tween_callback(old.stop)
	if key != "" and MUSIC.has(key) and ResourceLoader.exists(MUSIC[key]):
		fresh.stream = load(MUSIC[key])
		fresh.pitch_scale = 1.0
		fresh.volume_linear = 0.0
		fresh.play()
		var tw2 := create_tween()
		tw2.tween_property(fresh, "volume_linear", _music_target(), 0.6)


## Acelera a música (usado nos últimos 10 s da vez).
func set_music_rate(rate: float) -> void:
	if is_equal_approx(rate, _music_rate):
		return
	_music_rate = rate
	_music_a.pitch_scale = rate


func _music_target() -> float:
	return Settings.music_volume * 0.55


func _apply_volumes() -> void:
	if _music_a.playing:
		_music_a.volume_linear = _music_target()
