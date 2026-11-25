extends CharacterBody2D

## Inclusive frames of `attack` with the jaws extended (zero based).
const BITE_FRAME_START: int = 1
const BITE_FRAME_END: int = 3

enum State { PATROL, WARNING, BITE, RECOVERY }

@export var speed: float = 54.0
@export var gravity: float = 800.0
@export var turn_cooldown: float = 0.15
## Margin around the body that wakes the rat just before it enters the camera.
@export_range(0.0, 512.0, 1.0) var activation_lead_px: float = 32.0
## Uncheck to patrol immediately from level load.
@export var require_screen_activation: bool = true
@export_range(1.0, 128.0, 1.0) var attack_range: float = 48.0
@export_range(0.0, 64.0, 1.0) var attack_vertical_tolerance: float = 18.0
@export_range(0.05, 1.0, 0.05) var warning_duration: float = 0.3
@export_range(0.0, 300.0, 1.0) var lunge_speed: float = 100.0
@export_range(0.0, 64.0, 1.0) var lunge_distance: float = 20.0
@export_range(0.0, 2.0, 0.05) var recovery_duration: float = 0.35
@export_range(0.0, 5.0, 0.05) var attack_cooldown: float = 0.8
@export var death_idle_delay: float = 0.75

## Per-enemy resistance (1.0 = full shared kick knockback). Easy to revert / retune.
const KICK_KNOCKBACK_RESISTANCE: float = 1.0

var direction: int = -1
var turn_timer: float = 0.0
var dead: bool = false
var fatal_hitstop_active: bool = false

var state: State = State.PATROL
var attack_direction: int = -1
var _state_timer: float = 0.0
var _lunge_remaining: float = 0.0
var attack_cooldown_timer: float = 0.0
## One-shot activation: scrolling away never interrupts patrol or a bite.
var _activated: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox

# AttackHitbox is under the sprite (child), so it will flip when we flip sprite SCALE
@onready var attack_hitbox: Area2D = $AnimatedSprite2D/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AnimatedSprite2D/AttackHitbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier

@onready var sfx_die: AudioStreamPlayer2D = $SFX_SmallRatDie
@onready var sfx_explode: AudioStreamPlayer2D = $SfxExplode
@onready var sfx_attack: AudioStreamPlayer2D = $SFX_Attack
@onready var sfx_warning: AudioStreamPlayer2D = $SFX_Warning

var base_sprite_scale := Vector2.ONE
var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

## Horizontal velocity to apply when fatal kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Sliding during death after kick fatal hitstop (patrol / attack AI never resumes).
var _kick_death_knockback_active: bool = false

func _ready() -> void:
	# Remember whatever scale you authored in the editor
	base_sprite_scale = sprite.scale

	# IMPORTANT: don't use flip_h anymore (we flip via scale so children flip too)
	sprite.flip_h = false

	sprite.play(&"idle")

	_update_facing()

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	sprite.frame_changed.connect(_sync_bite_hitbox)
	sprite.animation_finished.connect(_on_attack_animation_finished)

	# start with attack hitbox OFF
	_set_bite_active(false)
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
	sprite.play(&"walk")

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

	# After kick fatal hitstop: horizontal slide while hurt/death play.
	# Never resumes patrol or attack AI.
	if dead and _kick_death_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		if is_on_wall() or is_zero_approx(velocity.x):
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

	# Settle onto the floor while dormant; only movement AI waits for the camera.
	if not _activated:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = 0.0
		move_and_slide()
		return

	# Cooldown only gates detection; expiry never starts an attack by itself.
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	match state:
		State.PATROL:
			turn_timer = maxf(0.0, turn_timer - delta)
			if attack_cooldown_timer <= 0.0 and _can_attack_player():
				_begin_warning()
			else:
				velocity.x = float(direction) * speed
		State.WARNING:
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				sfx_warning.stop()
				state = State.BITE
				_lunge_remaining = lunge_distance
				sprite.play(&"attack")
		State.BITE:
			# Only the extended-jaw frames propel the rat. Once blocked, stay put.
			if _is_bite_frame() and _lunge_remaining > 0.0:
				var step := minf(lunge_speed * delta, _lunge_remaining)
				var motion := Vector2(float(attack_direction) * step, 0.0)
				if is_on_floor() and _has_lunge_floor(motion) and not test_move(global_transform, motion):
					velocity.x = motion.x / delta
				else:
					_lunge_remaining = 0.0
		State.RECOVERY:
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				state = State.PATROL
				sprite.play(&"walk")

	var previous_x := global_position.x
	move_and_slide()
	if state == State.BITE:
		_lunge_remaining = maxf(0.0, _lunge_remaining - absf(global_position.x - previous_x))
	elif state == State.PATROL and turn_timer <= 0.0 and is_on_wall():
		direction *= -1
		turn_timer = turn_cooldown
		_update_facing()


