extends CharacterBody2D

# --- CONSTANTS ---
const SPEED := 120.0

# --- RUN TUNING ---
const RUN_SPEED := 190.0
const RUN_ACCEL := 650.0
const RUN_DECEL := 800.0
const RUN_TURN_DECEL := 1230.0
const RUN_WINDUP_DECEL := 405.0
const RUN_LAND_DECEL := 520.0
# Matches InputMap deadzone on ui_left / ui_right (controller stick).
const MOVEMENT_INPUT_DEADZONE := 0.5

const AIR_CONTROL := 0.35
const JUMP_FORCE := -250.0
const GRAVITY := 700.0
const FALL_MULTIPLIER := 2.1
const JUMP_PEAK_SPEED := 50.0
const BLASTER_PROJECTILE := preload("res://scenes/combat/BlasterProjectile.tscn")
const BLASTER_SMOKE := preload("res://scenes/effects/BlasterMuzzleSmoke.tscn")
const BLASTER_RECOIL_SPEED := 60.0
const RECOIL_DECEL := 400.0
const BLASTER_GROUND_MUZZLE := Vector2(29, -6)
const BLASTER_AIR_MUZZLE := Vector2(29, -6)
const FRICTION := 850.0
const DOUBLE_JUMP_HORIZONTAL := 100.0
const DOUBLE_JUMP_BOOST_DURATION := 0.12

const WallMovement = preload("res://scripts/player/player_wall_movement.gd")
const MovementResource = preload("res://scripts/player/player_resource.gd")

# Disabled until the Gnome curse (or the isolated resource playtest) enables it.
const STAMINA_CURSE_EFFECT := preload("res://scripts/effects/player_stamina_curse.gd")
var curse_sequence_active: bool = false
var movement_resource := MovementResource.new()
var resource_running_carry: bool = false
var _resource_suspended_this_tick: bool = false
const RESOURCE_KICK_BUFFER_DURATION := 0.1
var resource_kick_buffer_time: float = 0.0

@export_group("Fart cloud")
## Cloud center relative to the player when facing right; X mirrors when facing left.
@export var fart_cloud_offset: Vector2 = Vector2(-20, 10)

@export_group("Jump forgiveness")
@export_range(0.0, 0.3, 0.01) var jump_buffer_duration: float = 0.12
@export_range(0.0, 0.3, 0.01) var ground_coyote_duration: float = 0.10
@export_range(0.1, 1.0, 0.05) var jump_release_speed_ratio: float = 0.5
@export_range(0.0, 40.0, 1.0) var ground_jump_minimum_rise: float = 24.0
@export_group("Wall movement")
# Normal falls are uncapped; this is an independent initial playtest value.
@export_range(1.0, 400.0, 1.0) var wall_slide_speed: float = 120.0
@export_range(100.0, 10000.0, 100.0) var wall_slide_deceleration: float = 3000.0
@export_range(0.1, 3.0, 0.05) var wall_jump_horizontal_multiplier: float = 1.1
@export_range(0.1, 2.0, 0.05) var wall_jump_vertical_multiplier: float = 1.1
@export_range(0.0, 0.3, 0.01) var wall_jump_protection: float = 0.16
@export_range(0.01, 0.2, 0.01) var wall_cling_cue_duration: float = 0.05
@export_range(0.01, 0.3, 0.01) var wall_jump_recovery: float = 0.10
@export_range(0.0, 0.3, 0.01) var wall_coyote_duration: float = 0.10
@export_range(1.0, 64.0, 1.0) var wall_jump_ground_distance: float = 32.0

var wall_motion = WallMovement.new()
var has_wall_jump: bool = false
const WALL_CLING_AUDIO_REARM_TIME := 0.10
var _wall_audio_side: int = 0
var _wall_audio_separation: float = 0.0
var jump_buffer_time: float = 0.0
var jump_buffer_released: bool = false
var landing_jump_queued: bool = false
var ground_coyote_time: float = 0.0
var jump_cut_active: bool = false
var jump_cut_requested: bool = false
var jump_cut_speed: float = 0.0
var jump_start_y: float = 0.0
var jump_minimum_rise: float = 0.0
var pending_wall_side: int = 0

# --- RUN-TO-CROUCH MOMENTUM (subtle coast; no velocity snap) ---
const CROUCH_MOMENTUM_MIN_SPEED := RUN_SPEED * 0.85
const CROUCH_MOMENTUM_DECEL := 550.0
const CROUCH_MOMENTUM_DURATION := 0.40
const CROUCH_MOMENTUM_STOP_SPEED := 1.0

# --- RUN-TO-KICK MOMENTUM (tiny body-weight carry; no startup snap) ---
const KICK_MOMENTUM_MIN_SPEED := RUN_SPEED * 0.75
const KICK_MOMENTUM_DECEL := 1200.0
const KICK_MOMENTUM_DURATION := 0.18
const KICK_MOMENTUM_STOP_SPEED := 1.0

const HURT_IFRAME_TIME := 1.25
const INVULN_FLASH_STEP := 0.07

const HURTBOX_STAND_HEIGHT := 53.0
const HURTBOX_CROUCH_HEIGHT := 39.0
const HURTBOX_STAND_OFFSET_Y := -0.5
const HURTBOX_CROUCH_OFFSET_Y := 6.5
const HURTBOX_TWEEN_DURATION := 0.08

# =========================
# KICK HITBOX SETTINGS
# =========================
const SHORT_KICK_HITBOX_SIZE := Vector2(11, 9)
const SOLID_KICK_RECOIL_SPEED := 50.0
const SHORT_KICK_HITBOX_OFFSET := Vector2(16, 17)
const LONG_KICK_HITBOX_SIZE := Vector2(13, 11)
const LONG_KICK_HITBOX_OFFSET := Vector2(17, 17)
# Both kicks currently share the placeholder poses: frame 1 is the contact pose.
# Keep upgraded tuning separate; adjust its size/offset/window when final art arrives.
const SHORT_KICK_ACTIVE_FRAME_START := 1
const SHORT_KICK_ACTIVE_FRAME_END := 1
const LONG_KICK_ACTIVE_FRAME_START := 1
const LONG_KICK_ACTIVE_FRAME_END := 1

const CAMERA_VERTICAL_FRAMING_OFFSET := -32.0

## Temporary: print land impact speeds, then set HARD_LAND_FALL_SPEED and set false.
const DEBUG_LAND_IMPACT := false
## Placeholder until tuned from DEBUG_LAND_IMPACT (comfortably above ordinary jump land).
const HARD_LAND_FALL_SPEED := 420.0
const HARD_LAND_LOCK_EXTRA := 0.15

const WALK_STEP_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/player/walk/walk_step_01.wav"),
	preload("res://assets/audio/sfx/player/walk/walk_step_02.wav"),
	preload("res://assets/audio/sfx/player/walk/walk_step_03.wav"),
]

const RUN_STEP_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/player/run/run_step_01.wav"),
	preload("res://assets/audio/sfx/player/run/run_step_02.wav"),
	preload("res://assets/audio/sfx/player/run/run_step_03.wav"),
]

# --- NODE REFERENCES ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: Node2D = $PlayerDust
@onready var fart_cloud: AnimatedSprite2D = $FartCloud
@onready var frames: SpriteFrames = anim.sprite_frames

@onready var sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var sfx_wall_cling: AudioStreamPlayer2D = $SFX_WallCling
@onready var sfx_wall_slide: AudioStreamPlayer2D = $SFX_WallSlide
@onready var sfx_wall_jump: AudioStreamPlayer2D = $SFX_WallJump
@onready var sfx_wall_impact: AudioStreamPlayer2D = $SFX_WallImpact
@onready var sfx_land: AudioStreamPlayer2D = $SFX_Land
@onready var sfx_kick_woosh: AudioStreamPlayer2D = $SFX_KickWoosh
@onready var sfx_kick_hit: AudioStreamPlayer2D = $SFX_KickHit
@onready var sfx_double_jump: AudioStreamPlayer2D = $SFX_DoubleJump
@onready var sfx_fart: AudioStreamPlayer2D = $SFX_Fart

# Footstep SFX
@onready var sfx_walk_step: AudioStreamPlayer2D = $SFX_WalkStep
@onready var sfx_run_step: AudioStreamPlayer2D = $SFX_RunStep
@onready var sfx_blaster_ready: AudioStreamPlayer2D = $SFX_BlasterReady
@onready var sfx_blaster_shoot_01: AudioStreamPlayer2D = $SFX_BlasterShoot01
@onready var sfx_blaster_shoot_02: AudioStreamPlayer2D = $SFX_BlasterShoot02
@onready var sfx_blaster_scrape: AudioStreamPlayer2D = $SFX_BlasterRecoilScrape

# Hurt nodes
@onready var sfx_hurt_01: AudioStreamPlayer2D = $SFX_Hurt_01
@onready var sfx_hurt_02: AudioStreamPlayer2D = $SFX_Hurt_02

# Death node (rename your node to exactly: SFX_Death)
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death

# Hitbox pivot for mirroring left/right
@onready var kick_pivot: Node2D = $KickPivot

# KickHitbox is under KickPivot; only pivot scale is flipped for left/right
@onready var kick_hitbox: Area2D = $KickPivot/KickHitbox
@onready var kick_hitbox_shape: CollisionShape2D = $KickPivot/KickHitbox/KickHitboxShape

@onready var hurtbox: Area2D = $Hurtbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var screen_shake: ScreenShake = $Camera2D/ScreenShake

# --- PLAYER STATE / RUNTIME VARIABLES ---
enum State { GROUND, WINDUP, AIR, LANDING, ATTACKING, HURT, DEAD }
var state: State = State.GROUND

