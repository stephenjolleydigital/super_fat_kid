extends Node2D

const SCENE := preload("res://scenes/effects/UpgradePickupEffect.tscn")

const DURATION := 0.35
const SPARKLE_COUNT_MIN := 10
const SPARKLE_COUNT_MAX := 12
const RING_SEGMENTS := 16

const COLOR_WHITE := Color("#EEF7FD")
const COLOR_PALE_BLUE_WHITE := Color("#D7EBFC")
const COLOR_LIGHT_SKY_BLUE := Color("#B8D7FA")
const COLOR_UPGRADE_YELLOW := Color("#FFD447")
const COLOR_ORANGE_ACCENT := Color("#F59A2F")

const _SPARKLE_COLORS: Array[Color] = [
	COLOR_WHITE,
	COLOR_WHITE,
	COLOR_PALE_BLUE_WHITE,
	COLOR_PALE_BLUE_WHITE,
	COLOR_LIGHT_SKY_BLUE,
	COLOR_LIGHT_SKY_BLUE,
	COLOR_UPGRADE_YELLOW,
	COLOR_ORANGE_ACCENT,
]

var _ring: Line2D


static func spawn(parent: Node, world_pos: Vector2) -> void:
	if parent == null:
		return
	var effect: Node2D = SCENE.instantiate()
	parent.add_child(effect)
	effect.global_position = world_pos.round()


func _ready() -> void:
	_play_effect()


func _play_effect() -> void:
	_create_ring()
	add_child(_ring)
	_animate_ring()

	var sparkle_count := randi_range(SPARKLE_COUNT_MIN, SPARKLE_COUNT_MAX)
	for i in range(sparkle_count):
		var sparkle := _create_sparkle()
		add_child(sparkle)
		_animate_sparkle(sparkle, i, sparkle_count)

	var finish_tween := create_tween()
	finish_tween.tween_interval(DURATION)
	finish_tween.tween_callback(queue_free)


func _create_ring() -> void:
	_ring = Line2D.new()
	_ring.width = 1.0
	_ring.default_color = COLOR_UPGRADE_YELLOW
	_ring.closed = true
	_ring.antialiased = false
	_ring.points = _make_circle_points(8.0)


func _make_circle_points(radius: float) -> PackedVector2Array:
	var snapped_radius := roundi(radius)
	var points := PackedVector2Array()
	points.resize(RING_SEGMENTS)
	for i in range(RING_SEGMENTS):
		var angle := TAU * float(i) / float(RING_SEGMENTS)
		points[i] = (Vector2(cos(angle), sin(angle)) * float(snapped_radius)).round()
	return points


func _update_ring_radius(radius: float) -> void:
	if not is_instance_valid(_ring):
		return
	_ring.points = _make_circle_points(radius)


func _animate_ring() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(Callable(self, "_update_ring_radius"), 8.0, 28.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _create_sparkle() -> ColorRect:
	var sparkle := ColorRect.new()
	sparkle.size = Vector2(2, 2)
	sparkle.position = Vector2(-1, -1)
	sparkle.color = _SPARKLE_COLORS.pick_random()
	return sparkle


func _animate_sparkle(sparkle: ColorRect, index: int, total: int) -> void:
	var base_angle := TAU * float(index) / float(total)
	var angle := base_angle + randf_range(-0.25, 0.25)
	var distance := float(randi_range(14, 22))
	var end_offset := (Vector2(cos(angle), sin(angle)) * distance).round()
	var start_pos := Vector2(-1, -1)
	var end_pos := (start_pos + end_offset).round()

	sparkle.position = start_pos

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(progress: float) -> void:
			if is_instance_valid(sparkle):
				sparkle.position = start_pos.lerp(end_pos, progress).round(),
		0.0, 1.0, DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sparkle, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
