extends Area2D

signal destroyed

const COLLISION_LAYER := 1
const COLLISION_MASK := 8

# Dead aliens are deactivated rather than freed so the wave-clear refill can
# revive the same node, keeping its sprite type and signal connections intact.
var _alive := true


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = COLLISION_MASK


func is_alive() -> bool:
	return _alive


func take_damage(_amount: int) -> void:
	if not _alive:
		return
	_alive = false
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_alien_death()
	visible = false
	# Deferred: take_damage runs from an area-overlap callback.
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	destroyed.emit()


func revive() -> void:
	_alive = true
	visible = true
	monitoring = true
	monitorable = true
	collision_layer = COLLISION_LAYER
	collision_mask = COLLISION_MASK
