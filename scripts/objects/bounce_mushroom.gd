extends StaticBody2D

const BOUNCE_APPROACH_MAX_Y: float = -22.0
const CAP_LANDING_TOLERANCE_PX: float = 10.0

@export var bounce_velocity: float = -385.0
@export var rearm_cooldown: float = 0.1

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _trigger: Area2D = $BounceTrigger
@onready var _sfx_bounce: AudioStreamPlayer2D = $SFX_Bounce
@onready var platform_collision: CollisionShape2D = $CollisionShape2D

var _platform_collision_original_y: float = 0.0
var _was_in_approach: Dictionary = {}
var _was_on_cap: Dictionary = {}
var _player_bounce_cooldown: Dictionary = {}


func _ready() -> void:
	process_physics_priority = -1
	_platform_collision_original_y = platform_collision.position.y
	_sprite.play(&"idle")
	_trigger.body_exited.connect(_on_bounce_trigger_body_exited)
	_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	_tick_player_bounce_cooldowns(delta)

	var seen_player_ids: Dictionary = {}

	for body in _trigger.get_overlapping_bodies():
		_process_player_body(body, seen_player_ids)

	for player_id in _was_on_cap.keys():
		if seen_player_ids.has(player_id):
			continue
		var player_obj = instance_from_id(player_id)
		if not is_instance_valid(player_obj) or not player_obj is CharacterBody2D:
			continue
		if not player_obj.is_in_group("player"):
			continue
		_process_player(player_obj as CharacterBody2D, seen_player_ids)

	for player_id in _was_in_approach.keys():
		if seen_player_ids.has(player_id):
			continue
		var player_obj = instance_from_id(player_id)
		if not is_instance_valid(player_obj) or not player_obj is CharacterBody2D:
			continue
		if not player_obj.is_in_group("player"):
			continue
		_process_player(player_obj as CharacterBody2D, seen_player_ids)

	_prune_stale_player_state(seen_player_ids)


func _process_player_body(body: Node, seen_player_ids: Dictionary) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_in_group("player"):
		return
	if not body is CharacterBody2D:
		return
	_process_player(body as CharacterBody2D, seen_player_ids)


func _process_player(player: CharacterBody2D, seen_player_ids: Dictionary) -> void:
	var player_id := player.get_instance_id()
	seen_player_ids[player_id] = true

	var in_approach := player.velocity.y > 0.0 and _is_in_approach_zone(player)
	var was_in_approach: bool = _was_in_approach.get(player_id, false)
	var on_cap := _player_is_on_cap(player)
	var was_on_cap: bool = _was_on_cap.get(player_id, false)
	var cooldown: float = _player_bounce_cooldown.get(player_id, 0.0)

	var edge_approach := in_approach and not was_in_approach
	var cap_contact := on_cap and (not was_on_cap or player.velocity.y >= 0.0)
	var edge_bounce := edge_approach and cooldown <= 0.0

	if edge_bounce or cap_contact:
		_bounce_player(player)

	_was_in_approach[player_id] = in_approach
	_was_on_cap[player_id] = on_cap


func _tick_player_bounce_cooldowns(delta: float) -> void:
	for player_id in _player_bounce_cooldown.keys():
		var remaining: float = _player_bounce_cooldown[player_id] - delta
		if remaining <= 0.0:
			_player_bounce_cooldown.erase(player_id)
		else:
			_player_bounce_cooldown[player_id] = remaining


func _on_bounce_trigger_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_prune_player_state(body.get_instance_id())


func _prune_player_state(player_id: int) -> void:
	_was_in_approach.erase(player_id)
	_was_on_cap.erase(player_id)
	_player_bounce_cooldown.erase(player_id)


func _prune_stale_player_state(seen_player_ids: Dictionary) -> void:
	for player_id in _was_in_approach.keys():
		if not seen_player_ids.has(player_id):
			_prune_player_state(player_id)
	for player_id in _was_on_cap.keys():
		if not seen_player_ids.has(player_id):
			_prune_player_state(player_id)


func _is_in_approach_zone(player: CharacterBody2D) -> bool:
	return player.global_position.y < global_position.y + BOUNCE_APPROACH_MAX_Y


