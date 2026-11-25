extends Control

# Reusable pixel-perfect readiness bar; fills bottom-to-top and brightens on READY.
@export var fill_color: Color = Color(162.0 / 255.0, 59.0 / 255.0, 59.0 / 255.0)
@export var ready_color: Color = Color(217.0 / 255.0, 108.0 / 255.0, 108.0 / 255.0)
@export var frame_color: Color = Color(217.0 / 255.0, 207.0 / 255.0, 195.0 / 255.0)
@export var bar_size: Vector2i = Vector2i(6, 80)

var _ratio := 0.0
var _is_ready := false


func _ready() -> void:
	custom_minimum_size = bar_size
	size = bar_size
	queue_redraw()


func set_meter(ratio: float, is_ready: bool) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_is_ready = is_ready
	queue_redraw()


func _draw() -> void:
	var w := bar_size.x
	var h := bar_size.y
	draw_rect(Rect2(0, 0, w, h), frame_color, false, 1.0)
	var inner_h := h - 2
	var fill_h := int(round(inner_h * _ratio))
	if fill_h <= 0:
		return
	var col := ready_color if _is_ready else fill_color
	draw_rect(Rect2(1, h - 1 - fill_h, w - 2, fill_h), col, true)
