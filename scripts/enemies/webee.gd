extends CharacterBody2D

## Sprite art faces RIGHT by default.
## direction: 1 = facing right, -1 = facing left.
##
## Web from WebSpawn shoots forward (same as direction).
## Stinger from StingerSpawn shoots backward (-direction).

@export var gravity: float = 800.0
@export var start_direction: int = -1
@export var hop_forward_speed: float = 70.0
@export var hop_up_speed: float = -340.0
@export var hop_cooldown: float = 0.35
@export var attack_cooldown: float = 1.5
@export var max_hp: int = 1
@export var death_hold_duration: float = 0.3
@export var web_projectile_scene: PackedScene = preload("res://scenes/enemies/WebeeWebProjectile.tscn")
@export var stinger_projectile_scene: PackedScene = preload("res://scenes/enemies/WebeeStingerProjectile.tscn")

## Per-enemy resistance (1.0 = full shared kick knockback). Easy to retune later.
const KICK_KNOCKBACK_RESISTANCE: float = 1.0

enum State { IDLE, JUMP_START, AIR, LAND, ATTACK_WINDUP, ATTACK_WEB_RELEASE, ATTACK_STINGER_RELEASE, DEAD }

var state: State = State.IDLE
var direction: int = 1
var hp: int = 1
var dead: bool = false
var fatal_hitstop_active: bool = false
var player_in_range: bool = false

## One-shot activation: leaving the screen never interrupts an encounter.
var _activated: bool = false

var _hop_timer: float = 0.0
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _web_spawned_this_attack: bool = false
var _stinger_spawned_this_attack: bool = false
var _use_web_attack_next: bool = true

var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

## Horizontal velocity to apply when fatal kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Sliding during death after kick fatal hitstop (hop/attack AI never resumes).
var _kick_death_knockback_active: bool = false

var _web_spawn_base_x: float = 0.0
var _stinger_spawn_base_x: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var player_detect: Area2D = $PlayerDetect
@onready var activation_region: VisibleOnScreenNotifier2D = $ActivationRegion
@onready var web_spawn: Marker2D = $WebSpawn
@onready var stinger_spawn: Marker2D = $StingerSpawn
@onready var sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var sfx_land: AudioStreamPlayer2D = $SFX_Land
@onready var sfx_web_shoot: AudioStreamPlayer2D = $SFX_WebShoot
@onready var sfx_stinger_shoot: AudioStreamPlayer2D = $SFX_StingerShoot
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var sfx_dissolve: AudioStreamPlayer2D = $SFX_Dissolve


func _ready() -> void:
	direction = -1 if start_direction < 0 else 1
	hp = maxi(1, max_hp)
	_hop_timer = hop_cooldown

	if web_spawn:
		_web_spawn_base_x = web_spawn.position.x
	if stinger_spawn:
		_stinger_spawn_base_x = stinger_spawn.position.x

	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if not player_detect.body_entered.is_connected(_on_player_detect_body_entered):
		player_detect.body_entered.connect(_on_player_detect_body_entered)
	if not player_detect.body_exited.is_connected(_on_player_detect_body_exited):
		player_detect.body_exited.connect(_on_player_detect_body_exited)

	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)

	_update_facing()
	_play_if_exists("idle")
	activation_region.screen_entered.connect(_activate)
	# Visibility is updated after entering the tree; include initially visible Webees.
	await get_tree().process_frame
	if is_instance_valid(self) and activation_region.is_on_screen():
		_activate()


