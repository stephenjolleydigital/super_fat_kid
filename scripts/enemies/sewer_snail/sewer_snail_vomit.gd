extends Area2D

@export var direction: int = 1
@export var lifetime: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _life_timer: float = 0.0
var _disappearing: bool = false


func _ready() -> void:
	add_to_group("enemy_attack")
	direction = -1 if direction < 0 else 1
	_life_timer = lifetime

	on_screen.screen_exited.connect(queue_free)

	# Snail family art is authored facing right; direction -1 mirrors it.
	# Mirroring the authored offset keeps the pile centered on the origin
	# so it matches the snail's baked-in barf pile for either facing.
	sprite.flip_h = direction < 0
	if direction < 0:
		sprite.offset.x = -sprite.offset.x
	_play_if_exists("idle")


func _physics_process(delta: float) -> void:
	if _disappearing:
		return

	_life_timer = maxf(0.0, _life_timer - delta)
	if _life_timer <= 0.0:
		_disappear()


func _disappear() -> void:
	if _disappearing:
		return

	_disappearing = true
	# Stop the surface bubbles while the existing pile disappearance plays.
	$PuddleBubbles.enabled = false
	remove_from_group("enemy_attack")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("disappear"):
		sprite.play("disappear")
		sprite.animation_finished.connect(_on_disappear_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_disappear_finished() -> void:
	queue_free()


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
