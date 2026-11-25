extends CharacterBody2D

@export var bullet_scene: PackedScene = preload("res://scenes/enemies/MallCopBullet.tscn")
@export var direction: int = -1
@export var death_idle_delay: float = 0.75

const MAX_HP := 2
const QUARTER_SCENE := preload("res://scenes/pickups/Pickup_Quarter.tscn")
const QUARTER_DROP_CHANCE := 0.25

## Heavier than small enemies; ~40% of full shared kick knockback.
const KICK_KNOCKBACK_RESISTANCE: float = 0.6

var hp: int = MAX_HP
var dead: bool = false
## True while logically dead but still consuming local hitstop before death anims.
var fatal_hitstop_active: bool = false
var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

## Horizontal velocity to apply when kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Nonfatal slide during hurt (attacks resume only after hurt + slide).
var _kick_knockback_active: bool = false
## Fatal slide during death (attacks never resume).
var _kick_death_knockback_active: bool = false
## True after nonfatal hurt anim finishes; used to gate shoot recovery with knockback.
var _hurt_anim_done: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var draw_timer: Timer = $DrawTimer
@onready var short_cooldown: Timer = $ShortCooldown
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_gun: AudioStreamPlayer2D = $SFX_Gun
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var sfx_explode: AudioStreamPlayer2D = $SfxExplode


func _ready() -> void:
	if not draw_timer.timeout.is_connected(_on_draw_timer_timeout):
		draw_timer.timeout.connect(_on_draw_timer_timeout)

	if not short_cooldown.timeout.is_connected(_on_short_cooldown_timeout):
		short_cooldown.timeout.connect(_on_short_cooldown_timeout)

	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	_start_draw_sequence()


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func _start_draw_sequence() -> void:
	if dead:
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("draw"):
		sprite.play("draw")

	draw_timer.stop()
	draw_timer.start()


func _on_draw_timer_timeout() -> void:
	if dead:
		return

	_shoot()

	short_cooldown.stop()
	short_cooldown.start()


func _shoot() -> void:
	if dead:
		return

	if bullet_scene == null:
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	bullet.global_position = muzzle.global_position

	if "direction" in bullet:
		bullet.direction = direction

	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(bullet)
	else:
		add_child(bullet)

	if is_instance_valid(sfx_gun) and sfx_gun.stream:
		sfx_gun.play()

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("shoot"):
		sprite.play("shoot")


func _on_short_cooldown_timeout() -> void:
	if dead:
		return

	_start_draw_sequence()


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
		var push_dir: float = sign(global_position.x - area.global_position.x)
		if push_dir == 0.0:
			push_dir = float(-direction)
		_pending_kick_knockback_x = push_dir * CombatTuning.resolve_kick_knockback_speed(
			1.0, KICK_KNOCKBACK_RESISTANCE
		)
	else:
		_pending_kick_knockback_x = 0.0

	_take_damage(1)


func _physics_process(delta: float) -> void:
	# Fatal hold: stationary on hurt frame 0 until local hitstop expires.
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

	# After kick fatal hitstop: short horizontal slide while death anims play.
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
		# Completely stationary for synchronized local hitstop.
		velocity = Vector2.ZERO
		hitstop_frames -= 1
		if not _hitstop_sprite_paused:
			sprite.pause()
			_hitstop_sprite_paused = true
		if hitstop_frames > 0:
			return
	if _hitstop_sprite_paused:
		sprite.play()
		_hitstop_sprite_paused = false
		_activate_pending_kick_knockback_if_any()
	elif not is_zero_approx(_pending_kick_knockback_x):
		# No hitstop this frame: start nonfatal slide after damage confirm.
		_activate_pending_kick_knockback_if_any()

	# Nonfatal kick slide during hurt.
	if _kick_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		if is_on_wall() or is_zero_approx(velocity.x):
			_kick_knockback_active = false
			velocity.x = 0.0
			_try_resume_after_nonfatal_hurt()
		return


func _take_damage(amount: int) -> void:
	if dead or fatal_hitstop_active:
		return

	hp = maxi(0, hp - amount)

	if hp <= 0:
		_enter_fatal_hitstop()
	else:
		_nonfatal_hurt()


