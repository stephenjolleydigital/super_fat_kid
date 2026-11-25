extends CharacterBody2D

enum State { HANGING, WOBBLING, FALLING, LANDED_STILL, KICKED, COLLECTING }

@export var gravity: float = 800.0
@export var kick_speed: float = 180.0
@export var kick_arc_y: float = -60.0
@export var settle_speed_threshold: float = 8.0
@export var heal_amount: int = 1
@export var player_bounce_y: float = -120.0
@export var player_bounce_x: float = 60.0
@export var player_hit_cooldown: float = 0.4
@export var player_collision_ignore_time: float = 0.35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_col: CollisionShape2D = $CollisionShape2D
@onready var player_detect: Area2D = $PlayerDetectArea
@onready var kick_detect: Area2D = $KickDetectArea
@onready var damage_area: Area2D = $DamageArea
@onready var collect_area: Area2D = $CollectArea
@onready var sfx_pickup: AudioStreamPlayer2D = get_node_or_null("SFX_Pickup")
@onready var sfx_kick_hit: AudioStreamPlayer2D = get_node_or_null("SFX_KickHit")
@onready var sfx_wobble: AudioStreamPlayer2D = get_node_or_null("SFX_Wobble")
@onready var sfx_fall: AudioStreamPlayer2D = get_node_or_null("SFX_Fall")
@onready var sfx_land: AudioStreamPlayer2D = get_node_or_null("SFX_Land")

var state: State = State.HANGING
var _collected: bool = false
var _hit_enemies: Dictionary = {}
var _player_hit_cd: float = 0.0
var _player_collision_ignore_cd: float = 0.0
var _ignored_player: Node = null
var _last_wobble_sfx_frame: int = -1


func _ready() -> void:
	player_detect.body_entered.connect(_on_player_detect_body_entered)
	collect_area.body_entered.connect(_on_collect_area_body_entered)
	collect_area.area_entered.connect(_on_collect_area_area_entered)
	kick_detect.area_entered.connect(_on_kick_detect_area_entered)
	damage_area.area_entered.connect(_on_damage_area_area_entered)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	_set_dangerous(false)
	_set_body_solid(false)
	_set_still_interactions(false)
	sprite.play(&"apple_idle")


func _physics_process(delta: float) -> void:
	if _player_hit_cd > 0.0:
		_player_hit_cd = maxf(0.0, _player_hit_cd - delta)
	if _player_collision_ignore_cd > 0.0:
		_player_collision_ignore_cd = maxf(0.0, _player_collision_ignore_cd - delta)
		if _player_collision_ignore_cd <= 0.0 and _ignored_player != null:
			if is_instance_valid(_ignored_player):
				remove_collision_exception_with(_ignored_player)
			_ignored_player = null

	match state:
		State.HANGING, State.WOBBLING, State.COLLECTING:
			velocity = Vector2.ZERO
		State.FALLING, State.KICKED:
			if not is_on_floor():
				velocity.y += gravity * delta
			elif state == State.FALLING:
				velocity.y = 0.0
			if state == State.KICKED and is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, gravity * delta * 0.5)
			move_and_slide()
			if state == State.FALLING:
				_check_player_slide_collisions()
			_handle_motion_state()
		State.LANDED_STILL:
			_try_collect_overlapping()


func _handle_motion_state() -> void:
	if state == State.FALLING and _is_on_real_floor():
		_enter_landed_still(true)
	elif state == State.KICKED and is_on_floor() and absf(velocity.x) < settle_speed_threshold:
		velocity.x = 0.0
		_enter_landed_still(false)


func _is_on_real_floor() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("player"):
			return false
	return true


func _check_player_slide_collisions() -> void:
	if _player_hit_cd > 0.0:
		return
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("player"):
			_bounce_off_player(collider)
			return


func _bounce_off_player(player: Node) -> void:
	var away := signf(global_position.x - player.global_position.x)
	if away == 0.0:
		away = 1.0
	velocity = Vector2(away * player_bounce_x, player_bounce_y)
	global_position.x += away * 4.0
	if is_instance_valid(_ignored_player):
		remove_collision_exception_with(_ignored_player)
	add_collision_exception_with(player)
	_ignored_player = player
	_player_hit_cd = player_hit_cooldown
	_player_collision_ignore_cd = player_collision_ignore_time


func _enter_landed_still(from_fall: bool = false) -> void:
	state = State.LANDED_STILL
	velocity = Vector2.ZERO
	_set_dangerous(false)
	_hit_enemies.clear()
	_set_body_solid(false)
	_set_still_interactions(true)

	if from_fall:
		_play_land_sfx()
		_play_anim(&"apple_land", _on_land_finished)
	else:
		sprite.play(&"apple_idle")

	_try_collect_overlapping()