## Camera framing / look offset owned by Player. Shake is added on top each frame.
var normal_camera_offset: Vector2 = Vector2(0.0, CAMERA_VERTICAL_FRAMING_OFFSET)
var was_on_floor: bool = false

# Bounce Mushroom support
# Added 2026-06-05
# Reason:
# Suppress normal landing SFX when landing on BounceMushroom.
# The primary solution is collider/group-based detection of
# bounce_mushroom surfaces during landing.
# suppress_next_land_sfx remains as a fallback hook for future
# bounce, spring, launch-pad, or similar launch surfaces.
var suppress_next_land_sfx: bool = false

var lock_time: float = 0.0
var pending_jump: bool = false

var has_double_jump: bool = false
var double_jump_used_this_air: bool = false
var double_jump_boost_timer: float = 0.0
var double_jump_anim_locked: bool = false

# After jump_double finishes, force jump_down until landing
var force_fall_anim: bool = false

var has_blaster: bool = false
var shooting: bool = false
var shooting_air: bool = false
var shot_emitted: bool = false
var shooting_facing: int = 1
var recoil_offset: float = 0.0
var shooting_showing_landing: bool = false
var shooting_waiting_for_ground: bool = false

# Crouch unlock flag (set by belt pickup)
var has_crouch: bool = false
var is_crouching: bool = false

# Run unlock flag (set by track medal pickup)
var has_run: bool = false

# Running runtime state. Recomputed only while on the floor so momentum carries
# through jump windup, airtime, and landing.
var is_running: bool = false
# True when raw horizontal axis exceeds MOVEMENT_INPUT_DEADZONE (not velocity).
var has_horizontal_input: bool = false

# Brief crouch coast after entering crouch from a genuine run (rising-edge only).
var crouch_momentum_timer: float = 0.0
# Tiny forward carry into a grounded kick begun from a direct run (not from crouch).
var kick_momentum_timer: float = 0.0

# Used to ensure kick hit SFX only fires once per kick
var kick_hit_sfx_lock: bool = false
var _solid_recoil_used: bool = false
var kick_animation: String = "kick_short" # start short, upgrade later by setting to "kick_long"

# =========================
# KICK HITBOX STATE
# =========================
var kick_hitbox_swing_long: bool = false
var kick_hitbox_active: bool = false
## Instance IDs of enemies already damaged by the current kick swing (blocks hitstop re-arm doubles).
var _kick_damaged_instance_ids: Dictionary = {}

var max_hp: int = 0
var hp: int = 0
var invuln_timer: float = 0.0

var _overlapping_enemy_attack_areas: Array[Area2D] = []

# Alternate hurt sounds
var hurt_toggle: bool = false

# 1px texture cache for sparkles
var _one_px_tex: Texture2D = null

var _hurtbox_tween: Tween = null
var last_walk_frame: int = -1
var last_walk_step_stream_index: int = -1
var last_run_step_frame: int = -1
var last_run_step_stream_index: int = -1
var hitstop_frames: int = 0
var _hitstop_anim_paused: bool = false
var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0
var jump_impulse: float = JUMP_FORCE

# --- READY ---
func _ready() -> void:
	movement_resource.enabled_changed.connect(_on_movement_resource_enabled_changed)
	# Give each player its own shapes: kicks and crouching resize these at runtime.
	# Keep those changes from affecting other instances of the player scene.
	if kick_hitbox_shape.shape != null:
		kick_hitbox_shape.shape = kick_hitbox_shape.shape.duplicate()
	if hurtbox_shape.shape != null:
		hurtbox_shape.shape = hurtbox_shape.shape.duplicate()

	normal_camera_offset = Vector2(0.0, CAMERA_VERTICAL_FRAMING_OFFSET)
	_apply_camera_offset()

	kick_hitbox.add_to_group("player_attack")

	# Pivot must stay at origin so mirroring is correct
	kick_pivot.position = Vector2.ZERO
	_update_kick_side()

	was_on_floor = is_on_floor()
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_blaster_frame_changed)
	anim.modulate = Color.WHITE
	fart_cloud.z_index = z_index - 1
	fart_cloud.animation_finished.connect(_reset_fart_cloud)
	_reset_fart_cloud()

	if not hurtbox.area_exited.is_connected(_on_hurtbox_area_exited):
		hurtbox.area_exited.connect(_on_hurtbox_area_exited)

	# start with kick hitbox OFF
	kick_hitbox.monitoring = false
	kick_hitbox_shape.disabled = true

	_update_hurtbox_crouch_state(false)

	_play("idle")
	_reapply_persistent_upgrades()
	# Match the selected kick before the first swing, rather than keeping scene defaults.
	_configure_kick_hitbox(kick_animation == "kick_long")


func _process(_delta: float) -> void:
	_apply_camera_offset()


func _apply_camera_offset() -> void:
	var shake: Vector2 = Vector2.ZERO
	if screen_shake != null:
		shake = screen_shake.offset
	camera.offset = (normal_camera_offset + shake).round()

# --- PUBLIC UPGRADE / PICKUP FUNCTIONS ---
func unlock_double_jump() -> void:
	has_double_jump = true
	print("UPGRADE: double_jump unlocked")

func unlock_wall_jump() -> void:
	has_wall_jump = true
	print("UPGRADE: wall_jump unlocked")

func unlock_kick_long() -> void:
	# Call this from your shorts pickup
	kick_animation = "kick_long"
	print("UPGRADE: kick_long unlocked")

func unlock_crouch() -> void:
	has_crouch = true
	print("UPGRADE: crouch unlocked")

func unlock_higher_jump() -> void:
	jump_impulse = JUMP_FORCE - 20.0
	print("UPGRADE: higher_jump unlocked")

func unlock_run() -> void:
	has_run = true
	print("UPGRADE: run unlocked")

func unlock_blaster() -> void:
	has_blaster = true
	print("UPGRADE: blaster unlocked")

func _reapply_persistent_upgrades() -> void:
	for upgrade_id in GameState.get_collected_upgrades():
		add_upgrade(upgrade_id)
	_init_health_from_progression()
	if GameState.stamina_cursed:
		movement_resource.set_stamina_phase(not GameState.gas_transmuted)
		if GameState.stamina_curse_reveal_pending:
			call_deferred("_begin_stamina_curse_reveal")
		else:
			movement_resource.set_enabled(true)
			if GameState.gas_reveal_pending:
				call_deferred("_begin_taco_gas_reveal")


# Grants a permanent max HP increase and records it in GameState.
# Reapplied automatically when new Player instances are created.
func grant_max_hp_upgrade(amount: int = 1) -> void:
	GameState.add_bonus_max_hp(amount)
	max_hp = GameState.get_max_hp()
	hp = max_hp


# Persistent progression owns max HP. A fresh spawn always starts at full.
func _init_health_from_progression() -> void:
	max_hp = GameState.get_max_hp()
	hp = max_hp


func add_upgrade(id: String) -> void:
	var applied := false
	if id == "shorts_kick_upgrade":
		unlock_kick_long()
		applied = true
	elif id == "belt_crouch_upgrade":
		unlock_crouch()
		applied = true
	elif id == "double_jump_upgrade":
		unlock_double_jump()
		applied = true
	elif id == "wall_jump_upgrade":
		unlock_wall_jump()
		applied = true
	elif id == "higher_jump_upgrade":
		unlock_higher_jump()
		applied = true
	elif id == "run_upgrade":
		unlock_run()
		applied = true
	elif id == "max_gas_upgrade":
		movement_resource.set_capacity(MovementResource.BASE_CAPACITY + 10.0)
		applied = true
	elif id == "blaster_upgrade":
		unlock_blaster()
		applied = true

	if not applied:
		return

	GameState.collect_upgrade(id)

func apply_slow(multiplier: float, duration: float) -> void:
	var clamped_multiplier := clampf(multiplier, 0.1, 1.0)
	var clamped_duration := maxf(0.0, duration)
	if clamped_duration <= 0.0:
		return

	_slow_multiplier = minf(_slow_multiplier, clamped_multiplier)
	_slow_timer = maxf(_slow_timer, clamped_duration)

# --- HEALTH / UI HELPERS ---
func heal(amount: int) -> void:
	# Called by pickups like donut
	if state == State.DEAD:
		return
	hp = mini(max_hp, hp + amount)
	_spawn_heal_sparkles()
	print("HEAL:", amount, "HP now:", hp)

func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)

func _get_1px_texture() -> Texture2D:
	if _one_px_tex:
		return _one_px_tex

	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_one_px_tex = ImageTexture.create_from_image(img)
	return _one_px_tex

