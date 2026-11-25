@tool
extends Node2D
## Palette-only placeholder art. The foreground lip conceals the descent.
var open := false

func _draw() -> void:
	draw_rect(Rect2(-25, -3, 50, 7), Color8(43, 45, 66))
	draw_rect(Rect2(-21, -2, 42, 5), Color.BLACK)
	if not open:
		draw_rect(Rect2(-20, -3, 40, 4), Color8(253, 243, 207))
		for x in range(-16, 20, 8):
			draw_rect(Rect2(x, -3, 2, 4), Color8(43, 45, 66))
	else:
		draw_rect(Rect2(27, -6, 32, 5), Color8(43, 45, 66))
		draw_rect(Rect2(-25, 3, 50, 96), Color8(43, 45, 66))