func _nonfatal_hurt() -> void:
	if not (sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")):
		return

	# Pause shooting loop during nonfatal hurt so the animation is visible.
	draw_timer.stop()
	short_cooldown.stop()
	_hurt_anim_done = false
	_kick_knockback_active = false

	if is_instance_valid(sfx_hurt) and sfx_hurt.stream:
		sfx_hurt.play()

	sprite.play("hurt")
	sprite.frame = 0
	if hitstop_frames > 0:
		sprite.pause()
		_hitstop_sprite_paused = true
	sprite.animation_finished.connect(_on_nonfatal_hurt_finished, CONNECT_ONE_SHOT)


func _on_nonfatal_hurt_finished() -> void:
	if dead or fatal_hitstop_active:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite) or sprite.animation != "hurt":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt_recover"):
		sprite.play("hurt_recover")
		sprite.animation_finished.connect(_on_nonfatal_hurt_recover_finished, CONNECT_ONE_SHOT)
	else:
		_hurt_anim_done = true
		_try_resume_after_nonfatal_hurt()


func _on_nonfatal_hurt_recover_finished() -> void:
	if dead or fatal_hitstop_active:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite) or sprite.animation != "hurt_recover":
		return
	_hurt_anim_done = true
	_try_resume_after_nonfatal_hurt()


func _try_resume_after_nonfatal_hurt() -> void:
	if dead or fatal_hitstop_active:
		return
	if not _hurt_anim_done:
		return
	if _kick_knockback_active:
		return
	_hurt_anim_done = false
	_start_draw_sequence()


func _activate_pending_kick_knockback_if_any() -> void:
	if dead or fatal_hitstop_active:
		return
	if is_zero_approx(_pending_kick_knockback_x):
		return
	velocity.x = _pending_kick_knockback_x
	velocity.y = 0.0
	_kick_knockback_active = true
	_pending_kick_knockback_x = 0.0


## Logically dead; physics stays on to consume hitstop on hurt frame 0.
func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	_kick_knockback_active = false
	_hurt_anim_done = false
	velocity = Vector2.ZERO

	draw_timer.stop()
	short_cooldown.stop()

	if is_instance_valid(sfx_death) and sfx_death.stream:
		sfx_death.play()

	if is_instance_valid(hurtbox_shape):
		hurtbox_shape.set_deferred("disabled", true)
	# Keep body during kick knockback so walls can stop the slide; apple disables now.
	if is_zero_approx(_pending_kick_knockback_x) and is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


## Existing hurt → death chain; kick applies stored slide when hitstop ends.
func _begin_death_sequence() -> void:
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		_disable_body_collision()
		set_physics_process(false)

	var has_hurt := sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")
	var has_death := sprite.sprite_frames and sprite.sprite_frames.has_animation("death")

	if has_hurt and has_death:
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_on_final_hurt_finished, CONNECT_ONE_SHOT)
	elif has_death:
		sprite.play("death")
		sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_continue_after_death_anim()


func _stop_kick_death_knockback() -> void:
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	_disable_body_collision()
	set_physics_process(false)


func _disable_body_collision() -> void:
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)


func _on_final_hurt_finished() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite) or sprite.animation != "hurt":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_continue_after_death_anim()


func _on_death_anim_finished() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite) or sprite.animation != "death":
		return

	_continue_after_death_anim()


func _continue_after_death_anim() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite):
		_after_death()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death_idle"):
		sprite.play("death_idle")
		await get_tree().create_timer(death_idle_delay).timeout
		if not is_inside_tree():
			return
		if not dead:
			return
		if not is_instance_valid(sprite):
			_after_death()
			return

	_play_explode_or_free()


func _play_explode_or_free() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite):
		_after_death()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("explode"):
		sprite.frame = 0
		sprite.play("explode")
		if is_instance_valid(sfx_explode) and sfx_explode.stream:
			sfx_explode.play()
		sprite.animation_finished.connect(_after_explode, CONNECT_ONE_SHOT)
	else:
		_after_death()


func _after_explode() -> void:
	if not dead:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(sprite):
		_after_death()
		return
	if sprite.animation != "explode":
		return
	_after_death()


func _try_drop_quarter() -> void:
	if QUARTER_SCENE == null:
		return

	if randf() > QUARTER_DROP_CHANCE:
		return

	var quarter := QUARTER_SCENE.instantiate()
	if quarter == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(quarter)
	else:
		get_parent().add_child(quarter)

	quarter.global_position = global_position + Vector2(0, 24)


func _after_death() -> void:
	# Guaranteed: dead body never remains an invisible world blocker.
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	_disable_body_collision()
	_try_drop_quarter()
	queue_free()
