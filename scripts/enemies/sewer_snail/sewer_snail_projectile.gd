extends Area2D

@export var direction: int = 1
@export var speed: float = 150.0
## Launch horizontally, then arc down after a short delay.
@export_range(-45.0, 45.0, 0.5) var launch_angle_degrees: float = 0.0
@export var gravity_delay: float = 0.25
@export var fall_gravity: float = 520.0
@export var max_fall_speed: float = 360.0
@export var lifetime: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sfx_impact: AudioStreamPlayer2D = get_node_or_null("SFX_Impact") as AudioStreamPlayer2D

var velocity: Vector2 = Vector2.ZERO
var _flight_time: float = 0.0
var _life_timer: float = 0.0
var _splatted: bool = false


func _ready() -> void:
	add_to_group("enemy_attack")
	direction = -1 if direction < 0 else 1
	_life_timer = lifetime
	var launch_angle := deg_to_rad(launch_angle_degrees)
	velocity = Vector2(cos(launch_angle) * float(direction), -sin(launch_angle)) * speed

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	on_screen.screen_exited.connect(queue_free)

	# Snail family art is authored facing right; flip to face left.
	sprite.flip_h = direction < 0
	_update_flight_rotation()
	_play_if_exists("fly")


func _physics_process(delta: float) -> void:
	if _splatted:
		return

	_life_timer = maxf(0.0, _life_timer - delta)
	if _life_timer <= 0.0:
		_splat()
		return

	if _flight_time >= gravity_delay:
		velocity.y = minf(velocity.y + fall_gravity * delta, max_fall_speed)
	_flight_time += delta
	_update_flight_rotation()
	global_position += velocity * delta


func _update_flight_rotation() -> void:
	# Account for the mirrored art when aiming along the flight direction.
	# Only rotate the sprite; the circular hitbox and screen notifier stay fixed.
	# Splat keeps this last flight angle because physics stops updating on impact.
	sprite.rotation = velocity.angle() - (PI if direction < 0 else 0.0)


func _on_body_entered(body: Node2D) -> void:
	if _splatted:
		return

	if has_meta("spawner_body") and body == get_meta("spawner_body"):
		return

	# Keep player damage routed through player_hurtbox only.
	if body.is_in_group("player"):
		return

	_splat()


func _on_area_entered(area: Area2D) -> void:
	if _splatted:
		return

	if area.is_in_group("player_hurtbox"):
		_splat()


func _splat() -> void:
	if _splatted:
		return

	_splatted = true
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)

	_play_sfx(sfx_impact)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("splat"):
		sprite.play("splat")
		sprite.animation_finished.connect(_on_splat_finished, CONNECT_ONE_SHOT)
	else:
		_finish_splat()


func _on_splat_finished() -> void:
	_finish_splat()


func _finish_splat() -> void:
	# Let the impact cue finish before freeing so it is never cut off; collisions
	# are already disabled above, so waiting does not change gameplay.
	if is_instance_valid(sfx_impact) and sfx_impact.playing:
		await sfx_impact.finished
	queue_free()


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