func _spawn_heal_sparkles() -> void:
	# Spawns a tiny burst of white pixel sparkles around the player.
	var sparkle_count: int = randi_range(5, 7)

	for i in range(sparkle_count):
		var s: Sprite2D = Sprite2D.new()
		s.texture = _get_1px_texture()
		s.centered = true
		s.scale = Vector2(2, 2)
		s.modulate = Color(1, 1, 1, 1)

		# Spawn near upper body (so it reads as "healed")
		var offset: Vector2 = Vector2(randi_range(-6, 6), randi_range(-14, -4))
		s.global_position = global_position + offset

		# Put it in world
		var p: Node = get_parent()
		if p == null:
			return
		p.add_child(s)

		# Drift up/out and fade
		var drift: Vector2 = Vector2(randi_range(-16, 16), randi_range(-34, -18))
		var duration: float = randf_range(0.18, 0.28)

		var tw: Tween = get_tree().create_tween()
		tw.tween_property(s, "global_position", s.global_position + drift, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(s.queue_free)

# --- PHYSICS ---
var world_exit_active: bool = false
var world_exit_speed: float = 0.0
var world_exit_falling: bool = false

func begin_world_exit() -> void:
	world_exit_active = true
	velocity = Vector2.ZERO
	reset_for_external_launch()
	wall_motion.reset(true)
	_disable_kick_hitbox()
	anim.modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	if world_exit_active:
		_resource_suspended_this_tick = true
		velocity.x = world_exit_speed
		velocity.y += GRAVITY * delta
		move_and_slide()
		anim.flip_h = false
		_play("jump_down" if world_exit_falling else ("walk" if world_exit_speed > 0.0 else "idle"))
		return
	if curse_sequence_active and state != State.DEAD:
		# Keep gravity/floor contact while briefly holding input for the announcement.
		_resource_suspended_this_tick = true
		velocity.x = 0.0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return
	_resource_suspended_this_tick = hitstop_frames > 0 or state == State.DEAD or SceneTransition.busy
	if not movement_resource.enabled or SceneTransition.busy or state == State.DEAD or state == State.HURT:
		resource_kick_buffer_time = 0.0
	# Gate before crouch/kick can capture new running momentum, including neutral input.
	if movement_resource.enabled and movement_resource.exhausted and is_on_floor():
		is_running = false
	# timers
	if lock_time > 0.0:
		lock_time = maxf(0.0, lock_time - delta)
	if double_jump_boost_timer > 0.0:
		double_jump_boost_timer = maxf(0.0, double_jump_boost_timer - delta)
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		if invuln_timer <= 0.0:
			_check_overlapping_enemy_attacks_after_invuln()
	if _slow_timer > 0.0:
		_slow_timer = maxf(0.0, _slow_timer - delta)
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0

	_update_invuln_visual()

	# Wait until the kick has overlapped for a physics step; hurtbox contacts win.
	_try_static_kick_contact()

	# During hitstop: keep kick hitbox forced off so the active window is not extended
	# by a paused attack frame. Hitbox updates resume after the freeze ends.
	if hitstop_frames > 0:
		_stop_wall_slide_audio()
		if kick_hitbox_active:
			kick_hitbox_active = false
			_disable_kick_hitbox_physics()
		hitstop_frames -= 1
		if not _hitstop_anim_paused:
			anim.pause()
			_hitstop_anim_paused = true
		if hitstop_frames > 0:
			return
	if _hitstop_anim_paused:
		anim.play()
		_hitstop_anim_paused = false
		if screen_shake != null:
			screen_shake.release_impulse()

	_update_kick_hitbox(delta)

	# DEAD: no control
	if state == State.DEAD:
		_stop_wall_slide_audio()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# HURT: no input
	var can_input: bool = (state != State.HURT)
	_update_jump_input(delta, can_input)
	wall_motion.tick(delta)
	wall_motion.observe(self, body_shape, wall_coyote_duration, false)
	wall_motion.advance_cue(delta, has_wall_jump and state == State.AIR and not shooting and anim.animation == &"wall_cling", wall_cling_cue_duration)
	_show_wall_cue()

	var horizontal_input: float = (
		Input.get_action_raw_strength("ui_right")
		- Input.get_action_raw_strength("ui_left")
	)

	# ---------- CROUCH ----------
	# Shooting takes priority over held crouch, including the unfinished shot after release.
	var shoot_overrides_crouch: bool = (
		has_blaster and can_input and state == State.GROUND
		and not SceneTransition.busy and not double_jump_anim_locked
		and pending_wall_side == 0
		and (shooting or Input.is_action_pressed("shoot"))
		and (lock_time <= 0.0 or anim.animation == &"crouch_exit")
	)
	var can_crouch: bool = (
		has_crouch
		and can_input
		and state == State.GROUND
		and lock_time <= 0.0
		and is_on_floor()
	)

	if has_crouch:
		if shoot_overrides_crouch:
			if is_crouching:
				_clear_crouch_state()
			if anim.animation == &"crouch_exit":
				lock_time = 0.0
		elif can_crouch and Input.is_action_pressed("ui_down"):
			_cancel_shooting()
			if not is_crouching:
				is_crouching = true
				_try_start_crouch_momentum()
				_update_hurtbox_crouch_state(true)
				if frames and frames.has_animation("crouch_enter"):
					_play("crouch_enter")
		else:
			# Do not exit crouch just because can_crouch flickered false (e.g. is_on_floor before move)
			# while still holding down on GROUND — that caused crouch_exit then immediate re-enter.
			if is_crouching and (not Input.is_action_pressed("ui_down") or state != State.GROUND):
				_clear_crouch_state()
				if frames and frames.has_animation("crouch_exit"):
					_play("crouch_exit")
					_lock_for("crouch_exit")

	# Standing up is interruptible; resolve crouch before this frame's movement.
	if (
		can_input and state == State.GROUND and not is_crouching
		and anim.animation == &"crouch_exit"
		and absf(horizontal_input) > MOVEMENT_INPUT_DEADZONE
	):
		lock_time = 0.0

	var direction: int = 0
	has_horizontal_input = false
	var can_move: bool = (
		can_input
		and lock_time <= 0.0
		and state != State.WINDUP
		and state != State.LANDING
		and state != State.ATTACKING
		and (not has_crouch or not is_crouching)
	)

	if can_move:
		# Float axis first (raw strengths) so analog stick is not truncated to int before deadzone.
		has_horizontal_input = absf(horizontal_input) > MOVEMENT_INPUT_DEADZONE
		if has_horizontal_input:
			direction = -1 if horizontal_input < 0.0 else 1
			if not shooting and not wall_motion.protecting(wall_jump_protection):
				anim.flip_h = horizontal_input < 0.0
			_update_kick_side()

	# horizontal movement
	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	elif (shooting or shoot_overrides_crouch) and state == State.GROUND:
		velocity.x = move_toward(velocity.x, 0.0, KICK_MOMENTUM_DECEL * delta)
	elif double_jump_boost_timer > 0.0:
		pass
	elif can_move:
		_apply_horizontal_movement(direction, delta)
		if wall_motion.launch_elapsed >= 0.0:
			velocity.x = wall_motion.blend_steering(velocity.x, wall_jump_protection, wall_jump_recovery)
	elif is_running and not is_on_floor():
		# Air momentum carry: preserve fully while airborne.
		pass
	elif is_running and state == State.WINDUP:
		# Some carry through jump_start, but less sliding than full preserve.
		velocity.x = move_toward(velocity.x, 0.0, RUN_WINDUP_DECEL * delta)
	elif is_running and state == State.LANDING:
		# Some carry through jump_land, but much less sliding than full preserve.
		velocity.x = move_toward(velocity.x, 0.0, RUN_LAND_DECEL * delta)
	elif is_crouching and crouch_momentum_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, CROUCH_MOMENTUM_DECEL * delta)
		if absf(velocity.x) <= CROUCH_MOMENTUM_STOP_SPEED:
			velocity.x = 0.0
			crouch_momentum_timer = 0.0
		else:
			crouch_momentum_timer = maxf(0.0, crouch_momentum_timer - delta)
			# Safety cap only: keep same decel until natural stop (avoid FRICTION step-up).
			if crouch_momentum_timer <= 0.0:
				crouch_momentum_timer = 0.001
	elif state == State.ATTACKING and kick_momentum_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KICK_MOMENTUM_DECEL * delta)
		if absf(velocity.x) <= KICK_MOMENTUM_STOP_SPEED:
			velocity.x = 0.0
			kick_momentum_timer = 0.0
		else:
			kick_momentum_timer = maxf(0.0, kick_momentum_timer - delta)
			if kick_momentum_timer <= 0.0:
				kick_momentum_timer = 0.001
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# ---------- KICK ----------
	if _resource_kick_requested(delta, can_input):
		_cancel_shooting()
		# Capture pre-attack crouch before canceling; crouch-origin kicks keep normal friction only.
		var was_crouching: bool = (
			has_crouch
			and (is_crouching or anim.animation == "crouch_enter" or anim.animation == "crouch_idle")
		)
		if was_crouching:
			_clear_crouch_state()

		state = State.ATTACKING
		kick_hit_sfx_lock = false # reset: allow one hit SFX for this kick
		_solid_recoil_used = false
		kick_momentum_timer = 0.0

		# Run-to-kick carry only from a direct grounded run, never from crouch cancel.
		# Preserve current velocity; strong smooth decel handles the stop (no startup snap).
		if (
			not was_crouching
			and is_running
			and absf(velocity.x) >= KICK_MOMENTUM_MIN_SPEED
		):
			kick_momentum_timer = KICK_MOMENTUM_DURATION

		# Capture this attack's momentum before its cost can exhaust running.
		movement_resource.spend_kick()
		_update_kick_side()
		_play(kick_animation, true)
		_prepare_kick_hitbox(kick_animation == "kick_long")

		_lock_for(kick_animation)

		if sfx_kick_woosh and sfx_kick_woosh.stream:
			sfx_kick_woosh.play()

	# One press has exactly one owner: ground/coyote, wall/coyote, then double.
	_try_buffered_jump()

	# ---------- WINDUP FINISHED -> JUMP ----------
	var dust_ground_jump: bool = false
	var dust_takeoff_position := Vector2.ZERO
	if state == State.WINDUP and pending_jump and lock_time <= 0.0:
		dust_ground_jump = is_on_floor()
		dust_takeoff_position = to_global(Vector2(0, 28))
		_launch_ground_jump()

	_apply_jump_release()

	# ---------- GRAVITY ----------
	if not is_on_floor() or state == State.AIR or state == State.HURT:
		if velocity.y < 0.0:
			velocity.y += GRAVITY * delta
		else:
			velocity.y += GRAVITY * FALL_MULTIPLIER * delta
	else:
		velocity.y = 0.0

	wall_motion.apply_slide(self, direction, has_wall_jump and state == State.AIR, wall_slide_speed, wall_slide_deceleration, delta)

	# Impact speed is cleared by move_and_slide on land; cache while airborne.
	var pre_slide_fall_speed: float = velocity.y if not is_on_floor() else 0.0

	# Recoil is a temporary movement offset, not accumulating base velocity.
	var applied_recoil: float = recoil_offset
	velocity.x += applied_recoil
	var resource_start_x: float = global_position.x
	var resource_was_grounded: bool = is_on_floor() and state != State.AIR
	move_and_slide()
	if not is_on_floor():
		resource_kick_buffer_time = 0.0
	_tick_movement_resource(delta, direction, resource_start_x, resource_was_grounded)
	# Contact with the kicked object must not cancel recoil away from it.
	if is_on_wall() and get_wall_normal().x * applied_recoil < 0.0:
		recoil_offset = 0.0
	else:
		velocity.x -= applied_recoil
		recoil_offset = move_toward(recoil_offset, 0.0, RECOIL_DECEL * delta)

	# ---------- FLOOR TRANSITIONS ----------
	var on_floor_now: bool = is_on_floor()
	var just_landed: bool = on_floor_now and not was_on_floor
	var just_left_floor: bool = (not on_floor_now) and was_on_floor
	wall_motion.observe(self, body_shape, wall_coyote_duration, true)
	_update_wall_contact_audio(delta)
	_show_wall_cue()
	if dust_ground_jump and just_left_floor:
		dust.emit_takeoff(dust_takeoff_position)

	if just_left_floor:
		if state == State.GROUND:
			state = State.AIR
			_cancel_shooting()
			ground_coyote_time = ground_coyote_duration

	if just_landed:
		pending_wall_side = 0
		ground_coyote_time = 0.0
		jump_cut_active = false
		if jump_buffer_time > 0.0 and state == State.AIR:
			landing_jump_queued = true
	elif not on_floor_now and state == State.AIR:
		# New collision this frame may satisfy a press that could not execute above.
		_try_buffered_jump()

	# ---------- LAND (ANY FALL/JUMP) ----------
	if just_landed and state == State.AIR:
		var used_double_jump: bool = double_jump_used_this_air
		var is_bounce_land: bool = (
			suppress_next_land_sfx or _is_landing_on_bounce_mushroom()
		)
		if not is_bounce_land:
			dust.emit_landing(to_global(Vector2(0, 28)), pre_slide_fall_speed >= HARD_LAND_FALL_SPEED)
		var is_hard_land: bool = (
			not used_double_jump
			and not is_bounce_land
			and pre_slide_fall_speed >= HARD_LAND_FALL_SPEED
		)

		if DEBUG_LAND_IMPACT:
			print(
				"LAND_IMPACT fall_speed=",
				pre_slide_fall_speed,
				" used_dj=",
				used_double_jump,
				" bounce=",
				is_bounce_land,
				" hard=",
				is_hard_land
			)

		double_jump_used_this_air = false
		double_jump_anim_locked = false
		force_fall_anim = false

		state = State.LANDING
		if shooting and not is_bounce_land:
			_land_shooting()
		else:
			if shooting:
				_cancel_shooting()
			_play("jump_land")
		_lock_for("jump_land")
		if is_hard_land:
			lock_time += HARD_LAND_LOCK_EXTRA
			# Hard-land camera bump disabled for now (playtest); detection/recovery unchanged.
			# if screen_shake != null:
			# 	screen_shake.play_hard_land_bump()

		if is_bounce_land:
			suppress_next_land_sfx = false
		elif sfx_land and sfx_land.stream:
			sfx_land.play()

	if not on_floor_now:
		suppress_next_land_sfx = false

	# Crouch can cancel landing recovery; shooting still owns its touchdown sequence.
	if (
		state == State.LANDING and on_floor_now and has_crouch and can_input
		and not SceneTransition.busy and Input.is_action_pressed("ui_down")
		and not shooting and not (has_blaster and Input.is_action_pressed("shoot"))
	):
		lock_time = 0.0

	if state == State.LANDING and lock_time <= 0.0:
		state = State.GROUND

	_update_shooting()

	# ---------- AIR ANIMS ----------
	if state == State.AIR and not on_floor_now and not double_jump_anim_locked and not shooting:
		if has_wall_jump and wall_motion.contact_side != 0:
			anim.flip_h = wall_motion.contact_side < 0
			_update_kick_side()
			_play("wall_cling")
		elif wall_motion.pose == WallMovement.Pose.PUSH:
			pass # Only the pose is protected; physics and steering remain active.
		elif wall_motion.pose == WallMovement.Pose.HOLD:
			var near_ground: bool = velocity.y > 0.0 and wall_motion.ground_nearby(self, body_shape, wall_jump_ground_distance)
			_play("jump_down" if near_ground else "jump_peak")
		elif force_fall_anim:
			_play("jump_down")
		else:
			# Hold the apex pose briefly; ledge falls never enter it.
			if absf(velocity.y) <= JUMP_PEAK_SPEED and (anim.animation == "jump_up" or anim.animation == "jump_peak"):
				_play("jump_peak")
			elif velocity.y < 0.0:
				_play("jump_up")
			else:
				_play("jump_down")

	# ---------- GROUND ANIMS ----------
	if state == State.GROUND and lock_time <= 0.0 and not shooting:
		# Crouch block ran earlier while state was still LANDING; start crouch here same frame we become GROUND.
		if (
			has_crouch
			and can_input
			and on_floor_now
			and Input.is_action_pressed("ui_down")
			and not is_crouching
		):
			is_crouching = true
			_try_start_crouch_momentum()
			_update_hurtbox_crouch_state(true)
			if frames and frames.has_animation("crouch_enter"):
				_play("crouch_enter")

		if has_crouch and is_crouching:
			if frames and frames.has_animation("crouch_idle"):
				if anim.animation != "crouch_idle":
					_play("crouch_idle")
			else:
				if abs(velocity.x) > 1.0:
					_play_locomotion("walk")
				else:
					_play("idle")
		else:
			_play_locomotion(_ground_locomotion_animation())

	_handle_walk_footsteps()
	_handle_run_footsteps()
	_update_wall_slide_audio()
	_update_wall_jump_visual()
	was_on_floor = on_floor_now

