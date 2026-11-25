extends Area2D

## Constant fall speed in pixels/second. Tune later.
const FALL_SPEED_PX_PER_SEC := 120.0

## One-shot guard so a single drop never hits / dissipates twice.
var _hit_landed: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var off_screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# --- SFX ---
@onready var _sfx_fall: AudioStreamPlayer2D = $SFX_Fall
@onready var _sfx_hit: AudioStreamPlayer2D = $SFX_Hit


func _ready() -> void:
	# Player auto-applies 1 damage to any enemy_attack area entering its Hurtbox.
	# Matches Gnome_Magicball / bird_poop / sewer_slug_spit convention.
	add_to_group("enemy_attack")

	animated_sprite.play(&"fall")
	_play_sfx(_sfx_fall)
	off_screen_notifier.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _hit_landed:
		return
	position.y += FALL_SPEED_PX_PER_SEC * delta


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
	# The off-screen path (off_screen_notifier.screen_exited -> queue_free) is unchanged.
	animated_sprite.animation_finished.connect(_on_hit_animation_finished, CONNECT_ONE_SHOT)


func _on_hit_animation_finished() -> void:
	if _sfx_hit and _sfx_hit.playing:
		await _sfx_hit.finished
	queue_free()


## SFX
func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if p and p.stream:
		p.play()
