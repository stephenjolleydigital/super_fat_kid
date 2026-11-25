extends Node
## Attach to an enemy or enemy projectile. This supplies knockback only;
## it does not enable damage or change collision, health, or attack timing.

## Paths relative to the enemy root. Use "." for an Area2D projectile root.
@export var damage_areas: Array[NodePath] = []
## Optional origin relative to the enemy root; empty uses the root itself.
@export var origin_path: NodePath
@export_range(0.0, 600.0, 1.0) var sideways_speed: float = CombatTuning.ENEMY_HIT_KNOCKBACK_SPEED
@export_range(0.0, 400.0, 1.0) var upward_speed: float = CombatTuning.ENEMY_HIT_KNOCKBACK_UP_SPEED

var _origin: Node2D


func _ready() -> void:
	var enemy := get_parent()
	_origin = enemy as Node2D if origin_path.is_empty() else enemy.get_node_or_null(origin_path) as Node2D
	if _origin == null:
		push_error("EnemyKnockback needs a Node2D origin: " + str(get_path()))
		return
	for path in damage_areas:
		var area := enemy.get_node_or_null(path) as Area2D
		if area == null:
			push_error("EnemyKnockback damage area missing: " + str(path))
			continue
		area.set_meta(&"hurt_knockback_provider", get_knockback)


func get_knockback(player_position: Vector2, fallback_direction: float) -> Vector2:
	return CombatTuning.enemy_hit_knockback(
		player_position, _origin.global_position, fallback_direction, sideways_speed, upward_speed
	)