func _on_land_finished() -> void:
	if state == State.LANDED_STILL:
		sprite.play(&"apple_idle")


func _on_player_detect_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if state == State.HANGING:
		_start_wobble()


func _on_collect_area_body_entered(body: Node) -> void:
	if body == null or state != State.LANDED_STILL:
		return
	if body.is_in_group("player"):
		_try_collect(body)
	elif _is_enemy_body(body):
		_try_enemy_collect(body)


func _on_collect_area_area_entered(area: Area2D) -> void:
	if state != State.LANDED_STILL:
		return
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := _resolve_enemy_from_node(area)
	if enemy:
		_try_enemy_collect(enemy)


func _try_collect_overlapping() -> void:
	if state != State.LANDED_STILL:
		return
	if collect_area == null or not collect_area.monitoring:
		return
	for body in collect_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			_try_collect(body)
			return
		if _is_enemy_body(body):
			_try_enemy_collect(body)
			return
	for area in collect_area.get_overlapping_areas():
		if not area.is_in_group("enemy_hurtbox"):
			continue
		var enemy := _resolve_enemy_from_node(area)
		if enemy:
			_try_enemy_collect(enemy)
			return


func _start_wobble() -> void:
	state = State.WOBBLING
	_last_wobble_sfx_frame = -1
	_play_anim(&"apple_wobble", _on_wobble_finished)
	_on_sprite_frame_changed()


func _on_wobble_finished() -> void:
	if state != State.WOBBLING:
		return
	state = State.FALLING
	_hit_enemies.clear()
	_set_body_solid(true)
	_set_dangerous(true, true)
	_play_fall_sfx()
	sprite.play(&"apple_idle")


func _on_sprite_frame_changed() -> void:
	if state != State.WOBBLING or sprite.animation != &"apple_wobble":
		_last_wobble_sfx_frame = -1
		return

	var current_frame: int = sprite.frame
	if current_frame == _last_wobble_sfx_frame:
		return
	_last_wobble_sfx_frame = current_frame

	if current_frame == 0 or current_frame == 2:
		_play_wobble_sfx()


func _try_collect(body: Node) -> void:
	if _collected or state != State.LANDED_STILL:
		return
	if not body.is_in_group("player"):
		return
	if body.get("hp") == null or body.get("max_hp") == null:
		return
	if body.hp < body.max_hp and body.has_method("heal"):
		body.heal(heal_amount)
	_begin_collect()


func _try_enemy_collect(enemy: Node) -> void:
	if _collected or state != State.LANDED_STILL:
		return
	if not _is_enemy_body(enemy):
		return
	if enemy.get("dead") == true:
		return
	_heal_enemy(enemy)
	_begin_collect()


func _begin_collect() -> void:
	_collected = true
	state = State.COLLECTING
	velocity = Vector2.ZERO
	_disable_collisions_deferred()
	_play_collect_sfx()
	_play_anim(&"apple_collect", func() -> void: queue_free())


func _play_collect_sfx() -> void:
	if sfx_pickup == null or sfx_pickup.stream == null:
		return
	var parent := get_parent()
	if parent:
		sfx_pickup.reparent(parent)
	sfx_pickup.global_position = global_position
	sfx_pickup.play()
	sfx_pickup.finished.connect(sfx_pickup.queue_free, CONNECT_ONE_SHOT)


func _play_kick_hit_sfx() -> void:
	if sfx_kick_hit and sfx_kick_hit.stream:
		sfx_kick_hit.play()


func _play_wobble_sfx() -> void:
	if sfx_wobble == null or sfx_wobble.stream == null:
		return
	sfx_wobble.pitch_scale = randf_range(0.95, 1.05)
	sfx_wobble.play()


func _play_fall_sfx() -> void:
	if sfx_fall == null or sfx_fall.stream == null:
		return
	sfx_fall.play()


func _play_land_sfx() -> void:
	if sfx_land == null or sfx_land.stream == null:
		return
	sfx_land.play()


func _heal_enemy(enemy: Node) -> void:
	if enemy.has_method("heal"):
		enemy.call("heal", heal_amount)
		return
	if enemy.get("hp") != null and enemy.get("max_hp") != null:
		enemy.hp = mini(enemy.max_hp, enemy.hp + heal_amount)


func _is_enemy_body(body: Node) -> bool:
	if body == null or body.is_in_group("player"):
		return false
	if not body is CharacterBody2D:
		return false
	return _node_has_enemy_hurtbox(body)


