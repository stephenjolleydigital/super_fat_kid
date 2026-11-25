@tool
extends StaticBody2D
## Origin is the left end of the standing surface. Tiles are never scaled.
## PNG cells: 48x80, surface at (16, 8); idle 0, crumble 1-9, reform 10-19.

enum State { IDLE, COUNTDOWN, CRUMBLE, ABSENT, REFORM }

signal state_changed(new_state: State)

const TILE_SIZE := 16
const CELL_SIZE := Vector2(48, 80)
const SHEETS: Array[Texture2D] = [
	preload("res://assets/sprites/objects/crumbling_platform/crumbling_platform_left.png"),
	preload("res://assets/sprites/objects/crumbling_platform/crumbling_platform_center_a.png"),
	preload("res://assets/sprites/objects/crumbling_platform/crumbling_platform_center_b.png"),
	preload("res://assets/sprites/objects/crumbling_platform/crumbling_platform_right.png"),
]

## Includes the two end caps; center A and B alternate between them.
@export_range(2, 128, 1) var width_in_tiles: int = 4:
	set(value):
		width_in_tiles = clampi(value, 2, 128)
		if is_node_ready():
			_resize_collision()
			queue_redraw()
## Seconds of solid footing after the first landing, even if the player leaves.
@export_range(0.0, 5.0, 0.05, "suffix:s") var crumble_delay: float = 0.45
## Base multiplier for both animations. 1 = the Aseprite timing (10 frames/second).
@export_range(0.1, 4.0, 0.1) var animation_speed: float = 1.0
## Extra speed for rebuilding; 1.5 reforms in about 0.67 seconds at base speed.
@export_range(0.1, 4.0, 0.1) var reform_speed_multiplier: float = 1.5
## Reform fades from this opacity to fully opaque as the pieces rebuild.
@export_range(0.0, 1.0, 0.05) var reform_start_opacity: float = 0.65
## Time fully absent, measured after the crumble animation finishes.
@export_range(0.0, 30.0, 0.1, "suffix:s") var respawn_delay: float = 1.5

var state: State = State.IDLE
var _elapsed: float = 0.0
var _frame: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Inspect slide contacts after the player has completed move_and_slide().
	process_physics_priority = 100
	_resize_collision()
	queue_redraw()


func _resize_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_in_tiles * TILE_SIZE, TILE_SIZE)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = shape.size * 0.5
	$SFX_Crumble.position = shape.size * 0.5
	$SFX_Reform.position = shape.size * 0.5


func _draw() -> void:
	var tint := Color.WHITE
	if state == State.REFORM:
		var progress := clampf(_elapsed / _get_reform_duration(), 0.0, 1.0)
		tint.a = lerpf(reform_start_opacity, 1.0, progress)
	for tile in range(width_in_tiles):
		var piece := 1 + (tile - 1) % 2
		if tile == 0:
			piece = 0
		elif tile == width_in_tiles - 1:
			piece = 3
		# Draw the whole padded cell: debris can cross tile boundaries freely.
		draw_texture_rect_region(SHEETS[piece],
			Rect2(Vector2(tile * TILE_SIZE - 16, -8), CELL_SIZE),
			Rect2(Vector2(_frame * CELL_SIZE.x, 0), CELL_SIZE), tint)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if state == State.IDLE:
		for node in get_tree().get_nodes_in_group("player"):
			if not node is CharacterBody2D:
				continue
			var body := node as CharacterBody2D
			if not body.is_on_floor():
				continue
			for index in range(body.get_slide_collision_count()):
				var contact := body.get_slide_collision(index)
				if contact.get_collider() == self and contact.get_normal().dot(Vector2.UP) > 0.7:
					_set_state(State.COUNTDOWN)
					return
		return
	_elapsed += delta
	match state:
		State.COUNTDOWN:
			if _elapsed >= maxf(crumble_delay, 0.0):
				_set_state(State.CRUMBLE)
		State.CRUMBLE:
			if _elapsed >= 0.9 / maxf(animation_speed, 0.1):
				_set_state(State.ABSENT)
		State.ABSENT:
			if _elapsed >= maxf(respawn_delay, 0.0):
				_set_state(State.REFORM)
		State.REFORM:
			if _elapsed >= _get_reform_duration():
				_set_state(State.IDLE)
	_update_frame()


func _set_state(next_state: State) -> void:
	state = next_state
	_elapsed = 0.0
	if state == State.CRUMBLE:
		$CollisionShape2D.set_deferred("disabled", true)
		$SFX_Crumble.play()
	elif state == State.REFORM:
		$SFX_Reform.play()
	elif state == State.IDLE:
		$CollisionShape2D.set_deferred("disabled", false)
	_update_frame()
	state_changed.emit(state)


func _update_frame() -> void:
	var next_frame := 0
	match state:
		State.CRUMBLE:
			next_frame = 1 + mini(int(_elapsed * 10.0 * maxf(animation_speed, 0.1)), 8)
		State.ABSENT:
			next_frame = 9
		State.REFORM:
			next_frame = 10 + mini(int(_elapsed / _get_reform_duration() * 10.0), 9)
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()
	elif state == State.REFORM:
		# Opacity advances smoothly between the pixel animation's frame changes.
		queue_redraw()


func _get_reform_duration() -> float:
	return 1.0 / (maxf(animation_speed, 0.1) * maxf(reform_speed_multiplier, 0.1))
