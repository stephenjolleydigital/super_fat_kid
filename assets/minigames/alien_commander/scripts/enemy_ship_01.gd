extends Area2D

signal destroyed

const ENEMY_BULLET_SCENE := preload("res://assets/minigames/alien_commander/scenes/Enemy_Bullet.tscn")
const TELEGRAPH_MODULATE := Color(1.15, 1.15, 1.0, 1.0)

# Move -> telegraph -> fire -> recover keeps hunting readable for the player.
enum HuntState { HUNT, TELEGRAPH, RECOVER }

@export var auto_fire: bool = true
@export var move_speed: float = 48.0
@export var aim_range: float = 1.0
@export var fire_cooldown: float = 0.45
@export var telegraph_time: float = 0.44

# Wave pressure: firing cadence ramps up with elapsed wave time so the player can't
# stall forever by micro-dodging with 1-2 surviving aliens. Baseline exports above are
# the pressure-0 values; the mins below are the capped late-wave values. A new wave is
# currently a scene reload, which resets the timer for free.
@export var pressure_grace_time: float = 10.0
@export var pressure_ramp_time: float = 50.0
@export var min_fire_cooldown: float = 0.15
@export var min_telegraph_time: float = 0.25
@export var max_move_speed: float = 96.0
# Telegraph tracking strength: 0 = freeze while telegraphing (baseline feel),
# 1 = full-speed follow. Scaled by pressure so late-wave aim commits later.
@export var telegraph_tracking: float = 0.0
@export var max_telegraph_tracking: float = 0.7

var _state: HuntState = HuntState.HUNT
var _state_timer := 0.0
var _target_alien: Area2D = null
var _lives := 10
var _formation: Node = null
var _wave_time := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bullet_spawn: Marker2D = $BulletSpawn_01
@onready var _bullets_root: Node2D = $"../EnemyBullets"


func _ready() -> void:
	_formation = get_parent().get_node_or_null("AlienFormation")
	_pick_target()


func _process(delta: float) -> void:
	if not auto_fire or not _can_shoot():
		return
	# Only ticks during active play, so pressure can't build on win/loss screens.
	_wave_time += delta
	if not _ensure_target():
		return

	match _state:
		HuntState.HUNT:
			_update_hunt(delta)
		HuntState.TELEGRAPH:
			_update_telegraph(delta)
		HuntState.RECOVER:
			_update_recover(delta)


func take_damage(_amount: int) -> void:
	if _lives <= 0:
		return
	_lives -= 1
	var audio := ACAudio.find_audio(self)
	if _lives > 0:
		if audio:
			audio.play_enemy_ship_hurt()
		return
	if audio:
		audio.play_enemy_ship_death()
	$Sprite2D.visible = false
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	destroyed.emit()


func _update_hunt(delta: float) -> void:
	var target_x := _target_alien.global_position.x
	var dx := target_x - global_position.x
	if absf(dx) <= aim_range:
		_enter_telegraph()
		return

	position.x += signf(dx) * _effective_move_speed() * delta
	_clamp_and_snap_x()

	if absf(target_x - global_position.x) <= aim_range:
		_enter_telegraph()


func _update_telegraph(delta: float) -> void:
	# Brief stop gives the player a dodge window before the shot lands.
	_track_during_telegraph(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_fire_and_recover()


func _track_during_telegraph(delta: float) -> void:
	# Late-wave pressure: drift toward the target's live X instead of committing to a
	# stale aim point. Strength 0 (baseline) reproduces the original full freeze.
	var strength := lerpf(telegraph_tracking, max_telegraph_tracking, _pressure())
	if strength <= 0.0 or not _is_target_valid():
		return
	var dx := _target_alien.global_position.x - global_position.x
	if absf(dx) <= aim_range:
		return
	var step := _effective_move_speed() * strength * delta
	position.x += signf(dx) * minf(step, absf(dx))
	_clamp_and_snap_x()


func _effective_move_speed() -> float:
	return lerpf(move_speed, max_move_speed, _pressure())


func _update_recover(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_pick_target()
		_state = HuntState.HUNT


func _enter_telegraph() -> void:
	_snap_aim_to_target()
	_state = HuntState.TELEGRAPH
	_state_timer = lerpf(telegraph_time, min_telegraph_time, _pressure())
	_sprite.modulate = TELEGRAPH_MODULATE


func _fire_and_recover() -> void:
	_sprite.modulate = Color.WHITE
	_spawn_bullet()
	_state = HuntState.RECOVER
	_state_timer = lerpf(fire_cooldown, min_fire_cooldown, _pressure())


func _pressure() -> float:
	# 0.0 for the grace period, then linear to a hard cap of 1.0.
	if pressure_ramp_time <= 0.0:
		return 1.0 if _wave_time >= pressure_grace_time else 0.0
	return clampf((_wave_time - pressure_grace_time) / pressure_ramp_time, 0.0, 1.0)


func _pick_target() -> void:
	# Random living aliens spread pressure across the formation, not just the selected one.
	_target_alien = null
	if _formation == null or not is_instance_valid(_formation):
		return
	if not _formation.has_method(&"get_living_aliens"):
		return
	var living: Array = _formation.call(&"get_living_aliens")
	if living.is_empty():
		return
	_target_alien = living[randi() % living.size()] as Area2D


func _ensure_target() -> bool:
	if _is_target_valid():
		return true
	_pick_target()
	return _is_target_valid()


func _is_target_valid() -> bool:
	return _target_alien != null and is_instance_valid(_target_alien) and _target_alien.is_inside_tree()


func _snap_aim_to_target() -> void:
	# BulletSpawn shares the ship origin X; snap so the vertical shot path hits the alien center.
	if not _is_target_valid():
		return
	position.x += _target_alien.global_position.x - global_position.x
	_clamp_and_snap_x()


func _get_move_x_bounds() -> Vector2:
	# Derive margins from sprite width so the ship can use the full playfield without clipping.
	var half_w := 32.0
	if _sprite.texture:
		half_w = ceilf(_sprite.texture.get_width() * 0.5)
	var playfield_w := ACPlayfield.RECT.size.x
	return Vector2(half_w, playfield_w - half_w)


func _clamp_and_snap_x() -> void:
	var bounds := _get_move_x_bounds()
	position.x = clampf(roundf(position.x), bounds.x, bounds.y)


func _spawn_bullet() -> void:
	var bullet: Node2D = ENEMY_BULLET_SCENE.instantiate()
	_bullets_root.add_child(bullet)
	bullet.global_position = _bullet_spawn.global_position
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_enemy_ship_shoot()


func _can_shoot() -> bool:
	var game := get_parent()
	if game != null and game.has_method(&"is_playing"):
		return game.is_playing()
	return true
