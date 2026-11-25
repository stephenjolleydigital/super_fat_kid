extends Node2D

## Horizontal fly speed in pixels per second.
@export var speed: float = 120.0
## 1 = move right (art as drawn), -1 = move left (flip_h).
@export var direction_x: int = 1
@export var trigger_size: Vector2 = Vector2(650, 160)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _trigger_area: Area2D = $TriggerArea
@onready var _trigger_shape: CollisionShape2D = $TriggerArea/CollisionShape2D
@onready var _on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _sfx_activate: AudioStreamPlayer2D = $SFX_Activate

var _is_active: bool = false


func _ready() -> void:
	direction_x = -1 if direction_x < 0 else 1

	_apply_trigger_layout()
	_apply_facing()

	_attack_hitbox.monitoring = false
	_sprite.animation = &"buzz"
	_sprite.frame = 0
	_sprite.stop()

	_trigger_area.body_entered.connect(_on_trigger_body_entered)
	_on_screen.screen_exited.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	position.x += float(direction_x) * speed * delta


func _apply_trigger_layout() -> void:
	var trigger_rect := _trigger_shape.shape as RectangleShape2D
	if trigger_rect:
		trigger_rect.size = trigger_size

	var offset_x := -trigger_size.x * 0.5 if direction_x < 0 else trigger_size.x * 0.5
	_trigger_shape.position = Vector2(offset_x, 0.0)


func _apply_facing() -> void:
	_sprite.flip_h = direction_x < 0


func _on_trigger_body_entered(body: Node) -> void:
	if _is_active:
		return
	if not body.is_in_group("player"):
		return

	_is_active = true
	_apply_facing()

	if _sfx_activate.stream:
		_sfx_activate.play()

	_sprite.play(&"buzz")
	_attack_hitbox.monitoring = true
	_trigger_area.set_deferred("monitoring", false)
