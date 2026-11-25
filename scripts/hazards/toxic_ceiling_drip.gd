extends Node2D

## Ceiling-mounted toxic drip. Cycles idle → warning → fall → splat → regrow.
## Damages the player only while falling, via enemy_attack ↔ player Hurtbox.
## Damage is fixed at 1 by the Player hurt interface (no damage_amount export).

enum Phase {
	IDLE,
	WARNING,
	FALLING,
	SPLAT,
	RESET_WAIT,
	REGROW,
	STOPPED,
}

@export var idle_delay: float = 1.5
## Extra wait before the first warning; later cycles use only idle_delay.
@export_range(0.0, 10.0, 0.05, "or_greater") var initial_delay: float = 0.0
@export var warning_fps: float = 9.0
@export var fall_speed: float = 120.0
@export var fall_fps: float = 11.0
@export var splat_fps: float = 12.0
@export var regrow_fps: float = 9.0
@export var reset_delay: float = 0.15
@export var auto_repeat: bool = true

@onready var _drop: Area2D = $Drop
@onready var _sprite: AnimatedSprite2D = $Drop/AnimatedSprite2D
@onready var _shape: CollisionShape2D = $Drop/CollisionShape2D
@onready var _fall_sfx: AudioStreamPlayer2D = $FallSFX
@onready var _splat_sfx: AudioStreamPlayer2D = $SplatSFX

var _phase: Phase = Phase.IDLE
var _hit_landed: bool = false
var _timer: float = 0.0


func _ready() -> void:
	_apply_anim_speeds()
	_drop.area_entered.connect(_on_drop_area_entered)
	_drop.body_entered.connect(_on_drop_body_entered)
	_sprite.animation_finished.connect(_on_animation_finished)
	_set_hitbox_active(false)
	_drop.position = Vector2.ZERO
	_begin_idle()
	_timer += initial_delay


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_begin_warning()
		Phase.FALLING:
			if _hit_landed:
				return
			_drop.position.y += fall_speed * delta
		Phase.RESET_WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_begin_regrow()
		_:
			pass


func _apply_anim_speeds() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		return
	frames.set_animation_speed(&"warning", warning_fps)
	frames.set_animation_speed(&"fall", fall_fps)
	frames.set_animation_speed(&"splat", splat_fps)
	frames.set_animation_speed(&"regrow", regrow_fps)


func _begin_idle() -> void:
	_phase = Phase.IDLE
	_hit_landed = false
	_drop.position = Vector2.ZERO
	_set_hitbox_active(false)
	_sprite.play(&"idle")
	_timer = idle_delay


func _begin_warning() -> void:
	_phase = Phase.WARNING
	_set_hitbox_active(false)
	_sprite.play(&"warning")


func _begin_falling() -> void:
	_phase = Phase.FALLING
	_hit_landed = false
	_set_hitbox_active(true)
	_sprite.play(&"fall")
	_play_sfx(_fall_sfx)


func _begin_splat() -> void:
	if _hit_landed:
		return
	_hit_landed = true
	_phase = Phase.SPLAT
	# Disable collision immediately; defer group removal so the same-frame
	# Hurtbox area_entered still sees enemy_attack if our signal ran first.
	_drop.set_deferred(&"monitoring", false)
	_drop.set_deferred(&"monitorable", false)
	_shape.set_deferred(&"disabled", true)
	call_deferred(&"_remove_from_enemy_attack")
	_sprite.play(&"splat")
	_play_sfx(_splat_sfx)


func _begin_reset_wait() -> void:
	_phase = Phase.RESET_WAIT
	# The splat is finished; keep the reset pause without holding its last frame.
	_sprite.hide()
	_timer = reset_delay


func _begin_regrow() -> void:
	_phase = Phase.REGROW
	_drop.position = Vector2.ZERO
	_set_hitbox_active(false)
	_sprite.show()
	_sprite.play(&"regrow")


func _on_animation_finished() -> void:
	match _phase:
		Phase.WARNING:
			if _sprite.animation == &"warning":
				_begin_falling()
		Phase.SPLAT:
			if _sprite.animation == &"splat":
				_begin_reset_wait()
		Phase.REGROW:
			if _sprite.animation == &"regrow":
				if auto_repeat:
					_begin_idle()
				else:
					_phase = Phase.STOPPED
					_set_hitbox_active(false)
					_sprite.play(&"idle")
		_:
			pass


func _on_drop_area_entered(area: Area2D) -> void:
	if _phase != Phase.FALLING or _hit_landed:
		return
	if not area.is_in_group(&"player_hurtbox"):
		return
	# Player applies 1 damage via enemy_attack on Hurtbox enter; we only splat.
	_begin_splat()


func _on_drop_body_entered(body: Node2D) -> void:
	if _phase != Phase.FALLING or _hit_landed:
		return
	# Damage routes through player_hurtbox only (matches bird_poop / magicrain).
	if body.is_in_group(&"player"):
		return
	_begin_splat()


func _set_hitbox_active(active: bool) -> void:
	if not is_instance_valid(_drop) or not is_instance_valid(_shape):
		return
	if active:
		if not _drop.is_in_group(&"enemy_attack"):
			_drop.add_to_group(&"enemy_attack")
	else:
		_remove_from_enemy_attack()
	_drop.set_deferred(&"monitoring", active)
	_drop.set_deferred(&"monitorable", active)
	_shape.set_deferred(&"disabled", not active)


func _remove_from_enemy_attack() -> void:
	if is_instance_valid(_drop) and _drop.is_in_group(&"enemy_attack"):
		_drop.remove_from_group(&"enemy_attack")


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player and player.stream:
		player.play()
