extends RefCounted
## Optional player resource; no autonomous processing or persistent state.
signal resource_changed(value: float, capacity: float)
signal exhaustion_changed(exhausted: bool)
signal enabled_changed(active: bool)
signal appearance_changed

# Normal playtest/default appearance is gas; the curse explicitly starts as stamina.
var stamina_phase: bool = false

var enabled: bool = false
const BASE_CAPACITY: float = 50.0
var capacity: float = BASE_CAPACITY
var recovery_rate: float = 15.0
# Recovery also applies while running: 33 - 15 = 18/sec net (previously 10/sec).
var running_cost: float = 33.0
var resume_threshold: float = 20.0
# Action spending is 1.8x the original tuning; jump safety rules are unchanged.
var ground_jump_cost: float = 5.4
var double_jump_cost: float = 9.0
var wall_jump_cost: float = 5.4
var kick_cost: float = 21.6
var value: float = 50.0
var exhausted: bool = false

func set_stamina_phase(active: bool) -> void:
	stamina_phase = active
	appearance_changed.emit()

func set_enabled(active: bool) -> void:
	enabled = active
	enabled_changed.emit(active)
	reset()

func reset() -> void:
	value = capacity
	_set_exhausted(false)
	resource_changed.emit(value, capacity)

func set_capacity(amount: float) -> void:
	# Capacity cannot be smaller than the fixed running recovery threshold.
	capacity = maxf(resume_threshold, amount)
	value = minf(value, capacity)
	# Changing capacity is neither a refill nor recovery from exhaustion.
	resource_changed.emit(value, capacity)

func spend(amount: float) -> void:
	if not enabled or amount <= 0.0:
		return
	_update_value(value - amount)

func spend_jump(amount: float) -> void:
	if not enabled or amount <= 0.0:
		return
	var previous: float = value
	value = minf(value, maxf(1.0, value - amount))
	# Jump spending cannot enter or clear exhaustion, or create points below 1.
	if value != previous:
		resource_changed.emit(value, capacity)

func can_kick() -> bool:
	return not enabled or value >= 1.0

func spend_kick() -> void:
	spend(kick_cost)

func tick(delta: float, running: bool, airborne: bool = false) -> void:
	if not enabled or delta <= 0.0:
		return
	var drain: float = running_cost if running and not exhausted else 0.0
	var next_value: float = value + (recovery_rate - drain) * delta
	# Airborne run carry can spend down to one, but cannot create reserve points.
	# Existing exhaustion still recovers normally and is never cleared by jumping.
	if airborne and drain > 0.0:
		next_value = maxf(next_value, minf(value, 1.0))
	_update_value(next_value)

func _update_value(next: float) -> void:
	var previous: float = value
	value = clampf(next, 0.0, capacity)
	if value <= 0.00001:
		value = 0.0
		_set_exhausted(true)
	elif exhausted and value >= resume_threshold - 0.00001:
		_set_exhausted(false)
	if value != previous:
		resource_changed.emit(value, capacity)

func _set_exhausted(active: bool) -> void:
	if exhausted == active:
		return
	exhausted = active
	exhaustion_changed.emit(exhausted)
