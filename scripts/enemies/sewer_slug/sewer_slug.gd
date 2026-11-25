extends CharacterBody2D

@export var spit_scene: PackedScene = preload("res://scenes/enemies/SewerSlugSpit.tscn")
@export var slime_scene: PackedScene = preload("res://scenes/enemies/SewerSlugSlime.tscn")

@export var move_speed: float = 30.0
@export var gravity: float = 800.0
## Self-propelled crawl applies only on these inclusive move-animation frames.
const MOVE_CRAWL_FRAME_START: int = 0
const MOVE_CRAWL_FRAME_END: int = 3
const MOVE_SFX_FRAME: int = 1
## Pause on idle after one non-looping move cycle before crawling again.
@export var crawl_rest_duration: float = 0.6
@export var start_direction: int = 1
## Margin around the body that wakes the slug just before it enters the camera.
@export_range(0.0, 512.0, 1.0) var activation_lead_px: float = 32.0
## Uncheck to crawl immediately from level load.
@export var require_screen_activation: bool = true
@export var spit_cooldown: float = 3.0
@export var slime_drop_interval: float = 2.4
@export var max_hp: int = 2

## Per-enemy resistance (1.0 = full shared kick knockback). Easy to revert / retune.
const KICK_KNOCKBACK_RESISTANCE: float = 1.0

enum State { MOVE, SPIT_WINDUP, SPIT_RELEASE, HURT, DEAD }

var state: State = State.MOVE
var direction: int = 1
var hp: int = 1
var dead: bool = false
## True while logically dead but still consuming local hitstop before death anims.
var fatal_hitstop_active: bool = false
var player_in_range: bool = false
## One-shot activation: scrolling away never interrupts an encounter.
var _activated: bool = false

var _state_timer: float = 0.0
var _spit_cooldown_timer: float = 0.0
var _slime_drop_timer: float = 0.0
var _crawl_rest_timer: float = 0.0
## Rising-edge gate so a continuous world wall turns the slug once, not every frame.
var _was_blocked_by_environment: bool = false

var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false
var _mouth_marker_abs_x: float = 0.0

## Horizontal velocity to apply when kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Nonfatal slide during HURT (MOVE resumes only after hurt timer + slide).
var _kick_knockback_active: bool = false
## Sliding during death after kick fatal hitstop (MOVE / patrol AI never resumes).
var _kick_death_knockback_active: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var hurtbox_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var player_detect: Area2D = get_node_or_null("PlayerDetect") as Area2D
@onready var mouth_marker: Marker2D = get_node_or_null("MouthMarker") as Marker2D
@onready var slime_marker: Marker2D = get_node_or_null("SlimeMarker") as Marker2D
@onready var sfx_hurt: AudioStreamPlayer2D = get_node_or_null("SFX_Hurt") as AudioStreamPlayer2D
@onready var sfx_splat: AudioStreamPlayer2D = get_node_or_null("SFX_Splat") as AudioStreamPlayer2D
@onready var sfx_move: AudioStreamPlayer2D = get_node_or_null("SFX_Move") as AudioStreamPlayer2D
@onready var sfx_spit: AudioStreamPlayer2D = get_node_or_null("SFX_Spit") as AudioStreamPlayer2D


