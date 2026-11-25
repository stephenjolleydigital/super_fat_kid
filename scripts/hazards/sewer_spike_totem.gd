extends StaticBody2D

@export_group("Timing")
@export_range(0.05, 2.0, 0.01, "suffix:s") var retract_duration: float = 0.08

@export_group("Sounds")
@export var warning_sound: AudioStream
@export var strike_sound: AudioStream
@export var retract_sound: AudioStream

@onready var sprite: Sprite2D = $Sprite
@onready var trigger: Area2D = $Proximity
@onready var hitbox: CollisionShape2D = $Strike/CollisionShape2D
@onready var timer: Timer = $PhaseTimer
@onready var audio: AudioStreamPlayer2D = $PhaseSound

var cycling := false

func _ready() -> void:
	$Strike.set_meta(&"hurt_knockback_provider", _strike_knockback)

func _physics_process(_delta: float) -> void:
	if cycling:
		return
	for body in trigger.get_overlapping_bodies():
		if body.is_in_group(&"player"):
			_cycle()
			return
	# Enemy roots do not share a group; their hurtboxes identify them.
	for area in trigger.get_overlapping_areas():
		if area.is_in_group(&"enemy_hurtbox") and area.get_parent().get("dead") != true:
			_cycle()
			return

func _cycle() -> void:
	cycling = true
	sprite.frame = 1 # Only the tips peek out during the warning.
	_play_sound(warning_sound)
	timer.start(0.45)
	await timer.timeout

	sprite.frame = 3
	hitbox.disabled = false
	_play_sound(strike_sound)
	timer.start(0.55)
	await timer.timeout

	hitbox.disabled = true
	sprite.frame = 2
	_play_sound(retract_sound)
	timer.start(retract_duration)
	await timer.timeout

	sprite.frame = 0
	timer.start(1.0)
	await timer.timeout
	cycling = false

func _play_sound(stream: AudioStream) -> void:
	if stream != null:
		audio.stream = stream
		audio.play()

func _strike_knockback(player_position: Vector2, fallback_direction: float) -> Vector2:
	return CombatTuning.enemy_hit_knockback(player_position, global_position, fallback_direction, 160.0, 100.0)
