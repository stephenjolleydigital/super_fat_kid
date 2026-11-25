extends CanvasLayer
## One overlay survives scene replacement. Gameplay is paused only during the wipe.
signal transition_failed
signal reveal_completed(scene: Node, is_restart: bool)

enum Effect { FADE, STAR, CIRCLE }
enum SessionAction { KEEP, NEW_GAME, CONTINUE }
const CLOSE_TIMES := [0.25, 0.40, 0.25]
const OPEN_TIMES := [0.30, 0.45, 0.30]
const COVERED_HOLD := 0.05
const WIPE_SFX_VOLUME_DB := -18.0
const MASK := preload("res://scripts/ui/transition_mask.gdshader")
const SFX_CLOSE := preload("res://assets/audio/sfx/ui/sfx_ui_transition_close_01.wav")
const SFX_OPEN := preload("res://assets/audio/sfx/ui/sfx_ui_transition_open_01.wav")
var busy: bool = false
var _cover: ColorRect
var _material: ShaderMaterial
var _sfx_close: AudioStreamPlayer
var _sfx_open: AudioStreamPlayer
var _previous_pause: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = MASK
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.material = _material
	add_child(_cover)
	_cover.hide()
	_sfx_close = _create_sfx_player("SfxTransitionClose", SFX_CLOSE)
	_sfx_open = _create_sfx_player("SfxTransitionOpen", SFX_OPEN)
	# Deferred until the initial scene exists, before its first rendered frame.
	call_deferred("_initial_reveal")

func _create_sfx_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = &"Master"
	player.volume_db = WIPE_SFX_VOLUME_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player

func _play_wipe_sfx(player: AudioStreamPlayer, effect: Effect) -> void:
	if effect == Effect.STAR or effect == Effect.CIRCLE:
		player.play()

func _initial_reveal() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path.begins_with("res://scenes/levels/"):
		reveal_entry()

func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()

func _begin(effect: Effect, coverage: float) -> void:
	_previous_pause = get_tree().paused
	busy = true
	get_tree().paused = true
	_material.set_shader_parameter("star", effect == Effect.STAR)
	_material.set_shader_parameter("circle", effect == Effect.CIRCLE)
	if effect == Effect.CIRCLE:
		_update_circle_center()
	_set_coverage(coverage)
	_cover.show()

func _update_circle_center() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as Node2D if scene else null
	if player:
		var camera := get_viewport().get_camera_2d()
		if camera:
			camera.force_update_scroll()
		var sprite := player.get_node_or_null("AnimatedSprite2D") as Node2D
		var target: Node2D = sprite if sprite else player
		center = target.get_global_transform_with_canvas().origin.round()
	# Keep offscreen deaths anchored to the nearest visible edge.
	center = center.clamp(Vector2.ZERO, viewport_size)
	_material.set_shader_parameter("circle_center", center / viewport_size)

func _set_coverage(value: float) -> void:
	_material.set_shader_parameter("coverage", value)

func _animate(from: float, to: float, duration: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_coverage, from, to, duration)
	await tween.finished

func _finish(recover: bool = false, is_restart: bool = false) -> void:
	_cover.hide()
	busy = false
	get_tree().paused = _previous_pause if recover else false
	if recover:
		transition_failed.emit()
	else:
		reveal_completed.emit(get_tree().current_scene, is_restart)

func reveal_entry() -> void:
	if busy:
		return
	_begin(Effect.STAR, 1.0)
	_play_wipe_sfx(_sfx_open, Effect.STAR)
	await _animate(1.0, 0.0, OPEN_TIMES[Effect.STAR])
	_finish()

func restart_current_level() -> bool:
	var scene := get_tree().current_scene
	return change_scene(scene.scene_file_path if scene else "", Effect.CIRCLE, true)

func change_scene(path: String, effect: Effect = Effect.STAR, is_restart: bool = false, session_action: SessionAction = SessionAction.KEEP) -> bool:
	if busy:
		return false
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		push_error("Transition destination is missing: " + path)
		return false
	# Begin loading without stalling the closing animation. Keep the screen
	# covered if loading takes longer than the wipe.
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		push_error("Transition destination cannot be requested: " + path)
		return false
	_begin(effect, 0.0)
	_run_change(path, effect, is_restart, session_action)
	return true

func _run_change(path: String, effect: Effect, is_restart: bool, session_action: SessionAction) -> void:
	_play_wipe_sfx(_sfx_close, effect)
	await _animate(0.0, 1.0, CLOSE_TIMES[effect])
	# Ensure an opaque frame is submitted before the old scene is removed.
	await get_tree().process_frame
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed: PackedScene
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null or not packed.can_instantiate():
		push_error("Transition destination cannot be loaded: " + path)
		_play_wipe_sfx(_sfx_open, effect)
		await _animate(1.0, 0.0, OPEN_TIMES[effect])
		_finish(true)
		return
	var previous_session := GameState.capture_session()
	if session_action == SessionAction.NEW_GAME:
		GameState.reset_playthrough()
	elif session_action == SessionAction.CONTINUE:
		GameState.set_lives(GameState.STARTING_LIVES)
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		GameState.restore_session(previous_session)
		push_error("Scene transition failed: %s" % error_string(error))
		_play_wipe_sfx(_sfx_open, effect)
		await _animate(1.0, 0.0, OPEN_TIMES[effect])
		_finish(true)
		return
	while get_tree().current_scene == null:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(COVERED_HOLD, true).timeout
	# Recenter while fully covered, after the new player's camera is ready.
	if effect == Effect.CIRCLE:
		_update_circle_center()
	_play_wipe_sfx(_sfx_open, effect)
	await _animate(1.0, 0.0, OPEN_TIMES[effect])
	_finish(false, is_restart)