func _ready() -> void:
	direction = -1 if start_direction < 0 else 1
	hp = maxi(1, max_hp)
	_spit_cooldown_timer = spit_cooldown
	_slime_drop_timer = slime_drop_interval
	_ignore_existing_player_collisions.call_deferred()

	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if player_detect:
		if not player_detect.body_entered.is_connected(_on_player_detect_body_entered):
			player_detect.body_entered.connect(_on_player_detect_body_entered)
		if not player_detect.body_exited.is_connected(_on_player_detect_body_exited):
			player_detect.body_exited.connect(_on_player_detect_body_exited)

	if mouth_marker:
		_mouth_marker_abs_x = absf(mouth_marker.position.x)

	if sprite and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	if sprite and not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)

	_update_facing()
	_play_if_exists("idle")
	_setup_screen_activation()
	if not require_screen_activation:
		_activate()
		return
	# Also handle slugs already visible when the level opens.
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
	_start_move_cycle()


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


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

	# After kick fatal hitstop: horizontal slide while death/splat play.
	# Never resumes MOVE / spit / slime patrol AI.
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
	elif not is_zero_approx(_pending_kick_knockback_x) and state == State.HURT:
		# No hitstop this frame: start nonfatal slide after damage confirm.
		_activate_pending_kick_knockback_if_any()

	if not _activated:
		velocity = Vector2.ZERO
		return

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
	if _spit_cooldown_timer > 0.0:
		_spit_cooldown_timer = maxf(0.0, _spit_cooldown_timer - delta)
	if _slime_drop_timer > 0.0:
		_slime_drop_timer = maxf(0.0, _slime_drop_timer - delta)
	if _crawl_rest_timer > 0.0:
		_crawl_rest_timer = maxf(0.0, _crawl_rest_timer - delta)

	# Nonfatal kick slide during HURT — skip state match so HURT does not zero X.
	if state == State.HURT and _kick_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		move_and_slide()
		if is_on_wall() or is_zero_approx(velocity.x):
			_kick_knockback_active = false
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_move_cycle()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.MOVE:
			if _crawl_rest_timer <= 0.0 and sprite and sprite.animation == &"idle":
				_start_move_cycle()

			var crawling := (
				sprite != null
				and sprite.animation == &"move"
				and sprite.frame >= MOVE_CRAWL_FRAME_START
				and sprite.frame <= MOVE_CRAWL_FRAME_END
			)
			velocity.x = float(direction) * move_speed if crawling else 0.0

			if _slime_drop_timer <= 0.0:
				_spawn_slime()
				_slime_drop_timer = slime_drop_interval

			if player_in_range and _spit_cooldown_timer <= 0.0:
				_start_spit_windup()

		State.SPIT_WINDUP:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_spit_release()

		State.SPIT_RELEASE:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_move_cycle()
				_spit_cooldown_timer = spit_cooldown

		State.HURT:
			if not _kick_knockback_active:
				velocity.x = 0.0
			if _state_timer <= 0.0 and not _kick_knockback_active:
				_start_move_cycle()

		State.DEAD:
			velocity = Vector2.ZERO

	# Capture X before slide so actor-only blocks can undo push-fight jitter.
	var move_x_before: float = global_position.x
	move_and_slide()

	# Facing comes only from persistent `direction` via _update_facing().
	# Turn on the rising edge of a true world wall — never while jammed into
	# the player or another enemy (those share the slug's collision layer).
	var on_world_wall: bool = _is_blocked_by_environment()
	if state == State.MOVE:
		if on_world_wall and not _was_blocked_by_environment:
			direction *= -1
			_update_facing()
		elif is_on_wall() and not on_world_wall:
			global_position.x = move_x_before
	_was_blocked_by_environment = on_world_wall


## True only when a wall opposing `direction` comes from level geometry, and no
## opposing CharacterBody2D (player/enemy) is also blocking this frame. Tile
## corners during actor jams must not count as patrol turns.
func _is_blocked_by_environment() -> bool:
	var hit_world: bool = false
	var hit_actor: bool = false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var normal: Vector2 = collision.get_normal()
		if absf(normal.x) < 0.7:
			continue
		if normal.x * float(direction) >= 0.0:
			continue
		var collider: Object = collision.get_collider()
		if collider is CharacterBody2D:
			hit_actor = true
		elif collider is Node and (collider as Node).is_in_group("player"):
			hit_actor = true
		else:
			hit_world = true
	if hit_actor:
		return false
	return hit_world


func _start_spit_windup() -> void:
	_crawl_rest_timer = 0.0
	state = State.SPIT_WINDUP
	_play_if_exists("spit_windup")
	_state_timer = _anim_duration("spit_windup")


func _start_spit_release() -> void:
	state = State.SPIT_RELEASE
	_play_if_exists("spit_release")
	_spawn_spit()
	_state_timer = _anim_duration("spit_release")


func _spawn_spit() -> void:
	if spit_scene == null:
		return

	var spit: Node2D = spit_scene.instantiate()
	if spit == null:
		return

	spit.set_meta("spawner_body", self)

	if "direction" in spit:
		spit.direction = direction

	var world := get_tree().current_scene
	if world:
		world.add_child(spit)
	else:
		get_parent().add_child(spit)

	if mouth_marker:
		spit.global_position = mouth_marker.global_position
	else:
		spit.global_position = global_position

	_play_sfx(sfx_spit)


func _spawn_slime() -> void:
	if slime_scene == null:
		return

	var slime: Node2D = slime_scene.instantiate()
	if slime == null:
		return

	var world := get_tree().current_scene
	if world:
		world.add_child(slime)
	else:
		get_parent().add_child(slime)

	if slime_marker:
		slime.global_position = slime_marker.global_position + Vector2(0, 1)
	else:
		slime.global_position = global_position + Vector2(0, 11)


