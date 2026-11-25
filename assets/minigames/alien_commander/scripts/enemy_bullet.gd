extends Area2D

const SPEED := 180.0
const HALF_SIZE := Vector2(4, 4)

var _hit: bool = false
var _playfield_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_playfield_origin = _find_playfield_origin()


func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return
	if area.has_method(&"take_damage"):
		_hit = true
		area.call(&"take_damage", 1)
	queue_free()


func _process(delta: float) -> void:
	global_position.y -= SPEED * delta
	var bullet_rect := Rect2(global_position - HALF_SIZE, HALF_SIZE * 2.0)
	if not ACPlayfield.encloses_global_rect(bullet_rect, _playfield_origin):
		queue_free()


func _find_playfield_origin() -> Vector2:
	var node: Node = self
	while node:
		if node.has_method(&"get_playfield_global_origin"):
			return node.call(&"get_playfield_global_origin")
		node = node.get_parent()
	return Vector2.ZERO
