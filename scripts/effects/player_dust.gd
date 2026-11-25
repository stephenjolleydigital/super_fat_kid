extends Node2D
## World-anchored, four-pose pixel dust. Only explicit calls emit a burst.
## Geometry is authored in native pixels; never scale or rotate this component.

const FRAME_COUNT := 4
const MAX_BURSTS := 2
const COLOR_SHADOW := Color("#7B6D5E")
const COLOR_BODY := Color("#B7A891")
const COLOR_LIGHT := Color("#D9CFC3")
const FRAME_SPREAD := [0, 1, 2, 3]
const FRAME_LIFT := [0, 1, 3, 2]

# Each particle is (initial x, initial y, horizontal step), in whole pixels.
const TAKEOFF_PARTICLES := [Vector3i(-10, -2, -1), Vector3i(7, -2, 1), Vector3i(-1, -4, 0)]
const LAND_PARTICLES := [Vector3i(-14, -3, -1), Vector3i(-7, -4, -1), Vector3i(4, -4, 1), Vector3i(10, -3, 1)]
const STRONG_LAND_PARTICLES := [Vector3i(-15, -3, -2), Vector3i(-8, -5, -1), Vector3i(-1, -6, 0), Vector3i(5, -5, 1), Vector3i(11, -3, 2)]
const TAKEOFF_SIZE := Vector2(3, 2)
const LAND_SIZE := Vector2(4, 3)
const LAST_POSE_SIZE := Vector2(2, 2)

@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_bursts.clear()
			set_physics_process(false)
			queue_redraw()

## Seconds per discrete pose (four poses total; default lifetime 0.20 seconds).
@export_range(0.01, 0.15, 0.01) var frame_duration: float = 0.05

class Burst:
	var origin: Vector2
	var particles: Array
	var age: float = 0.0
	var frame: int = 0

var _bursts: Array[Burst] = []


func _ready() -> void:
	# Remain a child for ownership/cleanup, but do not follow the player's motion.
	top_level = true
	global_transform = Transform2D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	# Match the existing afterimage convention: one layer behind the player.
	var player := get_parent() as Node2D
	if player != null:
		z_index = player.z_index - 1
	set_physics_process(false)


func emit_takeoff(world_position: Vector2) -> void:
	_emit(world_position, TAKEOFF_PARTICLES)


func emit_landing(world_position: Vector2, strong: bool = false) -> void:
	_emit(world_position, STRONG_LAND_PARTICLES if strong else LAND_PARTICLES)


func _emit(world_position: Vector2, particles: Array) -> void:
	if not enabled or not is_inside_tree() or is_queued_for_deletion():
		return
	if _bursts.size() >= MAX_BURSTS:
		_bursts.pop_front()
	var burst := Burst.new()
	burst.origin = world_position.round()
	burst.particles = particles
	_bursts.append(burst)
	set_physics_process(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var changed := false
	for i in range(_bursts.size() - 1, -1, -1):
		var burst := _bursts[i]
		burst.age += delta
		var next_frame := int(floor((burst.age + 0.000001) / maxf(frame_duration, 0.01)))
		if next_frame >= FRAME_COUNT:
			_bursts.remove_at(i)
			changed = true
		elif next_frame != burst.frame:
			burst.frame = next_frame
			changed = true
	if changed:
		queue_redraw()
	if _bursts.is_empty():
		set_physics_process(false)


func _draw() -> void:
	for burst in _bursts:
		for i in range(burst.particles.size()):
			# A few pieces disappear in the last pose instead of fading.
			if burst.frame == FRAME_COUNT - 1 and i % 2 == 1:
				continue
			var particle: Vector3i = burst.particles[i]
			var offset := Vector2(
				particle.x + particle.z * FRAME_SPREAD[burst.frame],
				particle.y - FRAME_LIFT[burst.frame]
			)
			var position_px := burst.origin + offset
			var size_px := TAKEOFF_SIZE if burst.particles.size() == 3 else LAND_SIZE
			if burst.frame == FRAME_COUNT - 1:
				size_px = LAST_POSE_SIZE
			draw_rect(Rect2(position_px, size_px), COLOR_SHADOW, true)
			draw_rect(Rect2(position_px, size_px - Vector2(0, 1)), COLOR_BODY, true)
			if burst.frame < FRAME_COUNT - 1:
				draw_rect(Rect2(position_px + Vector2(1, 0), Vector2(size_px.x - 2, 1)), COLOR_LIGHT, true)
