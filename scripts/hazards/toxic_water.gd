extends Node2D

## Fixed-width toxic water pit. Damages via enemy_attack ↔ player Hurtbox.
## When can_squirt is true, idle loops 3 times then plays a one-shot squirt attack.

const IDLE_LAST_FRAME: int = 10
const SQUIRT_HITBOX_ENABLE_FRAME: int = 5
const SQUIRT_HITBOX_DISABLE_FRAME: int = 8
const IDLE_LOOPS_BEFORE_SQUIRT: int = 3

@export var can_squirt: bool = false
@export var knockback_x: float = 120.0
@export var knockback_y: float = -220.0
@export var knockback_velocity_deadzone: float = 10.0
@export var pit_half_width: float = 32.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _liquid_damage: Area2D = $LiquidDamage
@onready var _liquid_shape: CollisionShape2D = $LiquidDamage/CollisionShape2D
@onready var _squirt_damage: Area2D = $SquirtDamage
@onready var _squirt_shape: CollisionShape2D = $SquirtDamage/CollisionShape2D

var _idle_loops_completed: int = 0
var _prev_frame: int = -1
var _is_squirting: bool = false


func _ready() -> void:
	# Refresh knockback meta before the player physics/hurt path when possible.
	process_physics_priority = -10

	_liquid_damage.area_entered.connect(_on_damage_area_entered.bind(_liquid_damage))
	_squirt_damage.area_entered.connect(_on_damage_area_entered.bind(_squirt_damage))

	_write_knockback_meta(_liquid_damage, Vector2(0.0, knockback_y))
	_write_knockback_meta(_squirt_damage, Vector2(0.0, knockback_y))
	_set_area_active(_liquid_damage, _liquid_shape, true)
	_set_area_active(_squirt_damage, _squirt_shape, false)

	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)

	_idle_loops_completed = 0
	_is_squirting = false
	_prev_frame = -1
	_sprite.play(&"idle")


func _physics_process(_delta: float) -> void:
	# Keep meta current for standing overlaps / post-invuln re-hits.
	_refresh_knockback_for_area(_liquid_damage)
	_refresh_knockback_for_area(_squirt_damage)


func _on_damage_area_entered(other: Area2D, damage_area: Area2D) -> void:
	var player := _player_from_hurtbox(other)
	if player == null:
		return
	_write_knockback_meta(damage_area, _compute_knockback(player))


func _refresh_knockback_for_area(damage_area: Area2D) -> void:
	if not is_instance_valid(damage_area) or not damage_area.monitoring:
		return
	for other in damage_area.get_overlapping_areas():
		var player := _player_from_hurtbox(other)
		if player != null:
			_write_knockback_meta(damage_area, _compute_knockback(player))
			return


func _player_from_hurtbox(area: Area2D) -> CharacterBody2D:
	if area == null or not area.is_in_group(&"player_hurtbox"):
		return null
	var parent := area.get_parent()
	return parent as CharacterBody2D


func _compute_knockback(player: CharacterBody2D) -> Vector2:
	var dir: float
	if absf(player.velocity.x) > knockback_velocity_deadzone:
		dir = signf(player.velocity.x)
	else:
		var center_x: float = global_position.x
		var dist_left: float = player.global_position.x - (center_x - pit_half_width)
		var dist_right: float = (center_x + pit_half_width) - player.global_position.x
		dir = -1.0 if dist_left <= dist_right else 1.0
	return Vector2(dir * absf(knockback_x), knockback_y)


func _write_knockback_meta(area: Area2D, kb: Vector2) -> void:
	area.set_meta(&"hurt_knockback", kb)


func _on_frame_changed() -> void:
	if _sprite.animation == &"squirt":
		_update_squirt_hitbox_for_current_frame()
		_prev_frame = _sprite.frame
		return

	if not can_squirt or _is_squirting or _sprite.animation != &"idle":
		_prev_frame = _sprite.frame
		return

	var frame: int = _sprite.frame
	# Completed idle loop: wrap from last frame back to first.
	if _prev_frame == IDLE_LAST_FRAME and frame == 0:
		_idle_loops_completed += 1
		if _idle_loops_completed >= IDLE_LOOPS_BEFORE_SQUIRT:
			_idle_loops_completed = 0
			_is_squirting = true
			_prev_frame = -1
			_set_area_active(_squirt_damage, _squirt_shape, false)
			_sprite.play(&"squirt")
			_update_squirt_hitbox_for_current_frame()
			return

	_prev_frame = frame


func _on_animation_finished() -> void:
	if _sprite.animation != &"squirt":
		return

	_set_area_active(_squirt_damage, _squirt_shape, false)
	_is_squirting = false
	_idle_loops_completed = 0
	_prev_frame = -1
	_sprite.play(&"idle")


func _update_squirt_hitbox_for_current_frame() -> void:
	var active := (
		_sprite.animation == &"squirt"
		and _sprite.frame >= SQUIRT_HITBOX_ENABLE_FRAME
		and _sprite.frame < SQUIRT_HITBOX_DISABLE_FRAME
	)
	_set_area_active(_squirt_damage, _squirt_shape, active)


func _set_area_active(area: Area2D, shape: CollisionShape2D, active: bool) -> void:
	if not is_instance_valid(area):
		return

	if active:
		if not area.is_in_group(&"enemy_attack"):
			area.add_to_group(&"enemy_attack")
	else:
		if area.is_in_group(&"enemy_attack"):
			area.remove_from_group(&"enemy_attack")

	area.set_deferred(&"monitoring", active)
	area.set_deferred(&"monitorable", active)
	if is_instance_valid(shape):
		shape.set_deferred(&"disabled", not active)