# --- SHARED JUMP INPUT / LAUNCHES ---
func _stop_wall_slide_audio() -> void:
	if sfx_wall_slide.playing:
		sfx_wall_slide.stop()


func _reset_wall_audio() -> void:
	_stop_wall_slide_audio()
	_wall_audio_side = 0
	_wall_audio_separation = 0.0


func _update_wall_contact_audio(delta: float) -> void:
	# Audio debouncing is independent of wall eligibility and animation timing.
	if is_on_floor() or not has_wall_jump:
		_reset_wall_audio()
		return
	var side: int = wall_motion.contact_side
	if side == 0:
		_wall_audio_separation += delta
		if _wall_audio_separation + 0.000001 >= WALL_CLING_AUDIO_REARM_TIME:
			_wall_audio_side = 0
		return
	_wall_audio_separation = 0.0
	if state == State.AIR and side != _wall_audio_side:
		_wall_audio_side = side
		sfx_wall_cling.play()


func _update_wall_slide_audio() -> void:
	# apply_slide runs before move_and_slide; verify the resulting contact too.
	var active: bool = (
		has_wall_jump and state == State.AIR and not is_on_floor()
		and wall_motion.sliding and wall_motion.contact_side != 0
		and velocity.y > 0.0 and wall_motion.launch_elapsed < 0.0
		and hitstop_frames <= 0
	)
	if active:
		if not sfx_wall_slide.playing:
			sfx_wall_slide.play()
	else:
		_stop_wall_slide_audio()


func _show_wall_cue() -> void:
	if not has_wall_jump or state != State.AIR or is_on_floor() or shooting or wall_motion.contact_side == 0:
		return
	# Contact owns this pose, including rising/neutral contact. It does not change
	# velocity, launch protection, or whether the taco jump has been spent.
	double_jump_anim_locked = false
	force_fall_anim = false
	wall_motion.pose = WallMovement.Pose.NONE
	anim.flip_h = wall_motion.contact_side < 0
	_update_kick_side()
	_play("wall_cling")


func _update_jump_input(delta: float, can_input: bool) -> void:
	ground_coyote_time = maxf(0.0, ground_coyote_time - delta)
	if not landing_jump_queued:
		jump_buffer_time = maxf(0.0, jump_buffer_time - delta)
	if not can_input:
		return
	if Input.is_action_just_pressed("ui_jump"):
		jump_buffer_time = jump_buffer_duration
		jump_buffer_released = false
		if state == State.LANDING and is_on_floor():
			landing_jump_queued = true
	if not Input.is_action_pressed("ui_jump"):
		if jump_buffer_time > 0.0 or landing_jump_queued or pending_wall_side != 0:
			jump_buffer_released = true
		if jump_cut_active or pending_jump:
			jump_cut_requested = true


func _consume_jump_buffer() -> void:
	jump_cut_requested = jump_buffer_released or not Input.is_action_pressed("ui_jump")
	jump_buffer_time = 0.0
	jump_buffer_released = false
	landing_jump_queued = false
	pending_wall_side = 0
	ground_coyote_time = 0.0
	wall_motion.clear_grace()


