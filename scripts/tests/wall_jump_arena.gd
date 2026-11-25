extends Node2D
## Isolated, disposable playtest layout. No production placement or level links.

const PLAYER = preload("res://scenes/player/player.tscn")
const GUM = preload("res://scenes/pickups/Pickup_Bubblegum.tscn")
const TACO = preload("res://scenes/pickups/Pickup_Taco.tscn")
const MUSHROOM = preload("res://scenes/objects/BounceMushroom.tscn")
const BLASTER = preload("res://scenes/pickups/Pickup_Blaster.tscn")
const MEDAL = preload("res://scenes/pickups/Pickup_TrackMedal.tscn")
const WALL_COLOR = Color("#4A4A4A")
var player: CharacterBody2D
var status: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#2B2D42"))
	_solid(Vector2(320, 240), Vector2(1024, 32))
	# A segmented wall tests seams; the opposite wall is one collider.
	for y in range(-320, 224, 16):
		_solid(Vector2(48, y + 8), Vector2(32, 16))
	_solid(Vector2(192, -48), Vector2(32, 544))
	# Climb out of the shaft to reach a slope, corner ledge and mushroom.
	_solid(Vector2(280, 80), Vector2(80, 16))
	var slope := StaticBody2D.new()
	var collision := CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([Vector2(320, 224), Vector2(400, 144), Vector2(400, 224)])
	slope.add_child(collision)
	add_child(slope)
	var graphic := Polygon2D.new()
	graphic.polygon = collision.polygon
	graphic.color = WALL_COLOR
	slope.add_child(graphic)
	_spawn(GUM, Vector2(151, 203))
	_spawn(TACO, Vector2(82, 203))
	_spawn(BLASTER, Vector2(264, 56))
	_spawn(MEDAL, Vector2(300, 56))
	_spawn(MUSHROOM, Vector2(448, 208))
	player = PLAYER.instantiate()
	player.position = Vector2(120, 196)
	add_child(player)
	var hud := CanvasLayer.new()
	add_child(hud)
	status = Label.new()
	status.position = Vector2(8, 8)
	status.add_theme_font_size_override("font_size", 12)
	hud.add_child(status)


func _process(_delta: float) -> void:
	status.text = "WALL JUMP PLAYTEST\nGum: %s    Taco: %s\nMove / Jump: normal controls\nR: restart (keep upgrades)\nF1: reset test upgrades\nF2: move to outside test area" % ["collected" if player.has_wall_jump else "right pickup", "collected" if player.has_double_jump else "left pickup"]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_F1:
			for upgrade_id in ["wall_jump_upgrade", "double_jump_upgrade", "blaster_upgrade", "run_upgrade"]:
				GameState.collected_upgrade_ids.erase(upgrade_id)
			get_tree().reload_current_scene()
		KEY_F2:
			player.reset_for_external_launch()
			player.global_position = Vector2(280, 40)
			player.velocity = Vector2.ZERO
			player.state = player.State.AIR


func _spawn(scene: PackedScene, at: Vector2) -> void:
	var node := scene.instantiate() as Node2D
	node.position = at
	add_child(node)


func _solid(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var graphic := Polygon2D.new()
	var half := size * 0.5
	graphic.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	graphic.color = WALL_COLOR
	body.add_child(graphic)
	add_child(body)
