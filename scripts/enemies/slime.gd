extends CharacterBody2D

## Simple sewer slime. Sprite art faces RIGHT by default.
## direction: 1 = facing right, -1 = facing left.
##
## Slow hop cycle: IDLE -> JUMP_START -> AIR -> LAND -> IDLE.
## Contact damage only. Normal slimes can split on death. Max HP = 1.

@export var gravity: float = 800.0
@export var start_direction: int = -1
## Margin around the body that wakes the slime just before it enters the camera.
@export_range(0.0, 512.0, 1.0) var activation_lead_px: float = 32.0
## Uncheck to hop immediately from level load.
@export var require_screen_activation: bool = true
@export var hop_forward_speed: float = 60.0
@export var hop_up_speed: float = -272.0
@export var hop_cooldown: float = 1.2
@export var slide_speed: float = 45.0
@export var slide_deceleration: float = 32.0
@export var max_hp: int = 1
@export var puddle_scene: PackedScene = preload("res://scenes/enemies/SlimePuddle.tscn")
@export_range(0.0, 1.0) var split_chance: float = 0.0
@export var small_slime_scene: PackedScene
@export var split_spawn_offset: float = 12.0

## Match the shared kick strength for light enemies.
const KICK_KNOCKBACK_RESISTANCE := 1.0

enum State { IDLE, JUMP_START, AIR, LAND, SLIDE, DEAD }

var state: State = State.IDLE
var direction: int = 1
var hp: int = 1
var dead: bool = false
var fatal_hitstop_active: bool = false

var _hop_timer: float = 0.0
var _state_timer: float = 0.0
var _died_in_air: bool = false
var _will_split: bool = false
var _pending_kick_knockback_x: float = 0.0
var _kick_death_knockback_active: bool = false
## One-shot activation: scrolling away never interrupts a hop or slide.
var _activated: bool = false

var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var sfx_land: AudioStreamPlayer2D = $SFX_Land
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var sfx_melt: AudioStreamPlayer2D = $SFX_Melt
@onready var sfx_split: AudioStreamPlayer2D = get_node_or_null("SFX_Split") as AudioStreamPlayer2D


func _ready() -> void:
	direction = -1 if start_direction < 0 else 1
	hp = maxi(1, max_hp)
	_hop_timer = hop_cooldown

	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	_update_facing()
	_play_if_exists("idle")
	_setup_screen_activation()
	if not require_screen_activation:
		_activate()
		return
	# Catch enemies already visible when the level opens, as the hedgehog does.
	await get_tree().process_frame
	if not _activated and screen_notifier.is_on_screen():
		_activate()


func _setup_screen_activation() -> void:
	var body_rect := body_shape.shape as RectangleShape2D
	var half := body_rect.size * 0.5 + Vector2.ONE * activation_lead_px
	screen_notifier.rect = Rect2(body_shape.position - half, half * 2.0)
	screen_notifier.screen_entered.connect(_activate)


