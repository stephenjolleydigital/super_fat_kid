extends CharacterBody2D

@export var speed: float = 38.0
@export var gravity: float = 800.0
@export var turn_cooldown: float = 0.15
@export var max_hp: int = 1
@export var death_idle_delay: float = 0.75
@export var death_explode_idle_delay: float = 0.75

# Hedgehog art is authored facing LEFT by default.
# direction: -1 = left, 1 = right
@export var start_direction: int = -1

## Margin around the body used to wake the hedgehog before it scrolls into view.
## Larger = starts walking further off-screen. At speed 38, 32px is roughly 0.85s of lead.
@export var activation_lead_px: float = 32.0
## Uncheck to make this hedgehog patrol from level load instead of waiting for the camera.
@export var require_screen_activation: bool = true

## Sideways speed when spikes hurt the player; pushes away from the solid body center.
@export_range(0.0, 600.0, 1.0) var spike_knockback_speed: float = CombatTuning.ENEMY_HIT_KNOCKBACK_SPEED
## Upward speed when spikes hurt the player.
@export_range(0.0, 400.0, 1.0) var spike_knockback_up_speed: float = CombatTuning.ENEMY_HIT_KNOCKBACK_UP_SPEED

## Per-enemy resistance (1.0 = full shared kick knockback). Easy to retune later.
const KICK_KNOCKBACK_RESISTANCE: float = 1.0

var direction: int = -1
var turn_timer: float = 0.0
var dead: bool = false
var hp: int = 1
## True while logically dead but still consuming local hitstop before death anims.
var fatal_hitstop_active: bool = false

var _base_pivot_scale: Vector2 = Vector2.ONE
var _base_pivot_sign_x: float = 1.0
var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

## Horizontal velocity to apply when fatal kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Sliding during hurt/death after kick fatal hitstop.
var _kick_death_knockback_active: bool = false
## Patrol is gated until the camera gets close; one-shot, never re-armed.
var _activated: bool = false

@onready var pivot: Node2D = $Pivot
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var face_hitbox: Area2D = $Pivot/FaceHitBox
@onready var spike_hurtbox: Area2D = $Pivot/SpikeHurtBox
@onready var face_shape: CollisionShape2D = $Pivot/FaceHitBox/CollisionShape2D
@onready var spike_shape: CollisionShape2D = $Pivot/SpikeHurtBox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var sfx_death_explode: AudioStreamPlayer2D = $SFX_DeathExplode
@onready var sfx_disintegrate: AudioStreamPlayer2D = $SFX_Disintegrate


func _ready() -> void:
	direction = -1 if start_direction < 0 else 1
	hp = maxi(1, max_hp)
	spike_hurtbox.set_meta(&"hurt_knockback_provider", get_spike_knockback)

	# Cache authored pivot scale as the LEFT-facing baseline
	_base_pivot_scale = pivot.scale if pivot else Vector2.ONE
	_base_pivot_sign_x = 1.0 if _base_pivot_scale.x >= 0.0 else -1.0

	_update_facing()

	if face_hitbox and not face_hitbox.area_entered.is_connected(_on_face_hitbox_area_entered):
		face_hitbox.area_entered.connect(_on_face_hitbox_area_entered)

	_setup_screen_activation()

	if not require_screen_activation:
		_activate()
		return

	_play_dormant_animation()

	# screen_entered does not fire for a hedgehog that is already visible on the first
	# frame of the level, so catch that case once the viewport has settled.
	await get_tree().process_frame
	if is_instance_valid(self) and not _activated and screen_notifier.is_on_screen():
		_activate()


## Called only for confirmed player damage, using position at the moment of impact.
func get_spike_knockback(player_position: Vector2, fallback_direction: float) -> Vector2:
	return CombatTuning.enemy_hit_knockback(
		player_position, body_shape.global_position, fallback_direction,
		spike_knockback_speed, spike_knockback_up_speed
	)


func _setup_screen_activation() -> void:
	if not screen_notifier:
		return

	var body_rect := body_shape.shape as RectangleShape2D
	if body_rect:
		var half := body_rect.size * 0.5 + Vector2(activation_lead_px, activation_lead_px)
		screen_notifier.rect = Rect2(body_shape.position - half, half * 2.0)

	if not screen_notifier.screen_entered.is_connected(_activate):
		screen_notifier.screen_entered.connect(_activate)


func _play_dormant_animation() -> void:
	if not (sprite and sprite.sprite_frames):
		return
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	elif sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
		sprite.frame = 0
		sprite.pause()


## Begin patrolling. One-shot: leaving the screen later never re-freezes the hedgehog.
func _activate() -> void:
	if _activated or dead:
		return

	_activated = true

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func _physics_process(delta: float) -> void:
	# Fatal hold: stay on hurt frame 0 until local hitstop expires, then resume death anims.
	if fatal_hitstop_active:
		velocity = Vector2.ZERO
		if hitstop_frames > 0:
			hitstop_frames -= 1
			# Keep locked on hurt frame 0 for the whole hold (never advance during freeze).
			if sprite:
				if sprite.animation != &"hurt" and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
					sprite.play("hurt")
				sprite.frame = 0
				if not _hitstop_sprite_paused:
					sprite.pause()
					_hitstop_sprite_paused = true
			if hitstop_frames > 0:
				return
		# Do not resume walk/AI — resume hurt/death from frame 0.
		_hitstop_sprite_paused = false
		fatal_hitstop_active = false
		_begin_death_sequence()
		return

	# After kick fatal hitstop, slide while hurt/death anims play.
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

	if turn_timer > 0.0:
		turn_timer = maxf(0.0, turn_timer - delta)

	if not is_on_floor():
		velocity.y += gravity * delta

	# Still fall while dormant, so a hedgehog authored above the floor settles onto it
	# instead of hanging in the air until the player arrives.
	if not _activated:
		velocity.x = 0.0
		move_and_slide()
		return

	velocity.x = float(direction) * speed
	move_and_slide()

	if turn_timer <= 0.0 and is_on_wall():
		direction *= -1
		turn_timer = turn_cooldown
		_update_facing()


