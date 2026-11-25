extends Sprite2D

const SHEETS := [
	{ "texture": preload("res://assets/sprites/ui/title/fatkid_title_stars_01.png"), "hframes": 34 },
	{ "texture": preload("res://assets/sprites/ui/title/fatkid_title_stars_02.png"), "hframes": 34 },
	{ "texture": preload("res://assets/sprites/ui/title/fatkid_title_stars_03.png"), "hframes": 34 },
	{ "texture": preload("res://assets/sprites/ui/title/fatkid_title_stars_04.png"), "hframes": 33 },
]
const FPS := 12.0

var _sheet_index: int = 0
var _time_accum: float = 0.0


func _ready() -> void:
	_apply_sheet(0)
	frame = 0


func _process(delta: float) -> void:
	_time_accum += delta
	var frame_duration := 1.0 / FPS
	while _time_accum >= frame_duration:
		_time_accum -= frame_duration
		_advance_frame()


func _advance_frame() -> void:
	var sheet: Dictionary = SHEETS[_sheet_index]
	var frame_count: int = sheet["hframes"]
	if frame + 1 < frame_count:
		frame += 1
		return
	_sheet_index = (_sheet_index + 1) % SHEETS.size()
	_apply_sheet(_sheet_index)
	frame = 0


func _apply_sheet(sheet_index: int) -> void:
	var sheet: Dictionary = SHEETS[sheet_index]
	texture = sheet["texture"]
	hframes = sheet["hframes"]
