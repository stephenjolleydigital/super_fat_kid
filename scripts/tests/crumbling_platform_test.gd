extends Node2D
## Dedicated F6 arena. Uses the real player and does not modify progression.

const PLAYER := preload("res://scenes/player/player.tscn")
var player: CharacterBody2D
var platforms: Array[StaticBody2D] = []
var status: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#2B2D42"))
	for child in get_children():
		if child is StaticBody2D:
			platforms.append(child)
	_solid(Vector2(240, 256), Vector2(480, 16))
	_solid(Vector2(-8, 135), Vector2(16, 270))
	_solid(Vector2(488, 135), Vector2(16, 270))
	# The ordinary jump reaches these steps and then the test platforms.
	_solid(Vector2(24, 218), Vector2(40, 8))
	_solid(Vector2(24, 190), Vector2(32, 8))
	player = PLAYER.instantiate()
	player.position = Vector2(144, 100)
	add_child(player)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(240, 135)
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	status = Label.new()
	status.position = Vector2(8, 6)
	status.add_theme_font_size_override("font_size", 10)
	hud.add_child(status)


func _process(_delta: float) -> void:
	var states := PackedStringArray()
	for platform in platforms:
		states.append("%d: %s" % [platform.width_in_tiles, platform.State.keys()[platform.state]])
	status.text = "CRUMBLING PLATFORMS | normal movement / jump\n1-5: land on a width | R: restart\n" + "   ".join(states)
	if player.position.y > 310:
		_land_on(2)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		_land_on(event.physical_keycode - KEY_1)


func _land_on(index: int) -> void:
	var platform := platforms[index]
	player.reset_for_external_launch()
	player.global_position = platform.global_position + Vector2(platform.width_in_tiles * 8, -64)
	player.velocity = Vector2.ZERO
	player.state = player.State.AIR


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
	graphic.color = Color("#4A4A4A")
	body.add_child(graphic)
	add_child(body)
