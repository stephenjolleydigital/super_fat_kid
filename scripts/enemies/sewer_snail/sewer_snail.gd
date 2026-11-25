extends CharacterBody2D

@export var projectile_scene: PackedScene = preload("res://scenes/enemies/SewerSnailProjectile.tscn")
@export var vomit_scene: PackedScene = preload("res://scenes/enemies/SewerSnailVomit.tscn")
@export var shell_scene: PackedScene = preload("res://scenes/enemies/SewerSnailShell.tscn")

@export var move_speed: float = 25.0
@export var gravity: float = 800.0
@export var start_direction: int = -1
@export var max_hp: int = 3
@export var idle_time: float = 1.5
@export var crawl_time: float = 3.0
@export var spit_cooldown: float = 7.0
@export var barf_cooldown: float = 4.0
@export var spit_weight: float = 0.35
@export var barf_weight: float = 1.0

## Per-enemy resistance (1.0 = full shared kick knockback). Same as Mall Cop.
const KICK_KNOCKBACK_RESISTANCE: float = 0.6

enum State { IDLE, CRAWL, SPIT_START, SPIT_RELEASE, BARF_START, BARF_RELEASE, HURT, DEAD }

var state: State = State.CRAWL
var direction: int = 1
var hp: int = 1
var dead: bool = false
## True while logically dead but still consuming local hitstop before death anims.
var fatal_hitstop_active: bool = false
var player_in_range: bool = false

var _state_timer: float = 0.0
var _spit_cooldown_timer: float = 0.0
var _barf_cooldown_timer: float = 0.0

var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false
var _sprite_offset_abs_x: float = 0.0
var _projectile_spawn_abs_x: float = 0.0
var _vomit_spawn_abs_x: float = 0.0
var _shell_spawn_abs_x: float = 0.0
var _barf_hitbox_abs_x: float = 0.0

## Horizontal velocity to apply when kick hitstop ends (0 = no knockback).
var _pending_kick_knockback_x: float = 0.0
## Nonfatal slide during HURT (crawl resumes only after hurt timer + slide).
var _kick_knockback_active: bool = false
## Sliding during death after kick fatal hitstop (patrol AI never resumes).
var _kick_death_knockback_active: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var hurtbox_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var player_detect: Area2D = get_node_or_null("PlayerDetect") as Area2D
@onready var projectile_spawn: Marker2D = get_node_or_null("ProjectileSpawn") as Marker2D
@onready var vomit_spawn: Marker2D = get_node_or_null("VomitSpawn") as Marker2D
@onready var shell_spawn: Marker2D = get_node_or_null("ShellSpawn") as Marker2D
@onready var barf_hitbox: Area2D = get_node_or_null("BarfHitbox") as Area2D
@onready var barf_hitbox_shape: CollisionShape2D = get_node_or_null("BarfHitbox/CollisionShape2D") as CollisionShape2D
@onready var sfx_slide: AudioStreamPlayer2D = get_node_or_null("SFX_Slide") as AudioStreamPlayer2D
@onready var sfx_spit: AudioStreamPlayer2D = get_node_or_null("SFX_Spit") as AudioStreamPlayer2D
@onready var sfx_barf: AudioStreamPlayer2D = get_node_or_null("SFX_Barf") as AudioStreamPlayer2D
@onready var sfx_hurt: AudioStreamPlayer2D = get_node_or_null("SFX_Hurt") as AudioStreamPlayer2D
@onready var sfx_retreat: AudioStreamPlayer2D = get_node_or_null("SFX_Retreat") as AudioStreamPlayer2D


