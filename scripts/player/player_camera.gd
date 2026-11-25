extends Camera2D
## Pixel-aligned follow. Player still owns offset (framing and existing impulses).

@export var improved_follow_enabled: bool = true:
	set(value):
		improved_follow_enabled = value
		if is_node_ready():
			reset_follow()
## Response rates in 1/seconds; higher values catch up faster.
@export_range(1.0, 60.0, 1.0) var horizontal_follow_speed: float = 12.0
## Airborne half-height in world pixels. Grounded framing always recenters.
@export_range(0.0, 32.0, 1.0) var vertical_dead_zone_pixels: float = 16.0
@export_range(1.0, 60.0, 1.0) var vertical_follow_speed: float = 14.0
## Grounded response rate; lower is gentler. Set to 14 for the previous settling.
@export_range(1.0, 60.0, 1.0) var landing_settle_speed: float = 9.0
## Additional upward framing in improved mode; 0 restores the previous height.
@export_range(0.0, 24.0, 1.0) var framing_height_pixels: float = 8.0

const TELEPORT_DISTANCE: float = 64.0
const MAX_VERTICAL_LAG: float = 40.0
var _target: Node2D
var _home_position: Vector2
var _follow_position: Vector2
var _last_target: Vector2


func _ready() -> void:
	_target = get_parent() as Node2D
	_home_position = position
	# One smoothing system, updated after the player's physics movement.
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	limit_smoothed = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = _target.process_physics_priority + 1
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	reset_follow()


## Call immediately after a scripted teleport, including moves under 64 pixels.
## Scene reloads / respawns reset automatically in _ready().
func reset_follow() -> void:
	_last_target = _target.to_global(_home_position)
	_follow_position = _clamp_to_limits(_last_target + Vector2(0, -framing_height_pixels))
	position = _home_position
	if improved_follow_enabled:
		global_position = _follow_position.round()
	reset_smoothing()
	force_update_scroll()


func _physics_process(delta: float) -> void:
	var target_position := _target.to_global(_home_position)
	if not improved_follow_enabled:
		position = _home_position
		_last_target = target_position
		force_update_scroll()
		return
	if target_position.distance_to(_last_target) > TELEPORT_DISTANCE:
		reset_follow()
		return
	_last_target = target_position
	var desired := _clamp_to_limits(target_position + Vector2(0, -framing_height_pixels))
	# Clamp the retained state too, so reversing at a limit has no hidden backlog.
	_follow_position = _clamp_to_limits(_follow_position)
	# Following a tiny recoil in rounded steps makes the player appear to twitch.
	var hold_recoil_follow: bool = _target.has_method("is_solid_kick_recoil_active") and _target.call("is_solid_kick_recoil_active")
	if not hold_recoil_follow:
		_follow_position.x = lerpf(_follow_position.x, desired.x,
			1.0 - exp(-horizontal_follow_speed * delta))
	var vertical_target := clampf(_follow_position.y,
		desired.y - vertical_dead_zone_pixels, desired.y + vertical_dead_zone_pixels)
	var vertical_speed := vertical_follow_speed
	# A dead zone must not preserve jump history after landing. Every platform
	# settles to the same framing, using the existing smooth follow response.
	if _target is CharacterBody2D and (_target as CharacterBody2D).is_on_floor():
		vertical_target = desired.y
		vertical_speed = landing_settle_speed
	_follow_position.y = lerpf(_follow_position.y, vertical_target,
		1.0 - exp(-vertical_speed * delta))
	# Uncapped falls must not outrun the view. No extra smoothing or look-ahead.
	_follow_position.y = clampf(_follow_position.y,
		desired.y - MAX_VERTICAL_LAG, desired.y + MAX_VERTICAL_LAG)
	global_position = _follow_position.round()
	force_update_scroll()


func _clamp_to_limits(point: Vector2) -> Vector2:
	# Camera2D still enforces its limits. Keep internal follow state within them.
	# offset intentionally stays outside limits, matching native Camera2D behavior.
	var half_view := get_viewport_rect().size * 0.5 / zoom
	var low := Vector2(limit_left, limit_top) + half_view
	var high := Vector2(limit_right, limit_bottom) - half_view
	return Vector2(clampf(point.x, low.x, high.x) if low.x <= high.x else point.x,
		clampf(point.y, low.y, high.y) if low.y <= high.y else point.y)