func _can_attack_player() -> bool:
	if not is_on_floor():
		return false
	for player in get_tree().get_nodes_in_group("player"):
		if not player is Node2D:
			continue
		var offset: Vector2 = player.global_position - global_position
		var forward_distance := offset.x * float(direction)
		if forward_distance <= 0.0 or forward_distance > attack_range or absf(offset.y) > attack_vertical_tolerance:
			continue
		# Bodies only: ignore combat areas and the target itself, but respect walls.
		var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, collision_mask, [get_rid()])
		if player is CollisionObject2D:
			query.exclude = [get_rid(), player.get_rid()]
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _begin_warning() -> void:
	state = State.WARNING
	if sfx_warning.stream:
		sfx_warning.play()
	attack_direction = direction
	_state_timer = warning_duration
	velocity.x = 0.0
	_set_bite_active(false)
	# Fit all four authored warning frames into the chosen duration.
	var frames := sprite.sprite_frames
	var animation_duration: float = 0.0
	for frame_index in frames.get_frame_count(&"windup"):
		animation_duration += frames.get_frame_duration(&"windup", frame_index) / frames.get_animation_speed(&"windup")
	sprite.play(&"windup", animation_duration / maxf(warning_duration, 0.05))


func _has_lunge_floor(motion: Vector2) -> bool:
	# Probe beyond the body's leading foot at the proposed next position.
	var rect := body_shape.shape as RectangleShape2D
	var foot := body_shape.global_position + Vector2(float(attack_direction) * rect.size.x * 0.5 * absf(global_scale.x), rect.size.y * 0.5 * absf(global_scale.y)) + motion
	var excluded: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("player"):
		if player is CollisionObject2D:
			excluded.append(player.get_rid())
	var query := PhysicsRayQueryParameters2D.create(foot + Vector2(0.0, -4.0), foot + Vector2(0.0, 6.0), collision_mask, excluded)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_bite_frame() -> bool:
	return state == State.BITE and sprite.animation == &"attack" and sprite.frame >= BITE_FRAME_START and sprite.frame <= BITE_FRAME_END


func _sync_bite_hitbox() -> void:
	var active := not dead and not fatal_hitstop_active and _is_bite_frame()
	_set_bite_active(active)
	if active and sprite.frame == BITE_FRAME_START and sfx_attack.stream:
		sfx_attack.play()


func _set_bite_active(active: bool) -> void:
	# One existing damage source, using the player's shared damage/iframe path.
	# Remove the group immediately too, so queued overlaps cannot hurt after death.
	if active:
		attack_hitbox.add_to_group("enemy_attack")
	else:
		attack_hitbox.remove_from_group("enemy_attack")
	attack_shape.set_deferred("disabled", not active)


func _on_attack_animation_finished() -> void:
	if dead or state != State.BITE or sprite.animation != &"attack":
		return
	_set_bite_active(false)
	_lunge_remaining = 0.0
	velocity.x = 0.0
	state = State.RECOVERY
	_state_timer = recovery_duration
	attack_cooldown_timer = attack_cooldown
	sprite.play(&"idle")

func _update_facing() -> void:
	# Flip the TRANSFORM so children (hitboxes) flip too.
	var sx := absf(base_sprite_scale.x)
	sprite.scale = Vector2(sx * (-1.0 if direction < 0 else 1.0), base_sprite_scale.y)
	# Hurtbox is on the body root (not under the sprite); mirror it to match facing.
	hurtbox.scale.x = -1.0 if direction < 0 else 1.0

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
			push_dir = float(-direction)
		_pending_kick_knockback_x = push_dir * CombatTuning.resolve_kick_knockback_speed(
			1.0, KICK_KNOCKBACK_RESISTANCE
		)
	else:
		_pending_kick_knockback_x = 0.0

	_enter_fatal_hitstop()


func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	sfx_attack.stop()
	sfx_warning.stop()
	_state_timer = 0.0
	_lunge_remaining = 0.0
	state = State.PATROL
	velocity = Vector2.ZERO
	_disable_attack_hitbox_deferred()
	_disable_hurtbox_deferred()
	# Keep body during kick knockback so walls can stop the slide; apple disables now.
	if is_zero_approx(_pending_kick_knockback_x) and is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	if sfx_die and sfx_die.stream:
		sfx_die.play()
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
		_continue_after_death_anim()


func _stop_kick_death_knockback() -> void:
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _disable_attack_hitbox_deferred() -> void:
	_set_bite_active(false)


func _disable_hurtbox_deferred() -> void:
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitoring", false)


func _after_hurt() -> void:
	if not dead:
		return
	if not is_instance_valid(sprite):
		_free_after_death_sfx()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		_continue_after_death_anim()


func _after_death() -> void:
	if not dead:
		return
	if not is_instance_valid(sprite):
		_free_after_death_sfx()
		return
	if sprite.animation != "death":
		return

	_continue_after_death_anim()


func _continue_after_death_anim() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite):
		_free_after_death_sfx()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_idle"):
		sprite.play("death_idle")
		await get_tree().create_timer(death_idle_delay).timeout
		if not is_inside_tree() or not dead:
			return
		if not is_instance_valid(sprite):
			_free_after_death_sfx()
			return

	_play_explode_or_free()


func _play_explode_or_free() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite):
		_free_after_death_sfx()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("explode"):
		sprite.frame = 0
		sprite.play("explode")
		if is_instance_valid(sfx_explode) and sfx_explode.stream:
			sfx_explode.play()
		sprite.animation_finished.connect(_after_explode, CONNECT_ONE_SHOT)
	else:
		_free_after_death_sfx()


func _after_explode() -> void:
	if not dead:
		return
	if not is_instance_valid(sprite):
		_free_after_death_sfx()
		return
	if sprite.animation != "explode":
		return
	_free_after_death_sfx()


func _free_after_death_sfx() -> void:
	if sfx_die and sfx_die.playing:
		await get_tree().create_timer(0.35).timeout
	queue_free()
