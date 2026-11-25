extends Node
## Modular player afterimage trail. Auto-spawns during grounded full-speed run,
## with a lighter continuation while retained run momentum carries into approved actions.
## Call spawn_afterimage() from elsewhere later if needed; do not put timers in Player.gd.

@export var enabled: bool = true
@export var spawn_interval: float = 0.075
@export var lifetime: float = 0.22
@export var start_opacity: float = 0.45
@export var max_visible: int = 3
@export var speed_threshold_ratio: float = 0.9

@export var continuation_spawn_interval: float = 0.11
@export var continuation_lifetime: float = 0.20
@export var continuation_opacity: float = 0.26
@export var continuation_speed_threshold_ratio: float = 0.50
@export var momentum_grace_duration: float = 0.45

var _player: CharacterBody2D
var _anim: AnimatedSprite2D
var _run_speed: float = 190.0
var _ground_state: int = 0
var _windup_state: int = 1
var _air_state: int = 2
var _landing_state: int = 3
var _attacking_state: int = 4
var _hurt_state: int = 5
var _dead_state: int = 6
var _spawn_accum: float = 0.0
var _momentum_grace_timer: float = 0.0
var _was_full_run_eligible: bool = false
var _active: Array[Sprite2D] = []


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_anim = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_cache_player_constants()
	tree_exiting.connect(_on_tree_exiting)


func _physics_process(delta: float) -> void:
	if not enabled or not _is_setup_valid():
		_reset_continuation_state()
		return

	var player_state: int = int(_player.get("state"))
	if player_state == _hurt_state or player_state == _dead_state:
		_reset_continuation_state()
		return

	var full_eligible: bool = _is_eligible_for_full_run()
	if full_eligible:
		_momentum_grace_timer = momentum_grace_duration
	elif _momentum_grace_timer > 0.0:
		# Pause grace during already-armed jump windup so the air budget covers rise/apex/early fall.
		if player_state != _windup_state:
			_momentum_grace_timer = maxf(0.0, _momentum_grace_timer - delta)

	var continuation_eligible: bool = (not full_eligible) and _is_eligible_for_continuation()

	if full_eligible:
		_spawn_accum += delta
		while _spawn_accum >= spawn_interval:
			_spawn_accum -= spawn_interval
			_spawn_afterimage_with_profile(start_opacity, lifetime)
	elif continuation_eligible:
		if _was_full_run_eligible:
			_spawn_accum = maxf(_spawn_accum, continuation_spawn_interval - 0.04)
		_spawn_accum += delta
		while _spawn_accum >= continuation_spawn_interval:
			_spawn_accum -= continuation_spawn_interval
			_spawn_afterimage_with_profile(continuation_opacity, continuation_lifetime)
	else:
		_spawn_accum = 0.0

	_was_full_run_eligible = full_eligible


func spawn_afterimage() -> void:
	_spawn_afterimage_with_profile(start_opacity, lifetime)


func _spawn_afterimage_with_profile(opacity: float, fade_lifetime: float) -> void:
	if not _is_setup_valid():
		return
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		return
	if not _player.is_inside_tree():
		return
	if max_visible <= 0:
		return

	var frames: SpriteFrames = _anim.sprite_frames
	if frames == null or not frames.has_animation(_anim.animation):
		return

	var tex: Texture2D = frames.get_frame_texture(_anim.animation, _anim.frame)
	if tex == null:
		return

	var world_parent: Node = _player.get_parent()
	if world_parent == null or not is_instance_valid(world_parent):
		return
	if not world_parent.is_inside_tree():
		return

	_prune_invalid_ghosts()
	while _active.size() >= max_visible:
		var oldest: Sprite2D = _active.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.offset = _anim.offset
	ghost.centered = _anim.centered
	ghost.flip_h = _anim.flip_h
	ghost.flip_v = _anim.flip_v
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(1.0, 1.0, 1.0, opacity)
	ghost.z_index = _player.z_index - 1

	world_parent.add_child(ghost)
	ghost.global_transform = _anim.global_transform

	_active.append(ghost)

	var fade_duration: float = maxf(fade_lifetime, 0.001)
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(_cleanup_ghost.bind(ghost))


func _is_eligible_for_full_run() -> bool:
	if not _is_setup_valid():
		return false
	if not _player.is_on_floor():
		return false
	if int(_player.get("state")) != _ground_state:
		return false
	if not bool(_player.get("is_running")):
		return false
	if not bool(_player.get("has_horizontal_input")):
		return false
	if bool(_player.get("is_crouching")):
		return false
	if String(_anim.animation) != "run":
		return false
	if absf(_player.velocity.x) < _run_speed * speed_threshold_ratio:
		return false
	if int(_player.get("hitstop_frames")) > 0:
		return false
	return true


func _is_eligible_for_continuation() -> bool:
	if not _is_setup_valid():
		return false
	if int(_player.get("hitstop_frames")) > 0:
		return false

	var player_state: int = int(_player.get("state"))
	if (
		player_state == _hurt_state
		or player_state == _dead_state
		or player_state == _landing_state
	):
		return false

	if absf(_player.velocity.x) < _run_speed * continuation_speed_threshold_ratio:
		return false

	if float(_player.get("crouch_momentum_timer")) > 0.0:
		return true

	if player_state == _attacking_state and float(_player.get("kick_momentum_timer")) > 0.0:
		return true

	if _momentum_grace_timer > 0.0 and bool(_player.get("is_running")):
		if player_state == _windup_state or player_state == _air_state:
			return true

	return false


func _is_setup_valid() -> bool:
	return (
		is_instance_valid(_player)
		and is_instance_valid(_anim)
		and _player.is_inside_tree()
	)


func _cache_player_constants() -> void:
	_run_speed = 190.0
	_ground_state = 0
	_windup_state = 1
	_air_state = 2
	_landing_state = 3
	_attacking_state = 4
	_hurt_state = 5
	_dead_state = 6
	if _player == null:
		return
	var script: Script = _player.get_script()
	if script == null:
		return
	var constants: Dictionary = script.get_script_constant_map()
	_run_speed = float(constants.get("RUN_SPEED", 190.0))
	var state_values: Variant = constants.get("State", {})
	if typeof(state_values) == TYPE_DICTIONARY:
		var state_dict: Dictionary = state_values
		_ground_state = int(state_dict.get("GROUND", 0))
		_windup_state = int(state_dict.get("WINDUP", 1))
		_air_state = int(state_dict.get("AIR", 2))
		_landing_state = int(state_dict.get("LANDING", 3))
		_attacking_state = int(state_dict.get("ATTACKING", 4))
		_hurt_state = int(state_dict.get("HURT", 5))
		_dead_state = int(state_dict.get("DEAD", 6))


func _reset_continuation_state() -> void:
	_spawn_accum = 0.0
	_momentum_grace_timer = 0.0
	_was_full_run_eligible = false


func _cleanup_ghost(ghost: Sprite2D) -> void:
	var idx: int = _active.find(ghost)
	if idx >= 0:
		_active.remove_at(idx)
	if is_instance_valid(ghost):
		ghost.queue_free()


func _prune_invalid_ghosts() -> void:
	var i: int = _active.size() - 1
	while i >= 0:
		if not is_instance_valid(_active[i]):
			_active.remove_at(i)
		i -= 1


func _on_tree_exiting() -> void:
	_reset_continuation_state()
	var ghosts: Array[Sprite2D] = _active.duplicate()
	_active.clear()
	for ghost in ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