func _update_facing() -> void:
	sprite.flip_h = direction < 0
	if mouth_marker:
		mouth_marker.position.x = _mouth_marker_abs_x * float(direction)


func _anim_duration(anim_name: String) -> float:
	if not (sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name)):
		return 0.2
	var count: int = sprite.sprite_frames.get_frame_count(anim_name)
	var fps: float = sprite.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		fps = 12.0
	return maxf(0.05, float(count) / fps)


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()


func _on_sprite_frame_changed() -> void:
	if dead or fatal_hitstop_active:
		return
	if sprite == null or sprite.animation != &"move":
		return
	if sprite.frame != MOVE_SFX_FRAME:
		return
	_play_sfx(sfx_move)


func _start_move_cycle() -> void:
	_crawl_rest_timer = 0.0
	state = State.MOVE
	_play_if_exists("move")


func _on_sprite_animation_finished() -> void:
	if dead or fatal_hitstop_active or state != State.MOVE:
		return
	if sprite == null or sprite.animation != &"move":
		return
	_play_if_exists("idle")
	_crawl_rest_timer = crawl_rest_duration


## Keep terrain collision, but never let the slug support or block the player.
func _ignore_existing_player_collisions() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		_ignore_player_body(player)


func _ignore_player_body(body: Node) -> void:
	if body is PhysicsBody2D:
		add_collision_exception_with(body)
		body.add_collision_exception_with(self)


func _on_player_detect_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_ignore_player_body(body)
		player_in_range = true


func _on_player_detect_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or fatal_hitstop_active:
		return
	if not area.is_in_group("player_attack"):
		return

	# Kick-only knockback: KickHitbox vs Apple's DamageArea.
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


func _take_damage(amount: int) -> void:
	if dead or fatal_hitstop_active:
		return

	# An attack reaching an offscreen slug starts its encounter too.
	_activate()
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_enter_fatal_hitstop()
	else:
		# Keep kick pending for nonfatal slide after hitstop (Apple already cleared it).
		_hurt()


func _hurt() -> void:
	_crawl_rest_timer = 0.0
	state = State.HURT
	_kick_knockback_active = false
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		if hitstop_frames > 0:
			sprite.pause()
			_hitstop_sprite_paused = true
	_state_timer = _anim_duration("hurt")
	_play_sfx(sfx_hurt)


func _activate_pending_kick_knockback_if_any() -> void:
	if dead or fatal_hitstop_active:
		return
	if state != State.HURT:
		return
	if is_zero_approx(_pending_kick_knockback_x):
		return
	velocity.x = _pending_kick_knockback_x
	velocity.y = 0.0
	_kick_knockback_active = true
	_pending_kick_knockback_x = 0.0


## Logically dead + collision soft-off, physics stays on to consume hitstop on hurt frame 0.
func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	state = State.DEAD
	velocity = Vector2.ZERO
	_crawl_rest_timer = 0.0

	_play_sfx(sfx_hurt)

	contact_hitbox.remove_from_group("enemy_attack")
	contact_hitbox.set_deferred("monitorable", false)
	contact_hitbox_shape.set_deferred("disabled", true)

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


## Existing hurt → death → splat chain; kick applies stored slide when hitstop ends.
func _begin_death_sequence() -> void:
	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		set_physics_process(false)

	var has_hurt := sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt")
	var has_death := sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death")

	if has_hurt and has_death:
		sprite.frame = 0
		sprite.play()
		sprite.animation_finished.connect(_after_final_hurt, CONNECT_ONE_SHOT)
	elif has_death:
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		_after_death()


func _stop_kick_death_knockback() -> void:
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _after_final_hurt() -> void:
	if not dead:
		return
	if sprite.animation != "hurt":
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.animation_finished.connect(_after_death, CONNECT_ONE_SHOT)
	else:
		_after_death()


func _after_death() -> void:
	if not dead:
		return
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("splat"):
		if is_instance_valid(sfx_splat) and sfx_splat.stream:
			sfx_splat.play()
		sprite.play("splat")
		sprite.animation_finished.connect(_after_splat, CONNECT_ONE_SHOT)
		return
	queue_free()


func _after_splat() -> void:
	if not dead:
		return
	if sprite.animation != "splat":
		return
	queue_free()
