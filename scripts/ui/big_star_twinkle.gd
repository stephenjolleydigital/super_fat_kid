extends Sprite2D

enum Size { SMALL, MEDIUM, LARGE }
enum StarColor { BLUE, RED, ORANGE }

const TEXTURES := {
	StarColor.BLUE: {
		Size.SMALL: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_blue_small.png"),
		Size.MEDIUM: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_blue_medium.png"),
		Size.LARGE: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_blue_large.png"),
	},
	StarColor.RED: {
		Size.SMALL: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_red_small.png"),
		Size.MEDIUM: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_red_medium.png"),
		Size.LARGE: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_red_large.png"),
	},
	StarColor.ORANGE: {
		Size.SMALL: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_orange_small.png"),
		Size.MEDIUM: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_orange_medium.png"),
		Size.LARGE: preload("res://assets/sprites/ui/title/stars/fatkid_title_star_orange_large.png"),
	},
}
const HFRAMES := 4
const TWINKLE_FPS := 10.0
const IDLE_WAIT := {
	Size.SMALL: Vector2(6.0, 16.0),
	Size.MEDIUM: Vector2(12.0, 28.0),
	Size.LARGE: Vector2(20.0, 48.0),
}

enum State { IDLE, TWINKLE }

@export var star_size: Size = Size.SMALL
@export var star_color: StarColor = StarColor.BLUE

var _state: State = State.IDLE
var _wait_remaining: float = 0.0
var _time_accum: float = 0.0


func _ready() -> void:
	texture = TEXTURES[star_color][star_size]
	hframes = HFRAMES
	frame = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wait_remaining = _random_idle_wait()


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			_wait_remaining -= delta
			if _wait_remaining <= 0.0:
				_start_twinkle()
		State.TWINKLE:
			_time_accum += delta
			var frame_duration := 1.0 / TWINKLE_FPS
			while _time_accum >= frame_duration:
				_time_accum -= frame_duration
				if not _advance_twinkle_frame():
					return


func _start_twinkle() -> void:
	_state = State.TWINKLE
	_time_accum = 0.0
	frame = 1


func _advance_twinkle_frame() -> bool:
	if frame < 3:
		frame += 1
		return true
	_state = State.IDLE
	frame = 0
	_wait_remaining = _random_idle_wait()
	return false


func _random_idle_wait() -> float:
	var wait_range: Vector2 = IDLE_WAIT[star_size]
	return randf_range(wait_range.x, wait_range.y)