func _player_is_on_cap(player: CharacterBody2D) -> bool:
	if player.is_on_floor():
		for i in range(player.get_slide_collision_count()):
			if player.get_slide_collision(i).get_collider() == self:
				return true
	return _player_is_imminent_cap_landing(player)


func _player_is_imminent_cap_landing(player: CharacterBody2D) -> bool:
	if player.velocity.y <= 0.0:
		return false
	if not _player_is_horizontally_on_cap(player):
		return false
	var feet_y := _player_feet_y(player)
	var cap_top := _cap_top_y()
	var travel := player.velocity.y * get_physics_process_delta_time()
	if feet_y + travel < cap_top - CAP_LANDING_TOLERANCE_PX:
		return false
	if feet_y > cap_top + CAP_LANDING_TOLERANCE_PX:
		return false
	return true


func _player_is_horizontally_on_cap(player: CharacterBody2D) -> bool:
	var platform_rect := platform_collision.shape as RectangleShape2D
	if platform_rect == null:
		return false
	var cap_center_x := global_position.x + platform_collision.position.x
	var cap_half_w := platform_rect.size.x * 0.5
	var body_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_center_x := player.global_position.x
	if body_shape:
		player_center_x = player.global_position.x + body_shape.position.x
	var player_half_w := _player_half_width(player)
	var player_left := player_center_x - player_half_w
	var player_right := player_center_x + player_half_w
	var cap_left := cap_center_x - cap_half_w
	var cap_right := cap_center_x + cap_half_w
	return player_left < cap_right and player_right > cap_left


func _player_half_width(player: CharacterBody2D) -> float:
	var body_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape and body_shape.shape is RectangleShape2D:
		return (body_shape.shape as RectangleShape2D).size.x * 0.5
	return 11.0


func _cap_top_y() -> float:
	var half_h := (platform_collision.shape as RectangleShape2D).size.y * 0.5
	return global_position.y + platform_collision.position.y - half_h


func _player_feet_y(player: CharacterBody2D) -> float:
	var body_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape and body_shape.shape is RectangleShape2D:
		var rect := body_shape.shape as RectangleShape2D
		return player.global_position.y + body_shape.position.y + rect.size.y * 0.5
	return player.global_position.y


func _bounce_player(player: CharacterBody2D) -> void:
	if "suppress_next_land_sfx" in player:
		player.suppress_next_land_sfx = true
	_player_bounce_cooldown[player.get_instance_id()] = rearm_cooldown
	platform_collision.position.y = _platform_collision_original_y + 4.0
	if is_instance_valid(_sfx_bounce) and _sfx_bounce.stream:
		_sfx_bounce.play()
	_sprite.play(&"bounce")
	var launch_vy := bounce_velocity
	player.velocity.y = launch_vy
	player.call_deferred("set", "velocity", Vector2(player.velocity.x, launch_vy))
	_apply_trampoline_jump_anim(player)
	call_deferred("_deferred_trampoline_jump_anim", player.get_instance_id())


func _deferred_trampoline_jump_anim(player_id: int) -> void:
	var player_obj = instance_from_id(player_id)
	if not is_instance_valid(player_obj) or not player_obj is CharacterBody2D:
		return
	_apply_trampoline_jump_anim(player_obj as CharacterBody2D)


func _apply_trampoline_jump_anim(player: CharacterBody2D) -> void:
	if not is_instance_valid(player) or not player.is_in_group("player"):
		return
	if player.has_method("reset_for_external_launch"):
		player.reset_for_external_launch()

	_set_player_var(player, &"lock_time", 0.0)
	_set_player_var(player, &"pending_jump", false)
	_set_player_var(player, &"force_fall_anim", false)
	_set_player_var(player, &"double_jump_anim_locked", false)
	_set_player_var(player, &"was_on_floor", true)

	if "State" in player and "state" in player:
		player.set(&"state", player.get("State").AIR)

	if player.has_method("_play"):
		player._play("jump_up", true)


func _set_player_var(player: Object, key: StringName, value: Variant) -> void:
	if key in player:
		player.set(key, value)


func _on_animation_finished() -> void:
	if _sprite.animation != &"bounce":
		return
	platform_collision.position.y = _platform_collision_original_y
	if _trigger.get_overlapping_bodies().is_empty():
		_sprite.play(&"idle")
