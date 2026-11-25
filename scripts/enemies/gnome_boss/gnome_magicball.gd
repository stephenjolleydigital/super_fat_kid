extends Area2D

## Constant flight speed in pixels/second. Tune later.
const SPEED_PX_PER_SEC := 120.0

## Set by the spawner before add_child so _ready sees the correct direction.
## Default matches the boss's canonical facing (LEFT).
var direction: Vector2 = Vector2.LEFT

## One-shot guard so a single ball never hits twice.
var _hit_landed: bool = false

## Scene default CollisionShape2D.position.x (mirrored with travel direction).
var _collision_offset_x_default: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var off_screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# --- SFX ---
@onready var _sfx_fly: AudioStreamPlayer2D = $SFX_Fly
@onready var _sfx_hit: AudioStreamPlayer2D = $SFX_Hit


func _ready() -> void:
	# Player auto-applies 1 damage to any enemy_attack area entering its Hurtbox
	# (see Player._on_hurtbox_area_entered). Matches bird_poop / sewer_slug_spit convention.
	add_to_group("enemy_attack")

	_collision_offset_x_default = collision_shape.position.x
	# Art is drawn facing right; flip when traveling left so the trail follows the motion.
	animated_sprite.flip_h = direction.x < 0.0
	# Mirror the collision offset so the hitbox stays on the forward side of the sprite.
	collision_shape.position.x = _collision_offset_x_default * sign(direction.x)

	animated_sprite.play(&"fly")
	_play_sfx(_sfx_fly)
	off_screen_notifier.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _hit_landed:
		return
	position += direction * SPEED_PX_PER_SEC * delta


func _on_area_entered(area: Area2D) -> void:
	if _hit_landed:
		return
	if not area.is_in_group("player_hurtbox"):
		return
	_splat()


func _on_body_entered(body: Node2D) -> void:
	if _hit_landed:
		return
	# Player damage routes through player_hurtbox only; matches bird_poop / sewer_slug_spit.
	if body.is_in_group("player"):
		return
	_splat()


func _splat() -> void:
	_hit_landed = true
	# Stop colliding so we cannot trigger again or eat extra signals while 'hit' plays.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)

	animated_sprite.play(&"hit")
	_play_sfx(_sfx_hit)
	# Wait for hit anim AND hit SFX tail before freeing so the splat is not cut off.
	# Damage/collisions are already disabled above, so the wait does not change gameplay.
	animated_sprite.animation_finished.connect(_on_hit_animation_finished, CONNECT_ONE_SHOT)


func _on_hit_animation_finished() -> void:
	if _sfx_hit and _sfx_hit.playing:
		await _sfx_hit.finished
	queue_free()


## SFX
func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if p and p.stream:
		p.play()
