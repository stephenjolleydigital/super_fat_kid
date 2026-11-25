extends CharacterBody2D

@export var max_hp: int = 1
@export var fly_speed: float = 95.0
@export var drop_distance: float = 14.0
@export var drop_duration: float = 0.15
@export var sonar_cooldown: float = 1.0
@export var sonar_approach_distance: float = 40.0
@export var face_cooldown: float = 0.35
@export var face_deadzone: float = 8.0
@export var sonar_damage_frame_start: int = 2
@export var sonar_damage_frame_end: int = 4

enum State { HANGING, WAKING, FLYING, SONAR, DEAD }

var state: State = State.HANGING
var hp: int = 1
var dead: bool = false
var fatal_hitstop_active: bool = false
var facing: int = 1

var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false

var _sonar_cooldown_timer: float = 0.0
var _face_cooldown_timer: float = 0.0
var _sonar_hit_landed: bool = false

var _hang_position: Vector2 = Vector2.ZERO
var _drop_progress: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var sonar_hitbox: Area2D = $SonarHitbox
@onready var sonar_hitbox_shape: CollisionShape2D = $SonarHitbox/CollisionShape2D
@onready var wake_zone: Area2D = $WakeZone
@onready var wake_sfx: AudioStreamPlayer2D = $WakeSfx
@onready var fly_sfx: AudioStreamPlayer2D = $FlySfx
@onready var sonar_sfx: AudioStreamPlayer2D = $SonarSfx
@onready var die_sfx: AudioStreamPlayer2D = $DieSfx


func _ready() -> void:
	hp = maxi(1, max_hp)
	_hang_position = global_position

	hurtbox.add_to_group("enemy_hurtbox")
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if not wake_zone.body_entered.is_connected(_on_wake_zone_body_entered):
		wake_zone.body_entered.connect(_on_wake_zone_body_entered)

	if not sonar_hitbox.area_entered.is_connected(_on_sonar_hitbox_area_entered):
		sonar_hitbox.area_entered.connect(_on_sonar_hitbox_area_entered)

	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	_set_contact_hitbox_active(false)
	_set_sonar_hitbox_active(false)

	sprite.animation = &"idle"
	sprite.frame = 0
	sprite.stop()
	_update_facing_visual()


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func _physics_process(delta: float) -> void:
	if fatal_hitstop_active:
		velocity = Vector2.ZERO
		if hitstop_frames > 0:
			hitstop_frames -= 1
			if sprite:
				if sprite.animation != &"die" and sprite.sprite_frames and sprite.sprite_frames.has_animation("die"):
					sprite.play("die")
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

	if dead:
		velocity = Vector2.ZERO
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

	match state:
		State.HANGING:
			velocity = Vector2.ZERO
		State.WAKING:
			_process_waking(delta)
		State.FLYING:
			_process_flying(delta)
		State.SONAR:
			_process_sonar(delta)
		State.DEAD:
			velocity = Vector2.ZERO


func _process_waking(delta: float) -> void:
	velocity = Vector2.ZERO
	if drop_duration <= 0.0:
		_drop_progress = 1.0
	else:
		_drop_progress = minf(1.0, _drop_progress + delta / drop_duration)
	global_position.y = _hang_position.y + drop_distance * _drop_progress


func _process_flying(delta: float) -> void:
	if _face_cooldown_timer > 0.0:
		_face_cooldown_timer = maxf(0.0, _face_cooldown_timer - delta)
	if _sonar_cooldown_timer > 0.0:
		_sonar_cooldown_timer = maxf(0.0, _sonar_cooldown_timer - delta)

	var player := _get_player()
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance_to_player: float = to_player.length()

	# Close attack range + sonar ready: hard-brake and blast before another chase step.
	if _sonar_cooldown_timer <= 0.0 and distance_to_player <= sonar_approach_distance:
		velocity = Vector2.ZERO
		_enter_sonar()
		return

	_try_update_facing(player)
	if distance_to_player > sonar_approach_distance:
		# Chase toward the player until the close sonar attack position.
		velocity = to_player / distance_to_player * fly_speed
	else:
		# Cooldown not ready: hold at/near attack distance; do not drive through center.
		velocity = Vector2.ZERO
	move_and_slide()


func _process_sonar(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _enter_waking() -> void:
	state = State.WAKING
	_hang_position = global_position
	_drop_progress = 0.0
	wake_zone.set_deferred("monitoring", false)

	var player := _get_player()
	if player != null:
		var dx: float = player.global_position.x - global_position.x
		if absf(dx) > 0.01:
			facing = 1 if dx > 0.0 else -1
			_update_facing_visual()

	_play_if_exists("wake")
	_play_sfx(wake_sfx)


func _enter_flying() -> void:
	state = State.FLYING
	_set_contact_hitbox_active(true)
	_set_sonar_hitbox_active(false)
	# First chase after wake can sonar as soon as the bat gets close.
	_sonar_cooldown_timer = 0.0
	_play_if_exists("fly")


func _enter_flying_from_sonar() -> void:
	state = State.FLYING
	_set_sonar_hitbox_active(false)
	_sonar_cooldown_timer = sonar_cooldown
	_set_contact_hitbox_active(true)
	_play_if_exists("fly")


func _enter_sonar() -> void:
	state = State.SONAR
	_sonar_hit_landed = false
	velocity = Vector2.ZERO
	_set_sonar_hitbox_active(false)
	_play_if_exists("sonar")
	_play_sfx(sonar_sfx)
	_sync_sonar_hitbox_for_frame()


func _try_update_facing(player: Node2D) -> void:
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) <= face_deadzone:
		return
	var desired: int = 1 if dx > 0.0 else -1
	if desired == facing:
		return
	if _face_cooldown_timer > 0.0:
		return
	facing = desired
	_face_cooldown_timer = face_cooldown
	_update_facing_visual()


