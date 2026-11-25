extends Area2D

## Slow drift speed in pixels/second. Tune later.
const DRIFT_SPEED_PX_PER_SEC := 40.0
## Lifetime before auto-dissipation. Tune later.
const LIFETIME_SEC := 2.5

## Set by the spawner before add_child so _ready sees the correct direction.
## Default matches the boss's canonical facing (LEFT).
var direction: Vector2 = Vector2.LEFT

## One-shot guard so a single sigil never hits / dissipates twice.
var _hit_landed: bool = false

## Scene default CollisionShape2D.position.x (mirrored with travel direction).
var _collision_offset_x_default: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- SFX ---
@onready var _sfx_fly: AudioStreamPlayer2D = $SFX_Fly
@onready var _sfx_hit: AudioStreamPlayer2D = $SFX_Hit


func _ready() -> void:
	# Player auto-applies 1 damage to any enemy_attack area entering its Hurtbox.
	# Matches Gnome_Magicball / bird_poop / sewer_slug_spit convention.
	add_to_group("enemy_attack")

	_collision_offset_x_default = collision_shape.position.x
	animated_sprite.flip_h = direction.x < 0.0
	# Mirror the collision offset so the hitbox stays on the forward side of the sprite.
	collision_shape.position.x = _collision_offset_x_default * sign(direction.x)

	animated_sprite.play(&"fly")
	_play_sfx(_sfx_fly)
	area_entered.connect(_on_area_entered)
	# Ghostly: intentionally no body_entered. Sigil drifts through walls/tiles.

	# Auto-dissipate after a short lifetime even if it never hits the player.
	get_tree().create_timer(LIFETIME_SEC).timeout.connect(_on_lifetime_expired)


func _physics_process(delta: float) -> void:
	if _hit_landed:
		return
	position += direction * DRIFT_SPEED_PX_PER_SEC * delta


func _on_area_entered(area: Area2D) -> void:
	if _hit_landed:
		return
	if not area.is_in_group("player_hurtbox"):
		return
	_splat()


func _on_lifetime_expired() -> void:
	if _hit_landed:
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
	# Covers both player-hit (_on_area_entered) and lifetime-expire (_on_lifetime_expired) paths.
	animated_sprite.animation_finished.connect(_on_hit_animation_finished, CONNECT_ONE_SHOT)


func _on_hit_animation_finished() -> void:
	if _sfx_hit and _sfx_hit.playing:
		await _sfx_hit.finished
	queue_free()


## SFX
func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if p and p.stream:
		p.play()