func _update_facing() -> void:
	# Flip the TRANSFORM so sprite + hitboxes flip together (Rat_Small pattern),
	# but treat authored orientation as LEFT-facing.
	if not pivot:
		return

	var sx := absf(_base_pivot_scale.x)
	# The hedgehog art is authored facing LEFT, but the authored scene scale can
	# still end up presenting the sprite as facing RIGHT depending on import/setup.
	# Map sign so the visual faces the movement direction:
	# - moving left (direction < 0) => face left
	# - moving right (direction > 0) => face right
	var target_sign := -_base_pivot_sign_x if direction < 0 else _base_pivot_sign_x
	pivot.scale = Vector2(sx * target_sign, _base_pivot_scale.y)


func _on_face_hitbox_area_entered(area: Area2D) -> void:
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
		# player_multiplier 1.0 until a kick knockback perk exists.
		_pending_kick_knockback_x = push_dir * CombatTuning.resolve_kick_knockback_speed(
			1.0, KICK_KNOCKBACK_RESISTANCE
		)
	else:
		_pending_kick_knockback_x = 0.0

	_take_damage(1)


func _take_damage(amount: int) -> void:
	if dead or fatal_hitstop_active:
		return

	# A dormant hedgehog can still be killed by a thrown apple; make sure it is out of
	# the waiting state before the hurt/death chain takes over.
	_activate()

	hp = maxi(0, hp - amount)

	if hp <= 0:
		_enter_fatal_hitstop()
	else:
		_hurt()


func _hurt() -> void:
	if not (sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")):
		return

	# Briefly pause patrol so hurt reads
	set_physics_process(false)
	velocity = Vector2.ZERO

	sprite.play("hurt")
	sprite.animation_finished.connect(_on_hurt_finished, CONNECT_ONE_SHOT)


func _on_hurt_finished() -> void:
	if dead or fatal_hitstop_active:
		return
	if not sprite or sprite.animation != "hurt":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

	set_physics_process(true)


## Logically dead + collision off, but physics stays on to consume hitstop on hurt frame 0.
func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	velocity = Vector2.ZERO
	_disable_body_collision_deferred()
	_disable_hitboxes_deferred()
	# Impact SFX at damage confirm (with hurt frame 0 + hitstop), not after the hold.
	if is_instance_valid(sfx_death) and sfx_death.stream:
		sfx_death.play()
	# Order: play hurt → force frame 0 → pause immediately (before any advance).
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


## Existing death anim / SFX / cleanup (previous _die body after marking dead).
func _begin_death_sequence() -> void:
	# Kick fatal → start horizontal slide; apple/other keep freeze-in-place death.
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
		# Physics stays on so decelerating slide runs during hurt/death anims.
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		set_physics_process(false)

	var has_hurt := sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")
	var has_death := sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death")

	if has_hurt and has_death:
		# Resume hurt from frame 0 (already showing during fatal hold); do not skip past it.
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_after_final_hurt, CONNECT_ONE_SHOT)
	elif has_death:
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _disable_body_collision_deferred() -> void:
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)


func _disable_hitboxes_deferred() -> void:
	# Avoid changing physics state inside callbacks; defer disables like Rat_Small.
	if is_instance_valid(face_shape):
		face_shape.set_deferred("disabled", true)
	if is_instance_valid(spike_shape):
		spike_shape.set_deferred("disabled", true)


func _after_final_hurt() -> void:
	if not dead:
		return
	if not sprite or sprite.animation != "hurt":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _after_death() -> void:
	if not dead:
		return
	if not sprite or sprite.animation != "death":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_idle"):
		sprite.play("death_idle")

	await get_tree().create_timer(death_idle_delay).timeout

	if not is_inside_tree() or not dead or not is_instance_valid(sprite):
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_explode"):
		if is_instance_valid(sfx_death_explode) and sfx_death_explode.stream:
			sfx_death_explode.play()
		sprite.play("death_explode")
		sprite.animation_finished.connect(_after_death_explode, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _after_death_explode() -> void:
	if not dead:
		return
	if not sprite or sprite.animation != "death_explode":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_explode_idle"):
		sprite.play("death_explode_idle")
		await get_tree().create_timer(death_explode_idle_delay).timeout
		if not is_inside_tree() or not dead or not is_instance_valid(sprite):
			return

	_play_death_explode_idle_disintegrate_or_free()


func _play_death_explode_idle_disintegrate_or_free() -> void:
	if not is_inside_tree() or not dead or not is_instance_valid(sprite):
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_explode_idle_disintegrate"):
		if is_instance_valid(sfx_disintegrate) and sfx_disintegrate.stream:
			sfx_disintegrate.play()
		sprite.frame = 0
		sprite.play("death_explode_idle_disintegrate")
		sprite.animation_finished.connect(_after_death_explode_idle_disintegrate, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _after_death_explode_idle_disintegrate() -> void:
	if not dead:
		return
	if not is_instance_valid(sprite) or sprite.animation != "death_explode_idle_disintegrate":
		return
	queue_free()