func _activate() -> void:
	if _activated or dead:
		return
	_activated = true
	_hop_timer = hop_cooldown


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func _physics_process(delta: float) -> void:
	if fatal_hitstop_active:
		velocity = Vector2.ZERO
		if hitstop_frames > 0:
			hitstop_frames -= 1
			if sprite:
				if sprite.animation != &"death" and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
					sprite.play("death")
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

	# After kick fatal hitstop: horizontal slide while death/dissolve play.
	# Never enters hop/attack match AI (dead stays true, state stays DEAD).
	if dead and _kick_death_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		# Stop cleanly on walls (no jitter / bounce).
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

	# Dormant Webees settle onto the floor without running movement/attack AI.
	# Damage and death handling above remain active before the camera arrives.
	if not _activated:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.JUMP_START:
			_process_jump_start()
		State.AIR:
			_process_air()
		State.LAND:
			_process_land(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_WEB_RELEASE:
			_process_attack_web_release(delta)
		State.ATTACK_STINGER_RELEASE:
			_process_attack_stinger_release(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO

	if _hop_timer > 0.0:
		_hop_timer = maxf(0.0, _hop_timer - delta)
		_play_if_exists("idle")
		return

	if not is_on_floor():
		_play_if_exists("idle")
		return

	if player_in_range and _attack_cooldown_timer <= 0.0:
		_start_attack_windup()
		return

	_start_jump()


func _process_jump_start() -> void:
	velocity = Vector2.ZERO
	_play_if_exists("jump_start")


func _process_air() -> void:
	if is_on_wall():
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

	state = State.IDLE
	_hop_timer = hop_cooldown
	_play_if_exists("idle")

	if is_on_wall():
		direction *= -1
		_update_facing()


func _process_attack_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_if_exists("attack_windup")

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		return

	if _use_web_attack_next:
		_start_attack_web_release()
	else:
		_start_attack_stinger_release()


func _process_attack_web_release(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_if_exists("attack_web_release")

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		return

	_finish_attack()


func _process_attack_stinger_release(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_if_exists("attack_stinger_release")

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		return

	_finish_attack()


func _start_attack_windup() -> void:
	state = State.ATTACK_WINDUP
	velocity = Vector2.ZERO
	_web_spawned_this_attack = false
	_stinger_spawned_this_attack = false
	_play_if_exists("attack_windup")
	_state_timer = _anim_duration("attack_windup")


func _start_attack_web_release() -> void:
	state = State.ATTACK_WEB_RELEASE
	velocity = Vector2.ZERO
	_web_spawned_this_attack = false
	_play_if_exists("attack_web_release")
	_state_timer = _anim_duration("attack_web_release")


func _start_attack_stinger_release() -> void:
	state = State.ATTACK_STINGER_RELEASE
	velocity = Vector2.ZERO
	_stinger_spawned_this_attack = false
	_play_if_exists("attack_stinger_release")
	_state_timer = _anim_duration("attack_stinger_release")


func _finish_attack() -> void:
	state = State.IDLE
	_attack_cooldown_timer = attack_cooldown
	_hop_timer = hop_cooldown
	_use_web_attack_next = not _use_web_attack_next
	_play_if_exists("idle")


func _on_sprite_frame_changed() -> void:
	if dead or not _activated:
		return
	if sprite.frame != 1:
		return

	if state == State.ATTACK_WEB_RELEASE and sprite.animation == "attack_web_release":
		if _web_spawned_this_attack:
			return
		_web_spawned_this_attack = true
		_spawn_web()
		return

	if state == State.ATTACK_STINGER_RELEASE and sprite.animation == "attack_stinger_release":
		if _stinger_spawned_this_attack:
			return
		_stinger_spawned_this_attack = true
		_spawn_stinger()


func _spawn_web() -> void:
	if web_projectile_scene == null or web_spawn == null:
		return

	var web: Node2D = web_projectile_scene.instantiate()
	if web == null:
		return

	web.set_meta("spawner_body", self)

	if web.has_method("set_direction_x"):
		web.set_direction_x(get_web_shoot_direction())

	var world := get_tree().current_scene
	if world:
		world.add_child(web)
	else:
		get_parent().add_child(web)

	web.global_position = web_spawn.global_position
	_play_sfx(sfx_web_shoot)


func _spawn_stinger() -> void:
	if stinger_projectile_scene == null or stinger_spawn == null:
		return

	var stinger: Node2D = stinger_projectile_scene.instantiate()
	if stinger == null:
		return

	stinger.set_meta("spawner_body", self)

	if stinger.has_method("set_direction_x"):
		stinger.set_direction_x(get_stinger_shoot_direction())

	var world := get_tree().current_scene
	if world:
		world.add_child(stinger)
	else:
		get_parent().add_child(stinger)

	stinger.global_position = stinger_spawn.global_position
	_play_sfx(sfx_stinger_shoot)


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


func _is_standing_on_player() -> bool:
	if not is_on_floor():
		return false

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var normal := collision.get_normal()
		if normal.dot(Vector2.UP) < 0.7:
			continue

		var collider := collision.get_collider()
		if collider == null:
			continue

		if collider.is_in_group("player"):
			return true

		var parent: Node = collider.get_parent()
		if parent != null and parent.is_in_group("player"):
			return true

	return false


func _start_land() -> void:
	if _is_standing_on_player():
		state = State.AIR
		velocity = Vector2(float(direction) * hop_forward_speed, hop_up_speed)
		_play_if_exists("jump_up")
		return

	state = State.LAND
	velocity = Vector2.ZERO
	_state_timer = _anim_duration("land")
	_play_if_exists("land")
	_play_sfx(sfx_land)


func _update_facing() -> void:
	sprite.flip_h = direction < 0

	if web_spawn:
		web_spawn.position.x = _web_spawn_base_x * float(direction)
	if stinger_spawn:
		stinger_spawn.position.x = _stinger_spawn_base_x * float(direction)


func get_web_shoot_direction() -> int:
	return direction


func get_stinger_shoot_direction() -> int:
	return -direction


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


func _on_player_detect_body_entered(body: Node2D) -> void:
	if dead:
		return
	if body.is_in_group("player"):
		player_in_range = true


func _on_player_detect_body_exited(body: Node2D) -> void:
	if dead:
		return
	if body.is_in_group("player"):
		player_in_range = false


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

	hp = maxi(0, hp - amount)
	if hp <= 0:
		_enter_fatal_hitstop()


func _enter_fatal_hitstop() -> void:
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
	# Keep body collision during kick knockback so walls can stop the slide.
	# Apple / non-kick fatal still disables body immediately (unchanged).
	if is_zero_approx(_pending_kick_knockback_x) and is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)

	if sprite.animation_finished.is_connected(_on_jump_start_finished):
		sprite.animation_finished.disconnect(_on_jump_start_finished)

	_play_sfx(sfx_death)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


func _begin_death_sequence() -> void:
	# Kick fatal → horizontal slide while death plays; apple keeps freeze-in-place.
	# Hop / attack AI never resumes (dead + State.DEAD; only knockback branch runs).
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		set_physics_process(false)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation("dissolve"):
		_start_dissolve()
	else:
		queue_free()


func _stop_kick_death_knockback() -> void:
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _on_death_anim_finished() -> void:
	if not dead or sprite.animation != "death":
		return

	sprite.pause()
	get_tree().create_timer(death_hold_duration).timeout.connect(_on_death_hold_finished, CONNECT_ONE_SHOT)


func _on_death_hold_finished() -> void:
	if not dead:
		return
	_start_dissolve()


func _start_dissolve() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("dissolve"):
		_play_sfx(sfx_dissolve)
		sprite.play("dissolve")
		sprite.animation_finished.connect(_on_dissolve_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_dissolve_finished() -> void:
	if not dead or sprite.animation != "dissolve":
		return
	queue_free()