func _update_facing_visual() -> void:
	sprite.flip_h = facing < 0


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		else:
			sprite.play(anim_name)


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player and player.stream:
		player.play()


func _on_wake_zone_body_entered(body: Node) -> void:
	if dead or state != State.HANGING:
		return
	if not body.is_in_group("player"):
		return
	_enter_waking()


func _on_sprite_frame_changed() -> void:
	if not dead and not fatal_hitstop_active and sprite.animation == &"fly" and sprite.frame == 1:
		_play_sfx(fly_sfx)

	if dead or state != State.SONAR:
		return
	if sprite.animation != &"sonar":
		return
	_sync_sonar_hitbox_for_frame()


func _sync_sonar_hitbox_for_frame() -> void:
	if dead or state != State.SONAR or _sonar_hit_landed:
		_set_sonar_hitbox_active(false)
		return
	if sprite.animation != &"sonar":
		_set_sonar_hitbox_active(false)
		return
	var frame: int = sprite.frame
	var active: bool = (
		frame >= sonar_damage_frame_start
		and frame <= sonar_damage_frame_end
	)
	_set_sonar_hitbox_active(active)


func _on_sonar_hitbox_area_entered(area: Area2D) -> void:
	if dead or state != State.SONAR or _sonar_hit_landed:
		return
	if not area.is_in_group("player_hurtbox"):
		return
	_sonar_hit_landed = true
	_set_sonar_hitbox_active(false)


func _set_contact_hitbox_active(active: bool) -> void:
	if not is_instance_valid(contact_hitbox):
		return
	if active:
		if not contact_hitbox.is_in_group("enemy_attack"):
			contact_hitbox.add_to_group("enemy_attack")
	else:
		if contact_hitbox.is_in_group("enemy_attack"):
			contact_hitbox.remove_from_group("enemy_attack")
	contact_hitbox.set_deferred("monitoring", active)
	contact_hitbox.set_deferred("monitorable", active)
	if is_instance_valid(contact_hitbox_shape):
		contact_hitbox_shape.set_deferred("disabled", not active)


func _set_sonar_hitbox_active(active: bool) -> void:
	if not is_instance_valid(sonar_hitbox):
		return
	if active:
		if not sonar_hitbox.is_in_group("enemy_attack"):
			sonar_hitbox.add_to_group("enemy_attack")
	else:
		if sonar_hitbox.is_in_group("enemy_attack"):
			sonar_hitbox.remove_from_group("enemy_attack")
	sonar_hitbox.set_deferred("monitoring", active)
	sonar_hitbox.set_deferred("monitorable", active)
	if is_instance_valid(sonar_hitbox_shape):
		sonar_hitbox_shape.set_deferred("disabled", not active)


func _on_animation_finished() -> void:
	if dead:
		if sprite.animation == &"die":
			queue_free()
		return

	match state:
		State.WAKING:
			if sprite.animation == &"wake":
				if _drop_progress < 1.0:
					global_position.y = _hang_position.y + drop_distance
					_drop_progress = 1.0
				_enter_flying()
		State.SONAR:
			if sprite.animation == &"sonar":
				_enter_flying_from_sonar()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or fatal_hitstop_active:
		return
	if not area.is_in_group("player_attack"):
		return

	if area.name == "KickHitbox":
		var kick_pivot := area.get_parent()
		var kick_owner: Node = kick_pivot.get_parent() if kick_pivot else null
		if kick_owner != null and kick_owner.has_method("register_kick_damage_target"):
			if not kick_owner.register_kick_damage_target(self):
				return

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
	_play_sfx(die_sfx)

	_set_contact_hitbox_active(false)
	_set_sonar_hitbox_active(false)
	if is_instance_valid(wake_zone):
		wake_zone.set_deferred("monitoring", false)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitoring", false)
	if is_instance_valid(hurtbox_shape):
		hurtbox_shape.set_deferred("disabled", true)
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
		sprite.frame = 0
		sprite.pause()
		_hitstop_sprite_paused = true
	elif sprite and hitstop_frames > 0 and not _hitstop_sprite_paused:
		sprite.pause()
		_hitstop_sprite_paused = true


func _begin_death_sequence() -> void:
	velocity = Vector2.ZERO
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("die"):
		sprite.frame = 0
		sprite.play("die")
	else:
		queue_free()