func _try_buffered_jump() -> void:
	# Reservation lasts only through this contact's visible cue. If contact ends,
	# the original (still aging) buffer alone decides whether another jump can run.
	if pending_wall_side != 0 and (wall_motion.contact_side != pending_wall_side or wall_motion.spent_side == pending_wall_side):
		pending_wall_side = 0
	if jump_buffer_time <= 0.0 and not landing_jump_queued and pending_wall_side == 0:
		return
	if state == State.GROUND and is_on_floor() and lock_time <= 0.0:
		_consume_jump_buffer()
		_start_ground_jump()
	elif state == State.AIR and not is_on_floor():
		if ground_coyote_time > 0.0:
			_consume_jump_buffer()
			_cancel_shooting()
			_launch_ground_jump()
		else:
			var side: int = wall_motion.eligible_side() if has_wall_jump else 0
			if side != 0:
				_consume_jump_buffer()
				_start_wall_jump(side)
			elif has_wall_jump and wall_motion.contact_side != 0 and wall_motion.contact_side != wall_motion.spent_side:
				pending_wall_side = wall_motion.contact_side
				_cancel_shooting()
				_show_wall_cue()
			elif has_double_jump and not double_jump_used_this_air:
				_consume_jump_buffer()
				_start_double_jump()


func _launch_ground_jump() -> void:
	resource_kick_buffer_time = 0.0
	resource_running_carry = is_running
	_spend_movement_resource(movement_resource.ground_jump_cost)
	pending_jump = false
	state = State.AIR
	force_fall_anim = false
	velocity.y = jump_impulse
	_arm_jump_cut(ground_jump_minimum_rise)
	if sfx_jump and sfx_jump.stream:
		sfx_jump.play()
	_play("jump_up")


func _start_wall_jump(side: int) -> void:
	resource_kick_buffer_time = 0.0
	resource_running_carry = false
	_spend_movement_resource(movement_resource.wall_jump_cost)
	_stop_wall_slide_audio()
	_cancel_shooting()
	double_jump_anim_locked = false
	double_jump_boost_timer = 0.0
	force_fall_anim = false
	wall_motion.begin_jump(side, RUN_SPEED * wall_jump_horizontal_multiplier)
	velocity = Vector2(wall_motion.launch_x, jump_impulse * wall_jump_vertical_multiplier)
	anim.flip_h = side > 0
	_update_kick_side()
	_arm_jump_cut(0.0)
	_apply_jump_release()
	_play("wall_jump", true)
	sfx_wall_jump.play()
	sfx_wall_impact.play()


func _arm_jump_cut(minimum_rise: float) -> void:
	jump_cut_active = true
	jump_start_y = global_position.y
	jump_minimum_rise = minimum_rise
	jump_cut_speed = absf(velocity.y) * jump_release_speed_ratio


func _apply_jump_release() -> void:
	if not jump_cut_active:
		return
	if velocity.y >= 0.0:
		jump_cut_active = false
	elif jump_cut_requested and jump_start_y - global_position.y >= jump_minimum_rise:
		velocity.y = maxf(velocity.y, -jump_cut_speed)
		jump_cut_active = false


# Mushroom launches can occur before physical touchdown. Do not reset spent_side
# here: only an actual floor/opposing-wall contact resets that restriction.
func reset_for_external_launch() -> void:
	resource_kick_buffer_time = 0.0
	resource_running_carry = false
	_reset_wall_audio()
	pending_wall_side = 0
	jump_buffer_time = 0.0
	jump_buffer_released = false
	landing_jump_queued = false
	ground_coyote_time = 0.0
	jump_cut_active = false
	jump_cut_requested = false
	wall_motion.reset(is_on_floor())

func _start_ground_jump() -> void:
	resource_kick_buffer_time = 0.0
	_cancel_shooting()
	var skipping_start: bool = false
	if has_crouch and (is_crouching or anim.animation == "crouch_enter" or anim.animation == "crouch_idle"):
		skipping_start = true

	state = State.WINDUP
	pending_jump = true
	force_fall_anim = false
	_play("jump_start")

	if skipping_start:
		if is_crouching:
			_clear_crouch_state()
		if frames and frames.has_animation("jump_start"):
			var count: int = frames.get_frame_count("jump_start")
			var fps: float = frames.get_animation_speed("jump_start")
			if fps <= 0.0:
				fps = 12.0
			var target_frame: int = mini(2, count - 1)
			anim.frame = target_frame
			# keep a brief final-frame windup before the jump
			lock_time = 1.0 / fps
		else:
			_lock_for("jump_start")
	else:
		_lock_for("jump_start")


func _start_double_jump() -> void:
	resource_kick_buffer_time = 0.0
	_spend_movement_resource(movement_resource.double_jump_cost)
	_stop_wall_slide_audio()
	wall_motion.cancel_launch()
	_cancel_shooting()
	double_jump_used_this_air = true
	double_jump_boost_timer = DOUBLE_JUMP_BOOST_DURATION
	var facing: int = -1 if anim.flip_h else 1
	velocity.y = jump_impulse
	var dj_x: float = float(facing) * DOUBLE_JUMP_HORIZONTAL
	# Near-zero is not "moving with facing" (signf(0) == 0).
	var moving_with_facing: bool = absf(velocity.x) > 0.01 and signf(velocity.x) == float(facing)
	if moving_with_facing and absf(velocity.x) >= absf(dj_x):
		pass  # preserve faster same-direction momentum (e.g. run carry)
	else:
		velocity.x = dj_x

	# A reversal or slower double jump ends inherited running carry.
	if not moving_with_facing or absf(velocity.x) <= SPEED * _slow_multiplier:
		resource_running_carry = false
	if sfx_double_jump and sfx_double_jump.stream:
		sfx_double_jump.play()
	if sfx_fart and sfx_fart.stream:
		sfx_fart.play()
	_play_fart_cloud()

	force_fall_anim = false
	_play("jump_double")
	double_jump_anim_locked = true
	_arm_jump_cut(0.0)
	_apply_jump_release()


func _play_fart_cloud() -> void:
	_reset_fart_cloud()
	var facing: float = -1.0 if anim.flip_h else 1.0
	# Top-level keeps this player-owned effect anchored where the jump began.
	fart_cloud.global_position = to_global(Vector2(fart_cloud_offset.x * facing, fart_cloud_offset.y)).round()
	fart_cloud.flip_h = anim.flip_h
	fart_cloud.show()
	fart_cloud.play(&"fart_cloud")


func _reset_fart_cloud() -> void:
	fart_cloud.hide()
	fart_cloud.stop()
	fart_cloud.set_frame_and_progress(0, 0.0)


# --- ANIMATION CALLBACKS ---
func _on_jump_double_anim_finished() -> void:
	double_jump_anim_locked = false
	force_fall_anim = true

func _on_anim_finished() -> void:
	if anim.animation == "wall_jump" and state == State.AIR and wall_motion.pose == WallMovement.Pose.PUSH:
		wall_motion.pose = WallMovement.Pose.HOLD
		_play("jump_peak")
		return
	if anim.animation == "jump_double" and state == State.AIR and double_jump_anim_locked:
		_on_jump_double_anim_finished()
		return
	if shooting:
		if not _can_finish_shot() or shooting_air != (state == State.AIR):
			_cancel_shooting()
		elif shooting_waiting_for_ground:
			return
		elif anim.animation == "shoot_start" or anim.animation == "jump_shoot_start":
			_begin_firing_cycle()
		elif _is_firing_animation() or (shooting_showing_landing and anim.animation == "jump_land"):
			var finished_landing: bool = shooting_showing_landing
			shooting_showing_landing = false
			if Input.is_action_pressed("shoot") and _can_shoot():
				_begin_firing_cycle()
			elif Input.is_action_pressed("shoot") and state == State.LANDING:
				shooting_waiting_for_ground = true
				anim.pause()
			else:
				_cancel_shooting(finished_landing)
		return
	# Only finish a lead-in while its ground movement is still appropriate.
	if (
		(anim.animation == "walk_start" or anim.animation == "run_start")
		and state == State.GROUND
		and is_on_floor()
		and lock_time <= 0.0
		and not is_crouching
	):
		var loop_animation: String = "walk" if anim.animation == "walk_start" else "run"
		var desired_animation: String = _ground_locomotion_animation()
		if desired_animation == loop_animation:
			_play(loop_animation)
		else:
			_play_locomotion(desired_animation)
		return

	if state == State.ATTACKING and anim.animation == kick_animation:
		state = State.GROUND
		lock_time = 0.0
		kick_momentum_timer = 0.0

		_disable_kick_hitbox()

		# After kick: if crouch is still held, return to crouch; otherwise, normal ground anims.
		if has_crouch and Input.is_action_pressed("ui_down"):
			is_crouching = true
			_update_hurtbox_crouch_state(true)
			if frames and frames.has_animation("crouch_idle"):
				_play("crouch_idle")
		else:
			_play_locomotion(_ground_locomotion_animation())

# --- ANIMATION / STATE HELPERS ---

# =========================
# KICK HITBOX HELPERS
# =========================
func _prepare_kick_hitbox(is_long_kick: bool) -> void:
	_kick_damaged_instance_ids.clear()
	kick_hitbox_swing_long = is_long_kick
	_configure_kick_hitbox(is_long_kick)
	_update_kick_side()
	kick_hitbox_active = false
	_disable_kick_hitbox_physics()


## First KickHitbox contact with this enemy root this swing → true.
## Later contacts (e.g. hitstop re-arm while overlapping) → false.
func register_kick_damage_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id: int = target.get_instance_id()
	if _kick_damaged_instance_ids.has(id):
		return false
	_kick_damaged_instance_ids[id] = true
	return true


