extends CharacterBody2D

@export var perimeter_speed: float = 40.0
@export var cling_outset: float = 8.0
@export var platform_shape_path: NodePath = NodePath()
@export_range(0, 3) var start_corner_index: int = 0
@export var start_t_on_edge: float = 0.0

## Per-enemy resistance (1.0 = full shared kick knockback). Easy to retune later.
const KICK_KNOCKBACK_RESISTANCE: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var sfx_disintegrate: AudioStreamPlayer2D = $SFX_Disintegrate

var dead: bool = false
var fatal_hitstop_active: bool = false
var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

var _platform_shape: CollisionShape2D
var _edge_index: int = 0
var _t_on_edge: float = 0.0

## Horizontal velocity to apply when fatal kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Sliding during hurt/death after kick fatal hitstop (perimeter never resumes).
var _kick_death_knockback_active: bool = false


func _ready() -> void:
	hurtbox.add_to_group("enemy_hurtbox")
	attack_hitbox.add_to_group("enemy_attack")

	sprite.play("walk")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if platform_shape_path != NodePath():
		_platform_shape = get_node_or_null(platform_shape_path) as CollisionShape2D
	if _platform_shape and _platform_shape.shape is RectangleShape2D:
		_edge_index = posmod(start_corner_index, 4)
		var seg := _edge_segment(_edge_index)
		var seg_len: float = seg.from.distance_to(seg.to)
		_t_on_edge = clampf(start_t_on_edge, 0.0, seg_len)
		var dir: Vector2 = (seg.to - seg.from).normalized()
		global_position = seg.from + dir * _t_on_edge
		_apply_body_rotation_for_edge(_edge_index)


func apply_hitstop(hitstop_count: int = 2) -> void:
	var clamped_frames: int = max(0, hitstop_count)
	hitstop_frames = max(hitstop_frames, clamped_frames)


func _physics_process(delta: float) -> void:
	# Fatal hold: stay on hurt frame 0 until local hitstop expires, then resume death anims.
	# Perimeter locomotion is never called in this branch.
	if fatal_hitstop_active:
		velocity = Vector2.ZERO
		if hitstop_frames > 0:
			hitstop_frames -= 1
			if sprite:
				if sprite.animation != &"hurt" and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
					sprite.play("hurt")
				sprite.frame = 0
				if not _hitstop_sprite_paused:
					sprite.pause()
					_hitstop_sprite_paused = true
			if hitstop_frames > 0:
				return
		_hitstop_sprite_paused = false
		fatal_hitstop_active = false
		_begin_death_sequence()
		return

	# After kick fatal hitstop: world-space horizontal slide while hurt/death play.
	# Intentionally does not call _perimeter_step.
	if dead and _kick_death_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		if is_zero_approx(velocity.x):
			_kick_death_knockback_active = false
			velocity = Vector2.ZERO
			set_physics_process(false)
		return

	if dead:
		return

	if hitstop_frames > 0:
		hitstop_frames -= 1
		if not _hitstop_sprite_paused:
			sprite.pause()
			_hitstop_sprite_paused = true
		if hitstop_frames > 0:
			return
	if _hitstop_sprite_paused:
		sprite.play()
		_hitstop_sprite_paused = false

	_perimeter_step(delta)


func _platform_rect_global() -> Rect2:
	var rs := _platform_shape.shape as RectangleShape2D
	var half := rs.size * 0.5
	var c := _platform_shape.global_transform.origin
	return Rect2(c - half, rs.size)


func _outer_corners() -> Array[Vector2]:
	var o := cling_outset
	var r := _platform_rect_global()
	var nw := Vector2(r.position.x - o, r.position.y - o)
	var ne := Vector2(r.end.x + o, r.position.y - o)
	var se := Vector2(r.end.x + o, r.end.y + o)
	var sw := Vector2(r.position.x - o, r.end.y + o)
	return [nw, ne, se, sw]


func _edge_segment(i: int) -> Dictionary:
	var c := _outer_corners()
	var a: Vector2 = c[i]
	var b: Vector2 = c[(i + 1) % 4]
	return {"from": a, "to": b}


func _perimeter_step(delta: float) -> void:
	if not is_instance_valid(_platform_shape) or not (_platform_shape.shape is RectangleShape2D):
		return

	var travel := perimeter_speed * delta
	while travel > 0.0:
		var seg := _edge_segment(_edge_index)
		var seg_len: float = seg.from.distance_to(seg.to)
		if seg_len <= 0.0001:
			break
		var remain: float = seg_len - _t_on_edge
		if travel <= remain:
			_t_on_edge += travel
			travel = 0.0
		else:
			travel -= remain
			_edge_index = (_edge_index + 1) % 4
			_t_on_edge = 0.0

	var segf := _edge_segment(_edge_index)
	var dir: Vector2 = (segf.to - segf.from).normalized()
	global_position = segf.from + dir * _t_on_edge
	_apply_body_rotation_for_edge(_edge_index)


func _apply_body_rotation_for_edge(edge: int) -> void:
	match edge:
		0:
			rotation = 0.0
		1:
			rotation = PI * 0.5
		2:
			rotation = PI
		3:
			rotation = -PI * 0.5


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or fatal_hitstop_active:
		return
	if not area.is_in_group("player_attack"):
		return

	# Kick-only: KickHitbox node name vs Apple's DamageArea.
	if area.name == "KickHitbox":
		var kick_pivot := area.get_parent()
		var kick_owner: Node = kick_pivot.get_parent() if kick_pivot else null
		if kick_owner != null and kick_owner.has_method("register_kick_damage_target"):
			if not kick_owner.register_kick_damage_target(self):
				return
		var push_dir: float = sign(global_position.x - area.global_position.x)
		if push_dir == 0.0:
			push_dir = 1.0
		# player_multiplier 1.0 until a kick knockback perk exists.
		_pending_kick_knockback_x = push_dir * CombatTuning.resolve_kick_knockback_speed(
			1.0, KICK_KNOCKBACK_RESISTANCE
		)
	else:
		_pending_kick_knockback_x = 0.0

	_enter_fatal_hitstop()


func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	velocity = Vector2.ZERO
	if is_instance_valid(sfx_death) and sfx_death.stream:
		sfx_death.play()
	hurtbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


func _begin_death_sequence() -> void:
	# Kick fatal → horizontal slide while dying; apple keeps freeze-in-place.
	# Perimeter clinging never resumes after fatal damage.
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		set_physics_process(false)

	var has_hurt := sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")
	var has_death := sprite.sprite_frames and sprite.sprite_frames.has_animation("death")

	if has_hurt and has_death:
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_after_hurt, CONNECT_ONE_SHOT)
	elif has_death:
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _after_hurt() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		if is_instance_valid(sfx_disintegrate) and sfx_disintegrate.stream:
			sfx_disintegrate.play()
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _after_death() -> void:
	queue_free()