func _activate() -> void:
	if _activated or dead:
		return
	_activated = true


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func _physics_process(delta: float) -> void:
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

	if dead and _kick_death_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		if _is_touching_world_wall() or is_zero_approx(velocity.x):
			_stop_kick_death_knockback()
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

	if not is_on_floor():
		velocity.y += gravity * delta

	# Settle onto the floor while dormant, without consuming the first hop timer.
	if not _activated:
		velocity.x = 0.0
		move_and_slide()
		return

	match state:
		State.IDLE:
			_process_idle(delta)
		State.JUMP_START:
			_process_jump_start()
		State.AIR:
			_process_air()
		State.LAND:
			_process_land(delta)
		State.SLIDE:
			_process_slide(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


func _process_idle(delta: float) -> void:
	_play_if_exists("idle")

	if not is_on_floor():
		return

	velocity = Vector2.ZERO

	if _hop_timer > 0.0:
		_hop_timer = maxf(0.0, _hop_timer - delta)
		return

	_start_jump()


func _process_jump_start() -> void:
	velocity = Vector2.ZERO
	_play_if_exists("jump_start")


func _process_air() -> void:
	if _is_touching_world_wall(true):
		direction *= -1
		_update_facing()

	velocity.x = float(direction) * hop_forward_speed

	if velocity.y >= 0.0:
		_play_if_exists("jump_down")
	else:
		_play_if_exists("jump_up")

	if is_on_floor() and velocity.y >= 0.0:
		_start_land()


func _process_land(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_if_exists("land")

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		return

	_start_slide()


func _start_slide() -> void:
	state = State.SLIDE
	velocity.x = float(direction) * slide_speed
	velocity.y = 0.0
	_state_timer = _anim_duration("slide")
	_play_if_exists("slide")


func _process_slide(delta: float) -> void:
	_play_if_exists("slide")

	velocity.x = move_toward(velocity.x, 0.0, slide_deceleration * delta)

	if _is_touching_world_wall(true):
		direction *= -1
		_update_facing()
		velocity.x = 0.0

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		return

	state = State.IDLE
	velocity = Vector2.ZERO
	_hop_timer = hop_cooldown
	_play_if_exists("idle")


func _start_jump() -> void:
	state = State.JUMP_START
	_play_if_exists("jump_start")

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("jump_start"):
		if sprite.animation_finished.is_connected(_on_jump_start_finished):
			sprite.animation_finished.disconnect(_on_jump_start_finished)
		sprite.animation_finished.connect(_on_jump_start_finished, CONNECT_ONE_SHOT)
	else:
		_on_jump_start_finished()


func _on_jump_start_finished() -> void:
	if dead or state != State.JUMP_START:
		return

	state = State.AIR
	velocity = Vector2(float(direction) * hop_forward_speed, hop_up_speed)
	_play_if_exists("jump_up")
	_play_sfx(sfx_jump)


func _start_land() -> void:
	state = State.LAND
	velocity = Vector2.ZERO
	_state_timer = _anim_duration("land")
	_play_if_exists("land")
	_play_sfx(sfx_land)


func _update_facing() -> void:
	sprite.flip_h = direction < 0


func _is_touching_world_wall(only_ahead: bool = false) -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var normal := collision.get_normal()
		if absf(normal.x) < 0.5:
			continue
		# Contact can persist after stopping or turning. Only turn away from
		# a wall we still face, rather than reversing again on the same contact.
		if only_ahead and normal.x * float(direction) >= 0.0:
			continue

		var collider := collision.get_collider()
		if collider is CharacterBody2D:
			continue

		return true

	return false


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()


func _anim_duration(anim_name: String) -> float:
	if not (sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name)):
		return 0.2
	var count: int = sprite.sprite_frames.get_frame_count(anim_name)
	var fps: float = sprite.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		fps = 12.0
	return maxf(0.05, float(count) / fps)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or fatal_hitstop_active:
		return
	if not area.is_in_group("player_attack"):
		return
	# Once per KickHitbox target per swing (blocks hitstop re-arm doubles).
	if area.name == "KickHitbox":
		var kick_pivot := area.get_parent()
		var kick_owner: Node = kick_pivot.get_parent() if kick_pivot else null
		if kick_owner != null and kick_owner.has_method("register_kick_damage_target"):
			if not kick_owner.register_kick_damage_target(self):
				return
		var push_dir := signf(global_position.x - area.global_position.x)
		if is_zero_approx(push_dir):
			push_dir = float(-direction)
		_pending_kick_knockback_x = push_dir * CombatTuning.resolve_kick_knockback_speed(
			1.0, KICK_KNOCKBACK_RESISTANCE
		)
	else:
		_pending_kick_knockback_x = 0.0
	_take_damage(1)


func _take_damage(amount: int) -> void:
	if dead or fatal_hitstop_active:
		return

	hp = maxi(0, hp - amount)
	_play_sfx(sfx_hurt)
	if hp <= 0:
		_enter_fatal_hitstop()


func _enter_fatal_hitstop() -> void:
	_died_in_air = not is_on_floor()
	_will_split = split_chance > 0.0 and small_slime_scene != null and sprite.sprite_frames.has_animation("split") and randf() < split_chance
	dead = true
	fatal_hitstop_active = true
	state = State.DEAD
	velocity = Vector2.ZERO

	if is_instance_valid(contact_hitbox):
		contact_hitbox.set_deferred("monitoring", false)
	if is_instance_valid(contact_hitbox_shape):
		contact_hitbox_shape.set_deferred("disabled", true)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitoring", false)
	if is_instance_valid(hurtbox_shape):
		hurtbox_shape.set_deferred("disabled", true)
	# Keep world collision during a fatal kick so the slide stops at walls.
	if is_zero_approx(_pending_kick_knockback_x) and is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)

	if sprite.animation_finished.is_connected(_on_jump_start_finished):
		sprite.animation_finished.disconnect(_on_jump_start_finished)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


func _begin_death_sequence() -> void:
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		set_physics_process(false)

	var has_hurt := sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")

	if has_hurt:
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_after_final_hurt, CONNECT_ONE_SHOT)
	else:
		_start_death_animation()


func _stop_kick_death_knockback() -> void:
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _after_final_hurt() -> void:
	if not dead or sprite.animation != "hurt":
		return
	_start_death_animation()


func _start_death_animation() -> void:
	if _will_split:
		_play_sfx(sfx_split)
		sprite.play("split")
		sprite.animation_finished.connect(_on_split_finished, CONNECT_ONE_SHOT)
		return

	if not _died_in_air:
		_start_melt()
		return

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death_air"):
		sprite.play("death_air")
		sprite.animation_finished.connect(_on_death_air_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_split_finished() -> void:
	if not dead or sprite.animation != "split":
		return
	for facing in [-1, 1]:
		var small_slime := small_slime_scene.instantiate() as CharacterBody2D
		small_slime.set("start_direction", facing)
		small_slime.set("split_chance", 0.0)
		# Children of a defeated slime join the existing encounter immediately.
		small_slime.set("require_screen_activation", false)
		# Same parent and transform preserve scale and align the last split frame.
		small_slime.transform = transform
		small_slime.position += transform.basis_xform(Vector2(float(facing) * split_spawn_offset, 0.0))
		get_parent().add_child(small_slime)
	queue_free()


func _on_death_air_finished() -> void:
	if not dead or sprite.animation != "death_air":
		return
	queue_free()


func _start_melt() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("melt"):
		_play_sfx(sfx_melt)
		sprite.play("melt")
		sprite.animation_finished.connect(_on_melt_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_melt_finished() -> void:
	if not dead or sprite.animation != "melt":
		return
	_spawn_puddle()
	queue_free()


func _spawn_puddle() -> void:
	if puddle_scene == null:
		return

	var puddle: Node2D = puddle_scene.instantiate()
	if puddle == null:
		return

	var world := get_tree().current_scene
	if world:
		world.add_child(puddle)
	else:
		get_parent().add_child(puddle)

	puddle.global_position = global_position
