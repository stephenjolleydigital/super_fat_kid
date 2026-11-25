extends Area2D

@export var direction: int = 1
@export var speed: float = 260.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sfx_hit: AudioStreamPlayer2D = $SFX_Hit

var _hit_landed: bool = false


func _ready() -> void:
	add_to_group("enemy_attack")
	direction = -1 if direction < 0 else 1
	_apply_facing()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	on_screen.screen_exited.connect(queue_free)

	_play_if_exists(&"stinger_fly")


func set_direction_x(dir: int) -> void:
	direction = -1 if dir < 0 else 1
	_apply_facing()


func _physics_process(delta: float) -> void:
	if _hit_landed:
		return
	global_position.x += float(direction) * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit_landed:
		return

	if has_meta("spawner_body") and body == get_meta("spawner_body"):
		return

	if body.is_in_group("player"):
		return

	_hit()


func _on_area_entered(area: Area2D) -> void:
	if _hit_landed:
		return

	if area.is_in_group("player_hurtbox"):
		_hit()


func _hit() -> void:
	if _hit_landed:
		return

	_hit_landed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"stinger_hit"):
		sprite.play(&"stinger_hit")
		_play_sfx(sfx_hit)
		sprite.animation_finished.connect(_on_hit_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_hit_finished() -> void:
	queue_free()


func _apply_facing() -> void:
	if sprite:
		sprite.flip_h = direction > 0


func _play_if_exists(anim_name: StringName) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()
