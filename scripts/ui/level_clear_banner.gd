extends Control
## Shared, palette-only pixel decoration; no per-level image assets.

const INK := Color8(43, 45, 66)
const BLACK := Color8(0, 0, 0)
const GOLD := Color8(249, 199, 79)
const ORANGE := Color8(247, 127, 0)
const CREAM := Color8(253, 243, 207)
const BLUE := Color8(58, 134, 255)
const RED := Color8(214, 40, 40)
const SPARKLES := [Vector2(22, 18), Vector2(330, 18), Vector2(38, 47), Vector2(316, 47)]

var _elapsed: float = 0.0
var _sparkle_frame: int = 0
var _world_clear: bool = false


func _ready() -> void:
	set_process(false)
	var label := $LevelCompleteLabel as Label
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_outline_color", BLACK)
	label.add_theme_color_override("font_shadow_color", ORANGE)


func celebrate(world_clear: bool = false) -> void:
	_world_clear = world_clear
	_elapsed = 0.0
	_sparkle_frame = 0
	position.y = 12
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		set_process(false)
		return
	_elapsed += delta
	# Discrete whole-pixel steps keep the font and borders sharp throughout.
	var step := mini(int(_elapsed / 0.05), 4)
	position.y = float([12, 6, 0, -2, 0][step])
	if _world_clear:
		# A large center-screen slam, then alternating pixel rays (no blurred scaling).
		position.y += 65.0
		if _elapsed < 0.4:
			position.x = float([0, -6, 6, -3, 3, 0][mini(int(_elapsed / 0.06), 5)])
		else:
			position.x = 0.0
	var frame := int(_elapsed / 0.15) % 4
	if frame != _sparkle_frame:
		_sparkle_frame = frame
		queue_redraw()


func _draw() -> void:
	if _world_clear:
		for index in range(12):
			var x := float(index * 32)
			var length := float(8 + (index + _sparkle_frame) % 3 * 5)
			var tint: Color = GOLD if index % 2 == 0 else ORANGE
			draw_rect(Rect2(x, -length - 6, 4, length), tint)
			draw_rect(Rect2(x, 70, 4, length), tint)
	_stepped_rect(Rect2(3, 4, 352, 64), BLACK)
	_stepped_rect(Rect2(0, 0, 352, 64), BLACK)
	_stepped_rect(Rect2(2, 2, 348, 60), ORANGE)
	_stepped_rect(Rect2(2, 2, 348, 56), GOLD)
	_stepped_rect(Rect2(5, 5, 342, 54), INK)
	# Inset highlight and a pair of arcade stripes frame the headline.
	draw_rect(Rect2(12, 7, 328, 1), CREAM)
	draw_rect(Rect2(72, 12, 208, 2), GOLD)
	draw_rect(Rect2(88, 51, 176, 2), ORANGE)
	for index in range(SPARKLES.size()):
		var center: Vector2 = SPARKLES[index]
		var radius := 2 + ((_sparkle_frame + index) % 3) * 2
		var tint: Color = [GOLD, BLUE, RED, CREAM][index]
		draw_rect(Rect2(center - Vector2(radius, 1), Vector2(radius * 2 + 1, 3)), tint)
		draw_rect(Rect2(center - Vector2(1, radius), Vector2(3, radius * 2 + 1)), tint)
		draw_rect(Rect2(center, Vector2.ONE), CREAM)


func _stepped_rect(rect: Rect2, tint: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 0), rect.size - Vector2(8, 0)), tint)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), tint)
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size - Vector2(0, 8)), tint)