func _ready() -> void:
	direction = -1 if start_direction < 0 else 1
	hp = maxi(1, max_hp)
	_spit_cooldown_timer = spit_cooldown
	_barf_cooldown_timer = barf_cooldown

	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if player_detect:
		if not player_detect.body_entered.is_connected(_on_player_detect_body_entered):
			player_detect.body_entered.connect(_on_player_detect_body_entered)
		if not player_detect.body_exited.is_connected(_on_player_detect_body_exited):
			player_detect.body_exited.connect(_on_player_detect_body_exited)

	_sprite_offset_abs_x = absf(sprite.offset.x)
	if projectile_spawn:
		_projectile_spawn_abs_x = absf(projectile_spawn.position.x)
	if vomit_spawn:
		_vomit_spawn_abs_x = absf(vomit_spawn.position.x)
	if shell_spawn:
		_shell_spawn_abs_x = absf(shell_spawn.position.x)
	if barf_hitbox:
		_barf_hitbox_abs_x = absf(barf_hitbox.position.x)

	_start_crawl()
	_update_facing()


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

	# After kick fatal hitstop: horizontal slide while death / shell sequence plays.
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

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
	if _spit_cooldown_timer > 0.0:
		_spit_cooldown_timer = maxf(0.0, _spit_cooldown_timer - delta)
	if _barf_cooldown_timer > 0.0:
		_barf_cooldown_timer = maxf(0.0, _barf_cooldown_timer - delta)

	# Nonfatal kick slide during HURT — skip state match so HURT does not zero X.
	if state == State.HURT and _kick_knockback_active:
		velocity.x = move_toward(velocity.x, 0.0, CombatTuning.PLAYER_KICK_KNOCKBACK_DECELERATION * delta)
		velocity.y = 0.0
		_update_slide_sfx()
		move_and_slide()
		if is_on_wall() or is_zero_approx(velocity.x):
			_kick_knockback_active = false
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_crawl()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			velocity.x = 0.0
			if not _try_start_attack() and _state_timer <= 0.0:
				_start_crawl()

		State.CRAWL:
			velocity.x = float(direction) * move_speed
			if not _try_start_attack() and _state_timer <= 0.0:
				_start_idle()

		State.SPIT_START:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_spit_release()

		State.SPIT_RELEASE:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_spit_cooldown_timer = spit_cooldown
				_start_crawl()

		State.BARF_START:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_start_barf_release()

		State.BARF_RELEASE:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_set_barf_hitbox_active(false)
				# Visual handoff: the vomit pile is baked into barf_release,
				# so the standalone hazard spawns only once that animation ends.
				_spawn_vomit()
				_barf_cooldown_timer = barf_cooldown
				_start_crawl()

		State.HURT:
			if not _kick_knockback_active:
				velocity.x = 0.0
			if _state_timer <= 0.0 and not _kick_knockback_active:
				_start_crawl()

		State.DEAD:
			velocity = Vector2.ZERO

	# The slide sound plays while the snail is in its normal movement state; it
	# starts once on entry, re-triggers only after the sample ends, and stops
	# the same frame the snail leaves the slide state. It does not gate movement.
	_update_slide_sfx()

	move_and_slide()
	if state == State.CRAWL:
		_turn_if_blocked()


func _turn_if_blocked() -> void:
	# Read this frame's collisions after moving. Only a wall in front causes a
	# turn; floor contact or a lingering contact behind us must not flip us back.
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if absf(normal.x) < 0.7 or normal.x * float(direction) >= 0.0:
			continue
		direction *= -1
		_update_facing()
		break


func _start_idle() -> void:
	state = State.IDLE
	_play_if_exists("idle")
	_state_timer = idle_time


func _start_crawl() -> void:
	state = State.CRAWL
	# Force-start the slide animation on entry rather than using _play_if_exists():
	# that helper skips play() when the sprite's current animation is already
	# named "slide" but stopped (e.g. the scene's default animation on spawn),
	# which would leave the snail moving on a frozen frame. Entry happens once
	# per movement, so this never restarts the animation every physics frame.
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("slide"):
		sprite.play("slide")
	_state_timer = crawl_time


func _try_start_attack() -> bool:
	if not player_in_range:
		return false

	var spit_ready := _spit_cooldown_timer <= 0.0 and projectile_scene != null
	var barf_ready := _barf_cooldown_timer <= 0.0 and vomit_scene != null
	var w_spit: float = maxf(0.0, spit_weight) if spit_ready else 0.0
	var w_barf: float = maxf(0.0, barf_weight) if barf_ready else 0.0
	var total := w_spit + w_barf
	if total <= 0.0:
		return false

	if randf() * total < w_spit:
		_start_spit()
	else:
		_start_barf()
	return true


func _start_spit() -> void:
	state = State.SPIT_START
	_play_if_exists("spit_start")
	_state_timer = _anim_duration("spit_start")


func _start_spit_release() -> void:
	state = State.SPIT_RELEASE
	_play_if_exists("spit_release")
	_spawn_projectile()
	_state_timer = _anim_duration("spit_release")


func _start_barf() -> void:
	state = State.BARF_START
	_play_if_exists("barf_start")
	_state_timer = _anim_duration("barf_start")


func _start_barf_release() -> void:
	state = State.BARF_RELEASE
	_play_if_exists("barf_release")
	# Play once exactly as barf_release begins; this transition happens a single
	# time per barf attack, so the cue never re-triggers during the attack.
	_play_sfx(sfx_barf)
	_set_barf_hitbox_active(true)
	_state_timer = _anim_duration("barf_release")


func _set_barf_hitbox_active(active: bool) -> void:
	if barf_hitbox == null:
		return
	if active:
		if not barf_hitbox.is_in_group("enemy_attack"):
			barf_hitbox.add_to_group("enemy_attack")
	else:
		if barf_hitbox.is_in_group("enemy_attack"):
			barf_hitbox.remove_from_group("enemy_attack")
	barf_hitbox.set_deferred("monitoring", active)
	barf_hitbox.set_deferred("monitorable", active)
	if is_instance_valid(barf_hitbox_shape):
		barf_hitbox_shape.set_deferred("disabled", not active)


