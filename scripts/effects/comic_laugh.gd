extends Node2D
## A short, palette-only comic beat. Positions and motion stay on whole pixels.

const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const INK := Color8(43, 45, 66)
const RED := Color8(214, 40, 40)
const LIFETIME := 0.29
const FONT_SIZE := 8

var outward := 1.0
var _elapsed := 0.0
var _origin := Vector2.ZERO
var _font: FontFile


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	_origin = position.round()
	_font = PIXEL_FONT.duplicate() as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font.generate_mipmaps = false
	_font.oversampling = 1.0
	_update_pose()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	_update_pose()


func _update_pose() -> void:
	# Pop upward, settle, hold, then lift away. No fractional scale or alpha fade.
	var rise := 3.0
	var drift := 0.0
	if _elapsed >= 0.035:
		rise = -1.0
	if _elapsed >= 0.075:
		rise = 0.0
	if _elapsed >= 0.22:
		rise = -2.0
		drift = outward
	if _elapsed >= 0.255:
		rise = -4.0
		drift = outward * 2.0
	position = _origin + Vector2(drift, rise)
	queue_redraw()


func _draw() -> void:
	# Leave one clear pixel between the outlined H and A (and before !).
	# Draw each complete eight-neighbor outline before its flat red fill;
	# a colored offset shadow would overwrite pixels along the bottom border.
	var glyphs := ["H", "A", "!"]
	var advances := [0, 10, 18]
	for i in glyphs.size():
		var baseline := Vector2(-12 + advances[i], 4)
		for offset in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
			Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
			draw_string(_font, baseline + offset, glyphs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
		draw_string(_font, baseline, glyphs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)
