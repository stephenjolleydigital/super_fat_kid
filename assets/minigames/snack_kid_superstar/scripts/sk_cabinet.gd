extends Node2D
## Host shell for a 256x224 cabinet. Emits results and does not quit the tree.
## The game renders into a fixed 256x224 SubViewport, shown 1:1 on its own CanvasLayer,
## so host cameras and parent Node2D transforms never rescale it.
signal host_result(result: Dictionary)
const SIZE := Vector2i(256, 224)
## Top-left of the cabinet screen in host viewport pixels. Use center_in() for a host frame.
@export var origin := Vector2i.ZERO:
	set(value):
		origin = value
		if screen: screen.position = Vector2(origin)
@export var screen_layer := 10
var game: Node2D
var result := {}
var rounds_cleared: Array = []
var plate: Node2D
var viewport: SubViewport
var screen: Sprite2D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(viewport)
	var scene_path: String = (str(get_script().resource_path).get_base_dir() + "/../scenes/Snack_Kid_Superstar.tscn").simplify_path()
	game = load(scene_path).instantiate()
	viewport.add_child(game)
	game.game_over.connect(_on_over)
	game.round_cleared.connect(_on_round)
	game.exit_requested.connect(_on_exit)
	var plate_layer := CanvasLayer.new()
	plate_layer.layer = 20
	viewport.add_child(plate_layer)
	plate = ResultPlate.new()
	plate.host = self
	plate_layer.add_child(plate)
	var layer := CanvasLayer.new()
	layer.layer = screen_layer
	add_child(layer)
	screen = Sprite2D.new()
	screen.texture = viewport.get_texture()
	screen.centered = false
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.position = Vector2(origin)
	layer.add_child(screen)

## Centers the 256x224 screen inside a host frame, e.g. Vector2i(480, 270) -> origin (112, 23).
func center_in(frame: Vector2i) -> void:
	origin = (frame - SIZE) / 2

func _unhandled_input(event: InputEvent) -> void:
	# The SubViewport is not inside a SubViewportContainer, so it only sees keys pushed here: once each.
	if not event is InputEventKey or viewport == null: return
	viewport.push_input(event)
	get_viewport().set_input_as_handled()

func shutdown() -> void:
	if game and is_instance_valid(game): game.shutdown()

func _on_over() -> void:
	result = _snapshot("win" if int(game.hp) > 0 else "dead")
	host_result.emit(result)

func _on_round(stage_number: int) -> void:
	rounds_cleared.append(stage_number)

func _on_exit() -> void:
	result = _snapshot("exit")
	host_result.emit(result)

func _snapshot(outcome: String) -> Dictionary:
	return {
		"outcome": outcome,
		"score": int(game.score),
		"hp": int(game.hp),
		"stage": int(game.level) + 1,
		"items": int(game.item_count),
		"kills": int(game.kills)
	}

class ResultPlate extends Node2D:
	var host: Node = null
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if host == null or host.result.is_empty(): return
		var font = preload("../sprites/sk_pixel_font.ttf")
		draw_rect(Rect2(16, 72, 224, 80), Color("181c30"))
		draw_rect(Rect2(16, 72, 224, 80), Color("f9be4c"), false)
		var outcome = str(host.result.get("outcome", "")).to_upper()
		draw_string(font, Vector2(28, 96), "CABINET " + outcome, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f9be4c"))
		draw_string(font, Vector2(28, 116), "TREE STILL RUNNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("fff7de"))
		draw_string(font, Vector2(28, 136), "SCORE " + str(host.result.get("score", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("fa77aa"))
