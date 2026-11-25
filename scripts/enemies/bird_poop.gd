extends Area2D

## Downward speed in pixels per second while falling.
@export var fall_speed: float = 120.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _sfx_drop: AudioStreamPlayer2D = $SFX_Drop
@onready var _sfx_splat: AudioStreamPlayer2D = $SFX_Splat

var _splatted: bool = false


func _ready() -> void:
	add_to_group("enemy_attack")
	_on_screen.screen_exited.connect(queue_free)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_sprite.play("fall")
	if _sfx_drop.stream:
		_sfx_drop.play()


func _physics_process(delta: float) -> void:
	if _splatted:
		return
	global_position.y += fall_speed * delta


func _try_hit(other: Node) -> void:
	if _splatted:
		return
	if other == self or is_ancestor_of(other) or other.is_ancestor_of(self):
		return

	if other.has_method("take_damage"):
		other.call("take_damage", 1)

	_splatted = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_sprite.play("splat")
	if _sfx_splat.stream:
		_sfx_splat.play()
	if not _sprite.animation_finished.is_connected(_on_splat_finished):
		_sprite.animation_finished.connect(_on_splat_finished, CONNECT_ONE_SHOT)


func _on_splat_finished() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Player damage uses Hurtbox (area_entered + enemy_attack), not the CharacterBody2D.
	if body.is_in_group("player"):
		return
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	# Match mall-cop style: player contact goes through player_hurtbox only.
	if not area.is_in_group("player_hurtbox"):
		return
	_try_hit(area)