## Fixed or movable objects request recoil on accepted kicks; strength scales speed only.
func apply_solid_kick_recoil(attack_area: Area2D, strength_multiplier: float = 1.0) -> void:
	if attack_area != kick_hitbox or not kick_hitbox_active or state != State.ATTACKING or _solid_recoil_used:
		return
	_solid_recoil_used = true
	kick_momentum_timer = 0.0
	velocity.x = 0.0
	var facing: float = -1.0 if anim.flip_h else 1.0
	# The existing hitstop freezes this offset until normal movement resumes.
	recoil_offset = -facing * SOLID_KICK_RECOIL_SPEED * strength_multiplier
	# Physical recoil replaces the camera shove; clear it if that signal ran first.
	if screen_shake != null:
		screen_shake.clear_combat_impulse()


func is_solid_kick_recoil_active() -> bool:
	return state == State.ATTACKING and _solid_recoil_used and not is_zero_approx(recoil_offset)


func _try_static_kick_contact() -> void:
	if not kick_hitbox_active or hitstop_frames > 0 or kick_hit_sfx_lock or _solid_recoil_used:
		return
	if state != State.ATTACKING or anim.animation != kick_animation or not _is_kick_hitbox_active_frame(anim.frame, kick_hitbox_swing_long):
		return
	var rect := kick_hitbox_shape.shape as RectangleShape2D
	if rect == null:
		return
	var facing: float = -1.0 if anim.flip_h else 1.0
	var inset_height := maxf(0.0, rect.size.y * 0.5 - 1.0)
	var space := get_world_2d().direct_space_state
	for y in [0.0, -inset_height, inset_height]:
		var tip := kick_hitbox_shape.to_global(Vector2(rect.size.x * 0.5, y))
		var origin := Vector2(global_position.x, tip.y)
		var query := PhysicsRayQueryParameters2D.create(origin, tip, collision_mask, [get_rid()])
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		# An excluded object blocks this ray; never look through it for another hit.
		if not hit.is_empty() and _is_static_kick_surface(hit, facing):
			apply_solid_kick_recoil(kick_hitbox)
			_apply_kick_contact_feedback()
			return


func _is_static_kick_surface(hit: Dictionary, facing: float) -> bool:
	if (hit.normal as Vector2).x * facing > -0.95:
		return false
	var collider: Node = hit.collider as Node
	if not (collider is TileMapLayer or (collider is StaticBody2D and not collider is AnimatableBody2D)):
		return false
	var ancestor := collider
	while ancestor != null:
		if ancestor.is_in_group("custom_kick_contact") or ancestor.is_in_group("bounce_mushroom"):
			return false
		ancestor = ancestor.get_parent()
	if collider is TileMapLayer:
		# Sample just inside the face, without depending on physics-body cell batching.
		var tile_layer := collider as TileMapLayer
		var inside: Vector2 = hit.position - hit.normal * 0.5
		var cell := tile_layer.local_to_map(tile_layer.to_local(inside))
		var tile := tile_layer.get_cell_tile_data(cell)
		if tile == null:
			return false
		for layer in tile_layer.tile_set.get_physics_layers_count():
			for polygon in tile.get_collision_polygons_count(layer):
				if tile.is_collision_polygon_one_way(layer, polygon):
					return false
		return true
	var body := collider as StaticBody2D
	var shape_owner := body.shape_find_owner(int(hit.shape))
	return not body.is_shape_owner_one_way_collision_enabled(shape_owner)


func _update_kick_hitbox(_delta: float) -> void:
	if state != State.ATTACKING or anim.animation != kick_animation:
		_disable_kick_hitbox()
		return

	var should_enable := _is_kick_hitbox_active_frame(anim.frame, kick_hitbox_swing_long)
	if should_enable:
		if not kick_hitbox_active:
			_enable_kick_hitbox()
	else:
		if kick_hitbox_active:
			kick_hitbox_active = false
			_disable_kick_hitbox_physics()


func _is_kick_hitbox_active_frame(frame: int, is_long_kick: bool) -> bool:
	if is_long_kick:
		return frame >= LONG_KICK_ACTIVE_FRAME_START and frame <= LONG_KICK_ACTIVE_FRAME_END
	return frame >= SHORT_KICK_ACTIVE_FRAME_START and frame <= SHORT_KICK_ACTIVE_FRAME_END


func _configure_kick_hitbox(is_long_kick: bool) -> void:
	kick_hitbox.position = Vector2.ZERO
	var size: Vector2 = LONG_KICK_HITBOX_SIZE if is_long_kick else SHORT_KICK_HITBOX_SIZE
	var offset: Vector2 = LONG_KICK_HITBOX_OFFSET if is_long_kick else SHORT_KICK_HITBOX_OFFSET
	var rect_shape := kick_hitbox_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		kick_hitbox_shape.shape = rect_shape
	rect_shape.size = size
	kick_hitbox_shape.position = offset


func _enable_kick_hitbox() -> void:
	kick_hitbox_active = true
	if kick_hitbox:
		kick_hitbox.set_deferred("monitoring", true)
	if kick_hitbox_shape:
		kick_hitbox_shape.set_deferred("disabled", false)


func _disable_kick_hitbox_physics() -> void:
	if kick_hitbox:
		kick_hitbox.set_deferred("monitoring", false)
	if kick_hitbox_shape:
		kick_hitbox_shape.set_deferred("disabled", true)


func _disable_kick_hitbox() -> void:
	kick_hitbox_active = false
	kick_hitbox_swing_long = false
	_disable_kick_hitbox_physics()


func _update_kick_side() -> void:
	# Only flip the pivot; kick shape offset is authored for +X and mirrored here.
	if kick_pivot:
		kick_pivot.scale.x = -1.0 if anim.flip_h else 1.0

func _apply_horizontal_movement(direction: int, delta: float) -> void:
	# Running intent is only (re)evaluated on the floor; while airborne it carries.
	if is_on_floor():
		# Preserve run momentum through brief neutral input frames.
		if movement_resource.enabled and movement_resource.exhausted:
			is_running = false
		elif direction != 0:
			is_running = has_run and Input.is_action_pressed("run")
		elif not has_run or not Input.is_action_pressed("run"):
			is_running = false

	if not is_running:
		# Walk: snappy/instant. Only bleed leftover run momentum smoothly instead of hard-snapping.
		var walk_target: float = direction * SPEED * _slow_multiplier
		if direction != 0 and absf(velocity.x) > absf(walk_target) and signf(velocity.x) == signf(float(direction)):
			velocity.x = move_toward(velocity.x, walk_target, RUN_DECEL * delta)
		else:
			velocity.x = walk_target
		return

	var run_target: float = direction * RUN_SPEED * _slow_multiplier
	if direction != 0 and velocity.x != 0.0 and signf(velocity.x) != signf(float(direction)):
		# Turning around: bleed momentum before re-accelerating the other way.
		velocity.x = move_toward(velocity.x, run_target, RUN_TURN_DECEL * delta)
	else:
		velocity.x = move_toward(velocity.x, run_target, RUN_ACCEL * delta)

func _try_start_crouch_momentum() -> void:
	# Rising-edge only (caller must already be entering crouch). Preserve velocity; no snap.
	if is_running and absf(velocity.x) >= CROUCH_MOMENTUM_MIN_SPEED:
		crouch_momentum_timer = CROUCH_MOMENTUM_DURATION
	else:
		crouch_momentum_timer = 0.0

func _can_shoot() -> bool:
	return _can_finish_shot() and state != State.LANDING and lock_time <= 0.0

func _can_finish_shot() -> bool:
	return has_blaster and not SceneTransition.busy and (state == State.GROUND or state == State.AIR or state == State.LANDING) and not is_crouching

func _land_shooting() -> void:
	if not _can_finish_shot():
		_cancel_shooting()
		_play("jump_land", true)
		return
	var was_readying: bool = anim.animation == "jump_shoot_start"
	shooting_air = false
	# Resolve the committed projectile before giving touchdown its normal animation.
	if not shot_emitted:
		if was_readying:
			sfx_blaster_shoot_01.play()
			sfx_blaster_shoot_02.play()
		_emit_blaster_shot()
	shooting_showing_landing = true
	shooting_waiting_for_ground = false
	_play("jump_land", true)

func _update_shooting() -> void:
	if pending_wall_side != 0:
		return
	if shooting:
		if not _can_finish_shot() or shooting_air != (state == State.AIR):
			_cancel_shooting()
		elif not shooting_showing_landing and not shooting_waiting_for_ground and anim.animation not in [&"shoot_start", &"jump_shoot_start"] and not _is_firing_animation():
			# External launch animations (e.g. mushrooms) take ownership immediately.
			_cancel_shooting()
		elif shooting_showing_landing:
			if not Input.is_action_pressed("shoot"):
				_cancel_shooting(true)
			return
		elif shooting_waiting_for_ground:
			if not Input.is_action_pressed("shoot"):
				_cancel_shooting(true)
			elif _can_shoot():
				shooting_waiting_for_ground = false
				_begin_firing_cycle()
		elif _is_firing_animation():
			var desired_animation: String = _firing_animation(shooting_air)
			if anim.animation != desired_animation:
				var saved_frame: int = anim.frame
				var saved_progress: float = anim.frame_progress
				anim.play(desired_animation)
				anim.set_frame_and_progress(saved_frame, saved_progress)
	if not shooting and _can_shoot() and Input.is_action_pressed("shoot"):
		# Shooting may finish the double-jump pose early without changing its movement.
		if double_jump_anim_locked:
			_on_jump_double_anim_finished()
		wall_motion.pose = WallMovement.Pose.NONE
		shooting = true
		shooting_air = state == State.AIR
		_capture_shooting_facing()
		_play("jump_shoot_start" if shooting_air else "shoot_start", true)
		sfx_blaster_ready.play()

