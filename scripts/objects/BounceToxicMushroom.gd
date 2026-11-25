extends "res://scripts/objects/bounce_mushroom.gd"

const GAS_HITBOX_ENABLE_FRAME: int = 0
const GAS_HITBOX_DISABLE_FRAME: int = 7

@onready var _gas_damage: Area2D = $GasDamage
@onready var _gas_damage_shape: CollisionShape2D = $GasDamage/CollisionShape2D
@onready var _sfx_release: AudioStreamPlayer2D = $SFX_Release


func _ready() -> void:
	super()
	_set_gas_hitbox_active(false)
	_sprite.frame_changed.connect(_on_toxic_sprite_frame_changed)


func _bounce_player(player: CharacterBody2D) -> void:
	# A new bounce always restarts the attack cycle safely.
	_set_gas_hitbox_active(false)
	super(player)


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"bounce":
			# Preserve the normal mushroom's collision reset before attacking.
			super()
			_sprite.play(&"windup")
		&"windup":
			_sprite.play(&"gas_release")
			_update_gas_hitbox_for_current_frame()
			_play_toxic_sfx(_sfx_release)
		&"gas_release":
			_set_gas_hitbox_active(false)
			_sprite.play(&"cooldown")
		&"cooldown":
			_sprite.play(&"idle")


func _on_toxic_sprite_frame_changed() -> void:
	if _sprite.animation == &"gas_release":
		_update_gas_hitbox_for_current_frame()


func _update_gas_hitbox_for_current_frame() -> void:
	var active := (
		_sprite.frame >= GAS_HITBOX_ENABLE_FRAME
		and _sprite.frame < GAS_HITBOX_DISABLE_FRAME
	)
	_set_gas_hitbox_active(active)


func _play_toxic_sfx(player: AudioStreamPlayer2D) -> void:
	if is_instance_valid(player) and player.stream:
		player.play()


func _set_gas_hitbox_active(active: bool) -> void:
	if not is_instance_valid(_gas_damage):
		return

	if active:
		if not _gas_damage.is_in_group(&"enemy_attack"):
			_gas_damage.add_to_group(&"enemy_attack")
	else:
		if _gas_damage.is_in_group(&"enemy_attack"):
			_gas_damage.remove_from_group(&"enemy_attack")

	_gas_damage.set_deferred(&"monitoring", active)
	_gas_damage.set_deferred(&"monitorable", active)
	if is_instance_valid(_gas_damage_shape):
		_gas_damage_shape.set_deferred(&"disabled", not active)
