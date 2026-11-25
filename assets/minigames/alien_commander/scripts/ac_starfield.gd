extends Node2D

# Decorative Galaga-style falling starfield for the 256x224 arcade playfield.
# Purely visual: no collision, no input, no signals, no gameplay coupling.

const PLAYFIELD_WIDTH := 256
const PLAYFIELD_HEIGHT := 224

# Groups are color buckets, not speed tiers: the accent group shares the mid
# speed, so only three discrete fall speeds are ever visible.
const LAYER_COUNT := 4
const MID_LAYER := 1

# Master palette only.
const COLOR_FAR := Color(111.0 / 255.0, 116.0 / 255.0, 124.0 / 255.0) # #6F747C
const COLOR_MID := Color(142.0 / 255.0, 156.0 / 255.0, 171.0 / 255.0) # #8E9CAB
const COLOR_ACCENT := Color(160.0 / 255.0, 196.0 / 255.0, 255.0 / 255.0) # #A0C4FF
const COLOR_NEAR := Color(215.0 / 255.0, 235.0 / 255.0, 252.0 / 255.0) # #D7EBFC

const LAYER_COLORS: Array[Color] = [COLOR_FAR, COLOR_MID, COLOR_ACCENT, COLOR_NEAR]

@export var far_count := 17
@export var mid_count := 9
@export var accent_count := 3
@export var near_count := 2

# Falling speeds in px/sec; the three discrete rates are what reads as depth.
@export var far_speed := 6.0
@export var mid_speed := 11.0
@export var near_speed := 18.0

# Fixed seed so the starting field is reproducible run to run.
@export var field_seed := 20260818

# Hard two-color twinkle on a few mid stars: instant switch, no fade or glow.
@export var flicker_count := 3
@export var flicker_interval_min := 4.0
@export var flicker_interval_max := 9.0
@export var flicker_flash_duration := 0.1

var _counts: Array[int] = []
var _speeds: Array[float] = []
# Sub-pixel movement lives here only; it is never rendered.
var _accumulators: Array[float] = [0.0, 0.0, 0.0, 0.0]
# Star positions per group, stored as whole pixels.
var _stars: Array = [[], [], [], []]
var _rng := RandomNumberGenerator.new()

# Flicker state, indexed against the first N stars of the mid group.
# Its own generator keeps the layout stream reproducible regardless of timing.
var _flicker_rng := RandomNumberGenerator.new()
var _flicker_lit: Array[bool] = []
var _flicker_waits: Array[float] = []
var _flicker_left: Array[float] = []


func _ready() -> void:
	_counts = [
		maxi(0, far_count),
		maxi(0, mid_count),
		maxi(0, accent_count),
		maxi(0, near_count),
	]
	# Accent stars ride at the mid speed so no fourth speed tier appears.
	_speeds = [
		maxf(0.0, far_speed),
		maxf(0.0, mid_speed),
		maxf(0.0, mid_speed),
		maxf(0.0, near_speed),
	]
	_rng.seed = field_seed
	_flicker_rng.seed = field_seed + 1
	_seed_field()
	_seed_flicker()
	queue_redraw()


func _seed_field() -> void:
	for layer in LAYER_COUNT:
		var stars: Array[Vector2i] = []
		for _i in _counts[layer]:
			stars.append(Vector2i(_random_x(), _rng.randi_range(0, PLAYFIELD_HEIGHT - 1)))
		_stars[layer] = stars


func _seed_flicker() -> void:
	var count := clampi(flicker_count, 0, _counts[MID_LAYER])
	_flicker_lit.resize(count)
	_flicker_waits.resize(count)
	_flicker_left.resize(count)
	for i in count:
		_flicker_lit[i] = false
		_flicker_left[i] = 0.0
		# Scattered initial waits keep the few flicker stars out of sync.
		_flicker_waits[i] = _flicker_rng.randf_range(0.0, maxf(0.0, flicker_interval_max))


func _process(delta: float) -> void:
	var advanced := false
	for layer in LAYER_COUNT:
		_accumulators[layer] += _speeds[layer] * delta
		while _accumulators[layer] >= 1.0:
			_accumulators[layer] -= 1.0
			_step_layer(layer)
			advanced = true
	# A flicker toggle changes pixels without moving anything, so it has to
	# count as a reason to redraw.
	if _update_flicker(delta):
		advanced = true
	# Redraw only when something actually changed on screen.
	if advanced:
		queue_redraw()


func _step_layer(layer: int) -> void:
	var stars: Array = _stars[layer]
	for i in stars.size():
		var star: Vector2i = stars[i]
		star.y += 1
		if star.y >= PLAYFIELD_HEIGHT:
			# Subtracting the height preserves each star's existing gap, so the
			# field never visibly restarts and stars wrap independently.
			star.y -= PLAYFIELD_HEIGHT
			star.x = _random_x()
		stars[i] = star


func _update_flicker(delta: float) -> bool:
	var toggled := false
	for i in _flicker_lit.size():
		if _flicker_lit[i]:
			_flicker_left[i] -= delta
			if _flicker_left[i] <= 0.0:
				_flicker_lit[i] = false
				_flicker_waits[i] = _next_flicker_wait()
				toggled = true
		else:
			_flicker_waits[i] -= delta
			if _flicker_waits[i] <= 0.0:
				_flicker_lit[i] = true
				_flicker_left[i] = maxf(0.0, flicker_flash_duration)
				toggled = true
	return toggled


func _next_flicker_wait() -> float:
	var low := maxf(0.0, flicker_interval_min)
	var high := maxf(low, flicker_interval_max)
	return _flicker_rng.randf_range(low, high)


func _random_x() -> int:
	return _rng.randi_range(0, PLAYFIELD_WIDTH - 1)


func _draw() -> void:
	for layer in LAYER_COUNT:
		var base_color: Color = LAYER_COLORS[layer]
		var stars: Array = _stars[layer]
		for i in stars.size():
			var star: Vector2i = stars[i]
			var color := base_color
			if layer == MID_LAYER and i < _flicker_lit.size() and _flicker_lit[i]:
				color = COLOR_NEAR
			draw_rect(Rect2(star.x, star.y, 1, 1), color, true)