func _capture_shooting_facing() -> void:
	var axis: float = Input.get_action_raw_strength("ui_right") - Input.get_action_raw_strength("ui_left")
	if absf(axis) > MOVEMENT_INPUT_DEADZONE:
		anim.flip_h = axis < 0.0
	shooting_facing = -1 if anim.flip_h else 1
	_update_kick_side()

func _begin_firing_cycle() -> void:
	shot_emitted = false
	_capture_shooting_facing()
	_play(_firing_animation(shooting_air), true)
	# Both layers start together on displayed firing frame 1.
	sfx_blaster_shoot_01.play()
	sfx_blaster_shoot_02.play()

func _is_firing_animation() -> bool:
	return anim.animation in [&"shoot", &"shoot_repeat", &"jump_shoot", &"jump_shoot_repeat"]

func _firing_animation(airborne: bool) -> String:
	var animation_name: String = "jump_shoot" if airborne else "shoot"
	# The repeat variant holds pose 3 through slot 4, preserving the shot interval.
	return animation_name + "_repeat" if Input.is_action_pressed("shoot") else animation_name

func _cancel_shooting(preserve_recoil: bool = false) -> void:
	shooting = false
	shot_emitted = false
	if not preserve_recoil:
		recoil_offset = 0.0
	shooting_showing_landing = false
	shooting_waiting_for_ground = false

func _on_blaster_frame_changed() -> void:
	if not shooting or shot_emitted or anim.frame != 2 or not _is_firing_animation():
		return
	if not _can_finish_shot():
		_cancel_shooting()
		return
	_emit_blaster_shot()

func _emit_blaster_shot() -> void:
	# Shared by the normal firing frame and touchdown; invalid calls have no side effects.
	if not shooting or shot_emitted or not _can_finish_shot():
		return
	shot_emitted = true
	var muzzle: Vector2 = BLASTER_AIR_MUZZLE if shooting_air else BLASTER_GROUND_MUZZLE
	muzzle.x *= shooting_facing
	var muzzle_position: Vector2 = to_global(muzzle)
	var projectile := BLASTER_PROJECTILE.instantiate()
	projectile.direction = shooting_facing
	projectile.shooter = self
	projectile.spawn_from = to_global(Vector2(0, muzzle.y))
	projectile.position = get_parent().to_local(muzzle_position)
	get_parent().add_child(projectile)
	var smoke := BLASTER_SMOKE.instantiate()
	smoke.position = get_parent().to_local(to_global(muzzle + Vector2(-shooting_facing, -1)))
	smoke.flip_h = shooting_facing < 0
	get_parent().add_child(smoke)
	recoil_offset = -shooting_facing * BLASTER_RECOIL_SPEED
	if is_on_floor():
		sfx_blaster_scrape.play()

func _ground_locomotion_animation() -> String:
	# Run needs intent and horizontal input; walk also covers residual momentum.
	if is_running and has_horizontal_input and frames and frames.has_animation("run"):
		return "run"
	return "walk" if absf(velocity.x) > 1.0 else "idle"

func _play_locomotion(loop_animation: String) -> void:
	if loop_animation == "idle":
		_play("idle")
		return
	var start_animation: String = loop_animation + "_start"
	if anim.animation == loop_animation or anim.animation == start_animation:
		return
	_play(start_animation if frames and frames.has_animation(start_animation) else loop_animation)

func _play(anim_name: String, force_restart: bool = false) -> void:
	if force_restart or anim.animation != anim_name:
		anim.play(anim_name)
	_update_wall_jump_visual()

func _update_wall_jump_visual() -> void:
	# Unlike ordinary right-facing poses, the authored wall_jump pushes LEFT
	# from a wall on the right. Keep that sequence tied to its launch side even
	# once steering resumes. flip_h remains the gameplay facing for shots/kicks.
	var mirror_pose: bool = anim.animation == &"wall_jump" and anim.flip_h != (wall_motion.launch_x > 0.0)
	anim.scale.x = -1.0 if mirror_pose else 1.0

func _lock_for(anim_name: String) -> void:
	if frames == null or not frames.has_animation(anim_name):
		lock_time = 0.0
		return
	var count: int = frames.get_frame_count(anim_name)
	var fps: float = frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		fps = 12.0
	lock_time = float(count) / fps

func _is_landing_on_bounce_mushroom() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var collider := collision.get_collider()
		if collider != null and collider.is_in_group(&"bounce_mushroom"):
			return true
	return false

# Callers own exit conditions and animations; keep the hurtbox and momentum in sync.
func _clear_crouch_state() -> void:
	is_crouching = false
	crouch_momentum_timer = 0.0
	_update_hurtbox_crouch_state(true)

