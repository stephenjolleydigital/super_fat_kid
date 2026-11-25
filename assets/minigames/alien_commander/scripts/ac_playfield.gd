class_name ACPlayfield

const RECT := Rect2(0, 0, 256, 224)


static func contains_global_point(global_point: Vector2, playfield_global_origin: Vector2) -> bool:
	return _global_rect(playfield_global_origin).has_point(global_point)


static func encloses_global_rect(global_rect: Rect2, playfield_global_origin: Vector2) -> bool:
	return _global_rect(playfield_global_origin).encloses(global_rect)


static func _global_rect(playfield_global_origin: Vector2) -> Rect2:
	return Rect2(playfield_global_origin + RECT.position, RECT.size)
