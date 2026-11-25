extends Control
## One cached text surface breaks into small tiles and assembles at the real HUD.
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const INK := Color8(43, 45, 66)
const STAMINA_GREEN := Color8(156, 203, 94)
const CREAM := Color8(253, 243, 207)
const TITLE_FONT_SIZE := 18
const INTRO_FONT_SIZE := 15
const GIFT_HOLD := 3.0
const UNLOCK_HOLD := 2.4
const TEXT_START := 0.12
const TITLE_START := 1.15
const MORPH_START := 2.35
const FIRST_ARRIVAL := 0.62
const LAST_ARRIVAL := 0.94
const TILE_SIZE := Vector2(4, 2)
var gas_mode := false
var elapsed := 0.0
var _text_size := Vector2i.ZERO
var meter_rect := Rect2(9, 27, 50, 4)
var _font: FontFile
var _surface: SubViewport

# Render once, using the same font, rasterization, and pixel outline as the first phrase.
class TitleInk extends Control:
	var pixel_font: FontFile
	var title: String
	var font_size := 18
	var tint := Color8(156,203,94)
	func _draw() -> void:
		var baseline := Vector2(2, font_size + 2)
		for offset in [Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1), Vector2(-1,0),
			Vector2(1,0), Vector2(-1,1), Vector2(0,1), Vector2(1,1)]:
			draw_string(pixel_font, baseline + offset, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color8(43,45,66))
		draw_string(pixel_font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = FONT.duplicate() as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font.oversampling = 1.0
	_font.generate_mipmaps = false
	var title := "STAMINA TRANSMUTING..." if gas_mode else "THE CURSE OF STAMINA"
	var width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE).x
	_text_size = Vector2i(ceili((width + 4) / 4.0) * 4, TITLE_FONT_SIZE + 6)
	_surface = SubViewport.new()
	_surface.size = _text_size
	_surface.transparent_bg = true
	_surface.disable_3d = true
	_surface.render_target_update_mode = SubViewport.UPDATE_ONCE
	_surface.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_surface)
	var ink := TitleInk.new()
	ink.pixel_font = _font
	ink.title = title
	ink.font_size = TITLE_FONT_SIZE
	_surface.add_child(ink)

# Both sequences get the longer reading holds; fragment flight stays unchanged.
func title_start() -> float:
	return TEXT_START + (TITLE_START - TEXT_START) * 2.0

func morph_start() -> float:
	return title_start() + (MORPH_START - TITLE_START) * 2.0

func morph_finish() -> float:
	return morph_start() + LAST_ARRIVAL

# Share the later cue times with the player controller so text, puff and grant stay synced.
func gift_start() -> float:
	return morph_finish() + 0.16

func puff_start() -> float:
	return gift_start() + 1.3

func unlock_start() -> float:
	return gift_start() + GIFT_HOLD

func gas_finish() -> float:
	return unlock_start() + UNLOCK_HOLD

func bar_progress() -> float:
	return clampf((elapsed - morph_start() - FIRST_ARRIVAL) / (LAST_ARRIVAL - FIRST_ARRIVAL), 0.0, 1.0)

func _draw() -> void:
	if elapsed < TEXT_START:
		return
	var center := roundf(get_viewport_rect().size.x * 0.5)
	if gas_mode and elapsed >= morph_finish():
		if elapsed >= unlock_start():
			_text("FART JUMP UNLOCKED", Vector2(center, 96), TITLE_FONT_SIZE, CREAM)
		elif elapsed >= gift_start():
			_text("POWER GRANTED:", Vector2(center, 77), INTRO_FONT_SIZE, CREAM)
			_text("THE GIFT OF GAS", Vector2(center, 101), TITLE_FONT_SIZE, STAMINA_GREEN)
		return
	if elapsed >= morph_finish():
		return
	if elapsed < title_start():
		_text("TACO COLLECTED" if gas_mode else "AFFLICTED WITH...", Vector2(center, 96), INTRO_FONT_SIZE, CREAM)
		return
	var origin := Vector2(center - _text_size.x * 0.5, 96 - TITLE_FONT_SIZE - 2).round()
	if elapsed < morph_start():
		draw_texture(_surface.get_texture(), origin)
		return
	# No particles/nodes per fragment, no readback, no new textures every frame.
	# The fragments are actual pieces of the lettering, not a replacement sparkle cloud.
	var flight := elapsed - morph_start()
	var rows := floori(_text_size.y / 2.0)
	var columns := floori(_text_size.x / 4.0)
	for row in rows:
		for column in columns:
			var fraction := float(column) / float(columns - 1)
			var delay := fraction * 0.28 + float(row) / float(rows - 1) * 0.04
			var progress := clampf((flight - delay) / FIRST_ARRIVAL, 0.0, 1.0)
			if progress >= 1.0:
				continue
			var source := Rect2(Vector2(column * 4, row * 2), TILE_SIZE)
			var start := origin + source.position
			var destination := meter_rect.position + Vector2(roundf(fraction * (meter_rect.size.x - 1)), row % int(meter_rect.size.y))
			# A shallow upward arc gathers the lettering toward the hearts.
			var bend := (start + destination) * 0.5 + Vector2(0, -24)
			var point := start.lerp(bend, progress).lerp(bend.lerp(destination, progress), progress).round()
			var tile_width := roundf(lerpf(4.0, 1.0, progress))
			draw_texture_rect_region(_surface.get_texture(), Rect2(point, Vector2(tile_width, 2)), source)

func _text(value: String, center: Vector2, font_size: int, tint: Color) -> void:
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2(roundf(center.x - width * 0.5), center.y)
	for offset in [Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1), Vector2(-1,0),
		Vector2(1,0), Vector2(-1,1), Vector2(0,1), Vector2(1,1)]:
		draw_string(_font, baseline + offset, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	draw_string(_font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