func _update_hurtbox_crouch_state(animated: bool) -> void:
	if not hurtbox_shape:
		return

	var rect_shape := hurtbox_shape.shape
	if rect_shape == null or not rect_shape is RectangleShape2D:
		return

	var shape := rect_shape as RectangleShape2D

	var target_height := HURTBOX_CROUCH_HEIGHT if is_crouching else HURTBOX_STAND_HEIGHT
	var target_offset_y := HURTBOX_CROUCH_OFFSET_Y if is_crouching else HURTBOX_STAND_OFFSET_Y

	var current_size: Vector2 = shape.size
	var target_size: Vector2 = Vector2(current_size.x, target_height)

	if _hurtbox_tween:
		_hurtbox_tween.kill()
		_hurtbox_tween = null

	if not animated:
		shape.size = target_size
		var pos := hurtbox_shape.position
		pos.y = target_offset_y
		hurtbox_shape.position = pos
		return

	_hurtbox_tween = get_tree().create_tween()
	_hurtbox_tween.tween_property(
		shape,
		"size",
		target_size,
		HURTBOX_TWEEN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hurtbox_tween.parallel().tween_property(
		hurtbox_shape,
		"position:y",
		target_offset_y,
		HURTBOX_TWEEN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _handle_walk_footsteps() -> void:
	if not is_on_floor() or state != State.GROUND or anim.animation != "walk":
		last_walk_frame = -1
		return

	if anim.frame == last_walk_frame:
		return

	last_walk_frame = anim.frame

	# visual frame 2 = code frame 1
	# visual frame 6 = code frame 5
	if anim.frame == 1 or anim.frame == 5:
		_play_random_walk_step()

func _play_random_walk_step() -> void:
	last_walk_step_stream_index = _play_footstep(sfx_walk_step, WALK_STEP_STREAMS, last_walk_step_stream_index)

func _handle_run_footsteps() -> void:
	if (
		not is_on_floor()
		or not is_running
		or state != State.GROUND
		or is_crouching
		or anim.animation != "run"
	):
		last_run_step_frame = -1
		return

	if anim.frame == last_run_step_frame:
		return

	last_run_step_frame = anim.frame

	if anim.frame == 3 or anim.frame == 7:
		_play_run_step_sfx()

func _play_run_step_sfx() -> void:
	last_run_step_stream_index = _play_footstep(sfx_run_step, RUN_STEP_STREAMS, last_run_step_stream_index)

# Callers keep separate walk/run histories; timing stays in the frame handlers.
func _play_footstep(sfx: AudioStreamPlayer2D, streams: Array[AudioStream], previous_index: int) -> int:
	if not is_instance_valid(sfx):
		return previous_index

	var index := randi() % streams.size()
	if streams.size() > 1 and index == previous_index:
		index = (index + 1) % streams.size()

	sfx.stream = streams[index]
	sfx.pitch_scale = randf_range(0.97, 1.03)
	sfx.play()
	return index

# --- COMBAT AND DAMAGE ---
func _update_invuln_visual() -> void:
	if state == State.DEAD:
		anim.modulate = Color.WHITE
		return
	if invuln_timer <= 0.0:
		anim.modulate = Color.WHITE
		return

	var elapsed := HURT_IFRAME_TIME - invuln_timer
	# Regular, high-contrast blinking makes the whole protection window readable.
	var phase := int(floor(elapsed / INVULN_FLASH_STEP)) % 2
	anim.modulate = Color.WHITE if phase == 0 else Color(1, 1, 1, 0.2)

func _play_hurt_sound() -> void:
	if hurt_toggle:
		if sfx_hurt_01 and sfx_hurt_01.stream:
			sfx_hurt_01.play()
	else:
		if sfx_hurt_02 and sfx_hurt_02.stream:
			sfx_hurt_02.play()
	hurt_toggle = !hurt_toggle

func _on_kick_hitbox_area_entered(area: Area2D) -> void:
	if not kick_hitbox_active:
		return
	if state != State.ATTACKING:
		return

	# Only react to enemy hurtboxes (prevents self/hurtbox/other overlaps)
	if not area.is_in_group("enemy_hurtbox"):
		return

	# Only once per kick
	if kick_hit_sfx_lock:
		return

	var enemy_node: Node = area.get_parent()
	if enemy_node and not enemy_node.has_method("apply_hitstop"):
		enemy_node = enemy_node.get_parent()

	_apply_kick_contact_feedback(enemy_node)
	print("KICK HIT:", area.name)


func _apply_kick_contact_feedback(enemy_node: Node = null) -> void:
	if kick_hit_sfx_lock:
		return
	kick_hit_sfx_lock = true
	var hitstop_frames_to_apply: int = CombatTuning.PLAYER_KICK_HITSTOP_FRAMES
	apply_hitstop(hitstop_frames_to_apply)
	if enemy_node and enemy_node.has_method("apply_hitstop"):
		enemy_node.call("apply_hitstop", hitstop_frames_to_apply)

	# Solid kicks already recoil physically; enemies retain the camera impulse.
	if screen_shake != null and not _solid_recoil_used:
		var facing: float = -1.0 if anim.flip_h else 1.0
		screen_shake.impulse_x(facing)

	if sfx_kick_hit and sfx_kick_hit.stream:
		sfx_kick_hit.play()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if world_exit_active:
		return
	if state == State.DEAD or curse_sequence_active:
		return
	if not area.is_in_group("enemy_attack"):
		return

	if not _overlapping_enemy_attack_areas.has(area):
		_overlapping_enemy_attack_areas.append(area)

	# TEMP: Gnome Boss teleport slam instant-kill.
	# Bypasses normal damage / iframes and forces death_air.
	if area.get_meta(&"gnome_teleport_slam_kill", false):
		hp = 0
		_apply_damage_camera_impulse(area)
		_die(true)
		return

	if invuln_timer > 0.0:
		return
	_take_damage(1, area)

func _on_hurtbox_area_exited(area: Area2D) -> void:
	if area in _overlapping_enemy_attack_areas:
		_overlapping_enemy_attack_areas.erase(area)

func _check_overlapping_enemy_attacks_after_invuln() -> void:
	if state == State.DEAD:
		return

	for area in _overlapping_enemy_attack_areas.duplicate():
		if not is_instance_valid(area):
			_overlapping_enemy_attack_areas.erase(area)
			continue

		if not area.is_in_group("enemy_attack"):
			_overlapping_enemy_attack_areas.erase(area)
			continue

		if area.overlaps_area($Hurtbox):
			_on_hurtbox_area_entered(area)
			return

## Directional combat camera impulse for a confirmed damaging hit.
## Call once after damage is confirmed, before _hurt() / _die().
func _apply_damage_camera_impulse(attack_area: Area2D = null) -> void:
	if screen_shake == null:
		return
	var hit_from: float = 0.0
	if attack_area != null and is_instance_valid(attack_area):
		hit_from = signf(attack_area.global_position.x - global_position.x)
	if is_zero_approx(hit_from):
		# Fallback: assume attack came from facing side (matches knockback).
		hit_from = -1.0 if anim.flip_h else 1.0
	# Force travels away from the attacker (hit from right → camera left).
	# hold=false: no hurt hitstop; settle starts immediately (same for fatal and nonfatal).
	screen_shake.impulse_x(-hit_from, false)


## Dedicated final-spell entry point: applies the curse without health damage.
func receive_stamina_curse(attack_area: Area2D) -> bool:
	if state == State.DEAD or curse_sequence_active or invuln_timer > 0.0 or SceneTransition.busy:
		return false
	var first_curse := not GameState.stamina_cursed
	if first_curse:
		GameState.stamina_cursed = true
		GameState.stamina_curse_reveal_pending = true
	if first_curse:
		# Keep impact feedback and the hurt pose, but never enter the HP/death path.
		_apply_damage_camera_impulse(attack_area)
		_hurt(attack_area)
		_begin_stamina_curse_reveal()
	return true

func _begin_stamina_curse_reveal() -> void:
	if curse_sequence_active or state == State.DEAD or not GameState.stamina_curse_reveal_pending:
		return
	add_child(STAMINA_CURSE_EFFECT.new())


## Returns true when the taco uses the staged gas presentation instead of the old toast.
func collect_stamina_taco() -> bool:
	if not GameState.stamina_cursed:
		return false
	if GameState.gas_transmuted and not GameState.gas_reveal_pending:
		return true
	GameState.gas_reveal_pending = true
	_begin_taco_gas_reveal()
	return true

func _begin_taco_gas_reveal() -> void:
	if curse_sequence_active or state == State.DEAD or not GameState.gas_reveal_pending:
		return
	var effect := STAMINA_CURSE_EFFECT.new()
	effect.gas_mode = true
	add_child(effect)


func _take_damage(amount: int, attack_area: Area2D = null) -> void:
	if world_exit_active:
		return
	hp = maxi(0, hp - amount)
	invuln_timer = HURT_IFRAME_TIME

	# Impulse first so fatal and nonfatal share one path before hurt/death branch.
	_apply_damage_camera_impulse(attack_area)

	if hp <= 0:
		_die()
	else:
		_hurt(attack_area)

func _hurt(attack_area: Area2D = null) -> void:
	reset_for_external_launch()
	_cancel_shooting()
	double_jump_anim_locked = false
	if state == State.ATTACKING:
		_disable_kick_hitbox()

	state = State.HURT
	_play_hurt_sound()
	lock_time = 0.0
	pending_jump = false
	crouch_momentum_timer = 0.0
	kick_momentum_timer = 0.0

	var facing: int = -1 if anim.flip_h else 1
	velocity = CombatTuning.resolve_player_hurt_knockback(
		attack_area, global_position, float(-facing), velocity.y
	)

	if frames and frames.has_animation("hurt"):
		_play("hurt")
		anim.animation_finished.connect(_on_hurt_anim_finished, CONNECT_ONE_SHOT)
	else:
		await get_tree().create_timer(0.12).timeout
		if state == State.HURT:
			state = State.AIR if not is_on_floor() else State.GROUND

func _on_hurt_anim_finished() -> void:
	if state != State.HURT:
		return
	state = State.AIR if not is_on_floor() else State.GROUND

# TEMP: force_death_air is currently used by Gnome Boss teleport slam instant-kill.
var _death_finished: bool = false

func _die(force_death_air: bool = false) -> void:
	if world_exit_active:
		return
	if state == State.DEAD or SceneTransition.busy:
		return
	state = State.DEAD
	GameState.consume_life()
	_reset_fart_cloud()
	reset_for_external_launch()
	wall_motion.reset(true)
	_cancel_shooting()
	double_jump_anim_locked = false
	var ui := get_tree().get_first_node_in_group("ui")
	if ui == null:
		# Development scenes may omit the normal HUD; still provide death recovery.
		ui = load("res://scenes/ui/UI.tscn").instantiate()
		get_parent().add_child(ui)
	if ui and ui.has_method("cancel_level_complete"):
		ui.cancel_level_complete()
	_play_hurt_sound()
	if sfx_death and sfx_death.stream:
		sfx_death.play()

	lock_time = 0.0
	pending_jump = false
	crouch_momentum_timer = 0.0
	kick_momentum_timer = 0.0
	anim.modulate = Color.WHITE

	_disable_kick_hitbox()
	if hurtbox_shape:
		hurtbox_shape.set_deferred("disabled", true)
	if body_shape:
		body_shape.set_deferred("disabled", true)

	var death_anim := "death"
	if force_death_air and frames and frames.has_animation(&"death_air"):
		death_anim = "death_air"
	elif not is_on_floor() and frames and frames.has_animation(&"death_air"):
		death_anim = "death_air"
	if frames and frames.has_animation(death_anim):
		_play(death_anim)
		anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_on_death_anim_finished.call_deferred()

func _on_death_anim_finished() -> void:
	if state != State.DEAD or _death_finished:
		return
	_death_finished = true
	if anim.animation == "death_air" and frames and frames.has_animation("death_air_loop"):
		# The reset wipe pauses gameplay; keep only the death sprite animating.
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		_play("death_air_loop")
	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("finish_player_death"):
		ui.finish_player_death()


# Called after collision resolution: requested velocity is not proof of movement.
func _tick_movement_resource(delta: float, direction: int, start_x: float, was_grounded: bool) -> void:
	if not movement_resource.enabled or _resource_suspended_this_tick or SceneTransition.busy or state == State.DEAD or hitstop_frames > 0:
		return
	var actual_speed: float = absf(global_position.x - start_x) / maxf(delta, 0.00001)
	var walk_speed: float = SPEED * _slow_multiplier
	var running: bool = false
	if was_grounded:
		resource_running_carry = false
		running = is_running and direction != 0 and actual_speed > 0.1 and state == State.GROUND and not is_crouching and not shooting
		# Walking off an edge can also inherit running momentum.
		if not is_on_floor() and running and absf(velocity.x) > walk_speed:
			resource_running_carry = true
	else:
		if state == State.HURT:
			resource_running_carry = false
		running = resource_running_carry and actual_speed > walk_speed and state == State.AIR and not shooting
	movement_resource.tick(delta, running, not is_on_floor())
	if is_on_floor():
		resource_running_carry = false

func _spend_movement_resource(amount: float) -> void:
	if not _resource_suspended_this_tick and not SceneTransition.busy and state != State.DEAD and hitstop_frames <= 0:
		movement_resource.spend_jump(amount)


func _on_movement_resource_enabled_changed(active: bool) -> void:
	if not active:
		resource_kick_buffer_time = 0.0

# Only buffers an otherwise valid kick denied for insufficient resource.
func _resource_kick_requested(delta: float, can_input: bool) -> bool:
	var eligible: bool = can_input and state == State.GROUND and lock_time <= 0.0 and is_on_floor()
	var pressed: bool = Input.is_action_just_pressed("kick_long")
	if not movement_resource.enabled:
		resource_kick_buffer_time = 0.0
		return eligible and pressed
	if SceneTransition.busy or not eligible:
		resource_kick_buffer_time = 0.0
		return false
	if _resource_suspended_this_tick or hitstop_frames > 0:
		return false
	resource_kick_buffer_time = maxf(0.0, resource_kick_buffer_time - delta)
	if pressed:
		resource_kick_buffer_time = RESOURCE_KICK_BUFFER_DURATION
	if resource_kick_buffer_time <= 0.0 or not movement_resource.can_kick():
		return false
	resource_kick_buffer_time = 0.0
	return true