func _spawn_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile: Node2D = projectile_scene.instantiate()
	if projectile == null:
		return

	projectile.set_meta("spawner_body", self)
	if "direction" in projectile:
		projectile.direction = direction

	_add_to_world(projectile)

	if projectile_spawn:
		projectile.global_position = projectile_spawn.global_position
	else:
		projectile.global_position = global_position

	# Fired exactly at the release event (spawn), so it plays once per shot.
	_play_sfx(sfx_spit)


func _spawn_vomit() -> void:
	if vomit_scene == null:
		return

	var vomit: Node2D = vomit_scene.instantiate()
	if vomit == null:
		return

	if "direction" in vomit:
		vomit.direction = direction

	_add_to_world(vomit)

	if vomit_spawn:
		vomit.global_position = vomit_spawn.global_position
	else:
		vomit.global_position = global_position


func _spawn_shell() -> void:
	if shell_scene == null:
		return

	var shell: Node2D = shell_scene.instantiate()
	if shell == null:
		return

	if "direction" in shell:
		shell.direction = direction

	var spawn_position := shell_spawn.global_position if shell_spawn else global_position
	var shell_parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	# Enter the world at the final position so the shell never starts at the origin.
	shell.position = shell_parent.to_local(spawn_position) if shell_parent is Node2D else spawn_position
	shell_parent.add_child(shell)


func _add_to_world(node: Node) -> void:
	var world := get_tree().current_scene
	if world:
		world.add_child(node)
	else:
		get_parent().add_child(node)


func _update_facing() -> void:
	# The spritesheet is authored facing right (head, mouth, and barf stream
	# on the right side of the unflipped frames): direction 1 shows the
	# unflipped art, direction -1 mirrors it horizontally.
	sprite.flip_h = direction < 0
	var mirror: float = float(direction)
	# The snail art sits off-center in its 128px frame; mirroring the offset
	# keeps the body centered on the node origin for both facings.
	sprite.offset.x = _sprite_offset_abs_x * mirror
	if projectile_spawn:
		projectile_spawn.position.x = _projectile_spawn_abs_x * mirror
	if vomit_spawn:
		vomit_spawn.position.x = _vomit_spawn_abs_x * mirror
	if shell_spawn:
		shell_spawn.position.x = _shell_spawn_abs_x * mirror
	if barf_hitbox:
		barf_hitbox.position.x = _barf_hitbox_abs_x * mirror


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
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()


func _stop_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.playing:
		p.stop()


func _update_slide_sfx() -> void:
	if not is_instance_valid(sfx_slide) or sfx_slide.stream == null:
		return
	var should_slide := state == State.CRAWL and not dead
	if should_slide:
		if not sfx_slide.playing:
			sfx_slide.play()
	elif sfx_slide.playing:
		sfx_slide.stop()


func _on_player_detect_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
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

	hp = maxi(0, hp - amount)
	if hp <= 0:
		_enter_fatal_hitstop()
	else:
		_hurt()


func _hurt() -> void:
	# Guard against replaying the cue when a hit lands while already reeling.
	var already_hurt := state == State.HURT
	_set_barf_hitbox_active(false)
	state = State.HURT
	_kick_knockback_active = false
	_stop_sfx(sfx_slide)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		sprite.frame = 0
		if hitstop_frames > 0:
			sprite.pause()
			_hitstop_sprite_paused = true
	_state_timer = _anim_duration("hurt")
	if not already_hurt:
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


## Logically dead + collision soft-off; physics stays on to consume hitstop on hurt frame 0.
func _enter_fatal_hitstop() -> void:
	dead = true
	fatal_hitstop_active = true
	_kick_knockback_active = false
	_set_barf_hitbox_active(false)
	_stop_sfx(sfx_slide)
	state = State.DEAD
	velocity = Vector2.ZERO

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


## Coil-into-shell death; kick applies stored slide when hitstop ends.
func _begin_death_sequence() -> void:
	# Retreat cue as the coil begins (same relative timing as legacy _die entry).
	_play_sfx(sfx_retreat)

	if not is_zero_approx(_pending_kick_knockback_x):
		velocity = Vector2(_pending_kick_knockback_x, 0.0)
		_pending_kick_knockback_x = 0.0
		_kick_death_knockback_active = true
	else:
		velocity = Vector2.ZERO
		_kick_death_knockback_active = false
		if is_instance_valid(body_shape):
			body_shape.set_deferred("disabled", true)
		set_physics_process(false)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
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


func _after_death() -> void:
	if not dead:
		return
	_kick_death_knockback_active = false
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	_spawn_shell()
	queue_free()
