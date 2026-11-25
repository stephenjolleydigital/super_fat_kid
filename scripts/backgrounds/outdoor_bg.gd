extends CanvasLayer

const LAYER_SCROLL_SPEEDS := {
	"Clouds": 0.08,
	"Hills": 0.12,
}

const MIRROR_WIDTHS := {
	"Clouds": 640.0,
	"Hills": 640.0,
}

## Slow rightward world-space drift so clouds keep moving when the camera is still.
const CLOUD_IDLE_DRIFT_PX_PER_SEC := 0.5

var _cloud_idle_offset_x: float = 0.0


func _ready() -> void:
	# Wait for all level children, including the player's camera framing.
	# This also covers the boss arena, which has no shared level script.
	get_parent().ready.connect(_initialize_parallax, CONNECT_ONE_SHOT)


func _initialize_parallax() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.force_update_scroll()
	sync_to_camera()


func _process(delta: float) -> void:
	if not get_viewport().get_camera_2d():
		return
	_cloud_idle_offset_x = fmod(
		_cloud_idle_offset_x + CLOUD_IDLE_DRIFT_PX_PER_SEC * delta,
		MIRROR_WIDTHS["Clouds"]
	)
	sync_to_camera()


## Also called before the level's paused entrance reveal. Does not advance drift.
func sync_to_camera() -> void:
	offset.y = 0
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var cam_x := cam.get_screen_center_position().x
	for layer_name in LAYER_SCROLL_SPEEDS:
		var node := get_node_or_null(layer_name) as Node2D
		if not node:
			continue
		var speed: float = LAYER_SCROLL_SPEEDS[layer_name]
		var mirror_w: float = MIRROR_WIDTHS[layer_name]
		var parallax_x: float = -fposmod(cam_x * speed, mirror_w)
		if layer_name == "Clouds":
			# Drift opposite camera parallax so standing still still scrolls clouds.
			parallax_x = -fposmod(cam_x * speed + _cloud_idle_offset_x, mirror_w)
		node.position.x = parallax_x
		node.position.y = 0
