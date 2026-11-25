extends Area2D

const ArcadeScreen := preload("res://scripts/ui/arcade_screen.gd")
const GLASS := Rect2(16, 31, 43, 29)
@onready var sprite: Sprite2D = $Sprite
@onready var prompt: Label = $Prompt
@onready var insert_quarter_sfx: AudioStreamPlayer = $InsertQuarterSfx
var player: CharacterBody2D
var session_layer: CanvasLayer
var frame_time := 0.0


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	GameState.quarters_changed.connect(_update_price_prompt)
	_update_price_prompt()


func _update_price_prompt() -> void:
	prompt.text = "UP  ARCADE  25¢" if GameState.get_quarters() > 0 else "NEED 25¢"


func _on_enter(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		player = body as CharacterBody2D
		prompt.visible = session_layer == null


func _on_exit(body: Node2D) -> void:
	if body == player:
		player = null
		prompt.hide()


func _process(delta: float) -> void:
	frame_time += delta
	var duration := 0.12
	if sprite.frame >= 15:
		duration = 0.4 if sprite.frame % 2 == 1 else 0.18
	if frame_time >= duration:
		frame_time -= duration
		sprite.frame = (sprite.frame + 1) % sprite.hframes


func _unhandled_input(event: InputEvent) -> void:
	if session_layer != null or not is_instance_valid(player) or SceneTransition.busy:
		return
	if not event.is_action_pressed(&"ui_up") or not player.is_on_floor() or player.get("hp") == 0:
		return
	get_viewport().set_input_as_handled()
	if not GameState.try_spend_quarter():
		return
	insert_quarter_sfx.play()
	prompt.hide()
	var layer := CanvasLayer.new()
	session_layer = layer
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := ArcadeScreen.new()
	screen.controller_controls = event is InputEventJoypadButton or event is InputEventJoypadMotion
	screen.glass_on_screen = sprite.get_global_transform_with_canvas() * GLASS
	screen.glass_region = Rect2(GLASS.position + Vector2(sprite.frame * 76, 0), GLASS.size)
	screen.closed.connect(_on_screen_closed)
	layer.add_child(screen)


func _on_screen_closed() -> void:
	session_layer.queue_free()
	session_layer = null
	prompt.visible = is_instance_valid(player)
