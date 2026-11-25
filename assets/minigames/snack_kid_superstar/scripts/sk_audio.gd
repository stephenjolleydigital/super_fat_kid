extends Node
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var muted := false
var last: Dictionary = {}
var music: AudioStreamPlayer
var music_enabled = true
var music_started := false
func _ready() -> void:
	for cue in ["bite","hit","perk","clear","pop","start"]:
		sounds[cue] = load(get_script().resource_path.get_base_dir() + "/../audio/sfx/sk_" + cue + ".wav")
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -15
		add_child(p)
		pool.append(p)
	music=AudioStreamPlayer.new()
	var buffet=load(get_script().resource_path.get_base_dir()+"/../audio/sfx/sk_midnight_buffet.wav")
	if buffet:
		buffet=buffet.duplicate()
		buffet.loop_mode=AudioStreamWAV.LOOP_FORWARD
		if buffet.data.size()>0: buffet.loop_end=buffet.data.size()/2
	music.stream=buffet
	music.volume_db=-20
	add_child(music)
func shutdown() -> void:
	for p in pool:
		if is_instance_valid(p): p.stop()
	if music and is_instance_valid(music): music.stop()
	music_started=false
	set_process(false)
func _process(_dt: float) -> void:
	if music and not music_started and not muted and music_enabled:
		music_started=true
		music.play()
	if music: music.volume_db=-80 if muted or not music_enabled else -20
func play(cue: String) -> void:
	if muted or not sounds.has(cue): return
	var now := Time.get_ticks_msec()
	if now - int(last.get(cue,-1000)) < 65: return
	last[cue] = now
	for p in pool:
		if not p.playing:
			p.stream = sounds[cue]
			p.pitch_scale = randf_range(0.96,1.04) if cue in ["bite","pop"] else 1.0
			p.play()
			return
