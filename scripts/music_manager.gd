extends Node

const DEFAULT_VOLUME_DB := -16.0
const SETTINGS_PATH := "user://audio_settings.cfg"
const SETTINGS_SECTION := "audio"

var current_music_path: String = ""

## 0.0–1.0 linear volume for Master bus (SFX + everything on Master).
var master_volume: float = 1.0
## 0.0–1.0 linear multiplier applied on top of DEFAULT_VOLUME_DB for BGM.
var music_volume: float = 1.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	load_settings()
	apply_volumes()


func play_music(requested_music_path: String) -> void:
	if requested_music_path.is_empty():
		return
	if current_music_path == requested_music_path and _player.playing:
		return

	if not ResourceLoader.exists(requested_music_path):
		push_warning("Music file not found: %s" % requested_music_path)
		return

	var music_stream := load(requested_music_path) as AudioStream
	if music_stream == null:
		push_warning("Music file could not be loaded: %s" % requested_music_path)
		return

	_enable_looping(music_stream)
	_player.stream = music_stream
	current_music_path = requested_music_path
	_apply_music_volume()
	_player.play()


func is_music_paused() -> bool:
	return _player.stream_paused


func set_music_paused(value: bool) -> void:
	_player.stream_paused = value


func stop_music() -> void:
	current_music_path = ""
	_player.stop()


func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	_apply_master_volume()
	save_settings()


func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_apply_music_volume()
	save_settings()


func apply_volumes() -> void:
	_apply_master_volume()
	_apply_music_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "master_volume", master_volume)
	cfg.set_value(SETTINGS_SECTION, "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, "master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, "music_volume", 1.0)), 0.0, 1.0)


func _apply_master_volume() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	if master_volume <= 0.0001:
		AudioServer.set_bus_volume_db(master_idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))


func _apply_music_volume() -> void:
	if _player == null:
		return
	if music_volume <= 0.0001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = DEFAULT_VOLUME_DB + linear_to_db(music_volume)


func _enable_looping(music_stream: AudioStream) -> void:
	for property in music_stream.get_property_list():
		if property["name"] == "loop":
			music_stream.set("loop", true)
			return
