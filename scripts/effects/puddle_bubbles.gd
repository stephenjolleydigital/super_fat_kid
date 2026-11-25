extends Node2D
## Cosmetic pixel bubbles. Position this node on the puddle's surface;
## width and colors are set by each scene to match its existing artwork.

@export var enabled: bool = true:
	set(value):
		enabled = value
		set_process(enabled)
		queue_redraw()
@export_range(4.0, 16.0, 1.0) var poses_per_second: float = 8.0
@export_range(4.0, 64.0, 1.0) var surface_width: float = 36.0
@export_range(1, 3, 1) var bubble_count: int = 2
@export var body_color: Color = Color("#339668")
@export var highlight_color: Color = Color("#81C784")

var _pose: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	# Different puddles should not bubble in unison.
	_pose = randi_range(0, 15)
	set_process(enabled)


func _process(delta: float) -> void:
	_elapsed += delta
	var step := 1.0 / maxf(poses_per_second, 1.0)
	if _elapsed >= step:
		_pose = (_pose + int(_elapsed / step)) % 16
		_elapsed = fmod(_elapsed, step)
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for i in bubble_count:
		var pose := (_pose + i * 7) % 16
		# Long quiet gaps keep the effect subtle; five discrete poses form a pop.
		if pose > 4:
			continue
		var x := roundf(surface_width * (float(i + 1) / float(bubble_count + 1) - 0.5))
		if pose == 0:
			draw_rect(Rect2(Vector2(x, -1), Vector2(1, 1)), highlight_color)
		elif pose < 4:
			var top := Vector2(x - 1, -float(pose))
			draw_rect(Rect2(top, Vector2(3, 2)), body_color)
			draw_rect(Rect2(top, Vector2(2, 1)), highlight_color)
		else:
			draw_rect(Rect2(Vector2(x - 2, -3), Vector2(1, 1)), highlight_color)
			draw_rect(Rect2(Vector2(x + 2, -2), Vector2(1, 1)), body_color)
