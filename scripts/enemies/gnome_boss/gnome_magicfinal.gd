extends Area2D
## The last spell survives its caster, ignores terrain, and pursues the player.
@export var initial_speed: float = 65.0
@export var acceleration: float = 22.0
@export var maximum_speed: float = 300.0
var direction := Vector2.LEFT
var speed := 65.0
var _age := 0.0
var _spent := false
var _target: Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Curse-only contact: never join enemy_attack, which would cause generic HP damage.
	speed = initial_speed
	direction = direction.normalized()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_target = get_tree().get_first_node_in_group("player") as Node2D
	sprite.play(&"fly")
	$SFX_Fly.play()
	_update_heading()

func _physics_process(delta: float) -> void:
	if _spent or SceneTransition.busy:
		return
	if not is_instance_valid(_target) or _target.state == _target.State.DEAD:
		queue_free()
		return
	_age += delta
	speed = minf(maximum_speed, initial_speed + acceleration * _age)
	var target_position: Vector2 = _target.hurtbox.global_position
	var to_target := target_position - global_position
	# Tighten steering near the target to prevent a fast projectile orbiting forever.
	var turn_rate := maxf(2.0 + _age * 0.45, speed / maxf(to_target.length(), 12.0) * 2.0)
	direction = Vector2.from_angle(rotate_toward(direction.angle(), to_target.angle(), turn_rate * delta))
	global_position += direction * speed * delta
	_update_heading()
	if overlaps_area(_target.hurtbox):
		# Retry during ordinary damage immunity; dodging or iframes cannot erase the curse.
		if _target.receive_stamina_curse(self):
			_impact()

func _update_heading() -> void:
	# Sixteen crisp facings; rotate the art rather than flipping the trailing flame.
	sprite.rotation = snappedf(direction.angle(), TAU / 16.0)
	shape.position = (direction * 3.0).round()
	sprite.global_position = global_position.round()

func _impact() -> void:
	_spent = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	shape.set_deferred("disabled", true)
	$SFX_Fly.stop()
	sprite.play(&"hit")
	$SFX_Hit.play()
	await sprite.animation_finished
	sprite.hide()
	if $SFX_Hit.playing:
		await $SFX_Hit.finished
	queue_free()
