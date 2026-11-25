extends TileMapLayer

const SPIKE_SOURCE := 1

func _ready() -> void:
	# Reach beyond the solid teeth so the player's inset hurtbox registers contact.
	var sensor_shape := RectangleShape2D.new()
	sensor_shape.size = Vector2(20, 13)
	for cell in get_used_cells_by_id(SPIKE_SOURCE):
		var outward := Vector2.UP if get_cell_atlas_coords(cell).x == 0 else Vector2.DOWN
		var flags := get_cell_alternative_tile(cell)
		if flags & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
			outward = Vector2(outward.y, outward.x)
		if flags & TileSetAtlasSource.TRANSFORM_FLIP_H:
			outward.x *= -1
		if flags & TileSetAtlasSource.TRANSFORM_FLIP_V:
			outward.y *= -1

		var damage := Area2D.new()
		damage.monitoring = false
		damage.collision_mask = 0
		damage.position = map_to_local(cell) + outward * 1.5
		damage.rotation = outward.angle() - Vector2.UP.angle()
		damage.add_to_group(&"enemy_attack")
		damage.set_meta(&"hurt_knockback", outward * 180.0)
		var collision := CollisionShape2D.new()
		collision.shape = sensor_shape
		damage.add_child(collision)
		add_child(damage)