func _resolve_enemy_from_node(start: Node) -> Node:
	var node: Node = start
	while node and node != self:
		if node is CharacterBody2D and not node.is_in_group("player"):
			if _node_has_enemy_hurtbox(node):
				return node
		node = node.get_parent()
	return null


func _node_has_enemy_hurtbox(node: Node) -> bool:
	for area in node.find_children("*", "Area2D", true, false):
		if area.is_in_group("enemy_hurtbox"):
			return true
	return false


func _on_kick_detect_area_entered(area: Area2D) -> void:
	if state != State.LANDED_STILL:
		return
	if not area.is_in_group("player_attack"):
		return

	var player := _find_player_from_node(area)
	if player == null:
		return

	var facing := _get_player_facing(player)
	_play_kick_hit_sfx()
	state = State.KICKED
	_hit_enemies.clear()
	_set_body_solid(true)
	_set_still_interactions(false)
	_set_dangerous(true, false)
	velocity = Vector2(float(facing) * kick_speed, kick_arc_y)
	sprite.play(&"apple_idle")


func _on_damage_area_area_entered(area: Area2D) -> void:
	if state == State.FALLING and area.is_in_group("player_hurtbox"):
		if _player_hit_cd <= 0.0:
			var player := _find_player_from_node(area)
			if player:
				_bounce_off_player(player)
		return

	if state != State.FALLING and state != State.KICKED:
		return
	if not area.is_in_group("enemy_hurtbox"):
		return

	var enemy_node: Node = area.get_parent()
	if enemy_node and not enemy_node.has_method("apply_hitstop"):
		enemy_node = enemy_node.get_parent()
	if enemy_node == null:
		return

	var enemy_id: int = enemy_node.get_instance_id()
	if _hit_enemies.has(enemy_id):
		return
	_hit_enemies[enemy_id] = true

	if enemy_node.has_method("apply_hitstop"):
		enemy_node.call("apply_hitstop", CombatTuning.APPLE_HITSTOP_FRAMES)


func _set_dangerous(on: bool, hurt_player: bool = false) -> void:
	if damage_area == null:
		return
	damage_area.set_deferred("monitoring", on)
	if on:
		damage_area.add_to_group("player_attack")
		if hurt_player:
			damage_area.add_to_group("enemy_attack")
		else:
			damage_area.remove_from_group("enemy_attack")
	else:
		damage_area.remove_from_group("player_attack")
		damage_area.remove_from_group("enemy_attack")


func _set_body_solid(solid: bool) -> void:
	if body_col:
		body_col.set_deferred("disabled", not solid)


func _set_still_interactions(enabled: bool) -> void:
	if collect_area:
		collect_area.set_deferred("monitoring", enabled)
	if kick_detect:
		kick_detect.set_deferred("monitoring", enabled)
	if damage_area:
		damage_area.set_deferred("monitoring", false)


func _disable_collisions_deferred() -> void:
	if body_col:
		body_col.set_deferred("disabled", true)
	if player_detect:
		player_detect.set_deferred("monitoring", false)
	if kick_detect:
		kick_detect.set_deferred("monitoring", false)
	if damage_area:
		damage_area.set_deferred("monitoring", false)
		damage_area.remove_from_group("player_attack")
		damage_area.remove_from_group("enemy_attack")
	if collect_area:
		collect_area.set_deferred("monitoring", false)


func _play_anim(anim_name: StringName, on_finished: Callable) -> void:
	if sprite == null or sprite.sprite_frames == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		if on_finished.is_valid():
			on_finished.call()
		return

	sprite.play(anim_name)
	if not on_finished.is_valid():
		return
	if sprite.animation_finished.is_connected(_on_anim_finished_proxy):
		sprite.animation_finished.disconnect(_on_anim_finished_proxy)
	_pending_anim_callback = on_finished
	sprite.animation_finished.connect(_on_anim_finished_proxy, CONNECT_ONE_SHOT)


var _pending_anim_callback: Callable = Callable()


func _on_anim_finished_proxy() -> void:
	if _pending_anim_callback.is_valid():
		var cb := _pending_anim_callback
		_pending_anim_callback = Callable()
		cb.call()


func _find_player_from_node(start: Node) -> Node:
	var node: Node = start
	while node:
		if node.is_in_group("player"):
			return node
		node = node.get_parent()
	return null


func _get_player_facing(player: Node) -> int:
	var anim: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if anim:
		return -1 if anim.flip_h else 1
	return 1
