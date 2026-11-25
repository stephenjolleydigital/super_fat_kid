class_name ScreenShake
extends Node
## Temporary camera offset only. Does not touch Camera2D.
## Owner (Player) composes: camera.offset = normal_offset + offset

# Combat: directional 1px impulse, held during hitstop, then smooth settle (no jitter/overshoot).
const COMBAT_IMPULSE_PIXELS := 2.0
const COMBAT_IMPULSE_SETTLE_DURATION := 0.10

# Hard landing: deterministic vertical bump (kept for later bosses/slams; trigger disabled).
const HARD_LAND_DOWN_PX := 2.0
const HARD_LAND_REBOUND_PX := -1.0
const HARD_LAND_DOWN_DURATION := 0.04
const HARD_LAND_REBOUND_DURATION := 0.06
const HARD_LAND_SETTLE_DURATION := 0.12

## Current shake/impulse offset (zero when idle). Read by the camera owner each frame.
var offset: Vector2 = Vector2.ZERO

## Combat impulse hold + settle.
var _impulse_holding: bool = false
var _impulse_settling: bool = false
var _impulse_settle_from: Vector2 = Vector2.ZERO
var _impulse_settle_elapsed: float = 0.0
var _impulse_settle_duration: float = COMBAT_IMPULSE_SETTLE_DURATION

## Hard-land bump: -1 idle; 0 = down; 1 = rebound; 2 = settle.
var _land_phase: int = -1
var _land_elapsed: float = 0.0
var _land_phase_duration: float = 0.0
var _land_from_y: float = 0.0
var _land_to_y: float = 0.0


## Instant horizontal combat impulse. Holds until release_impulse() unless hold is false.
## direction_x > 0 → nudge right; < 0 → nudge left.
func impulse_x(direction_x: float, hold: bool = true) -> void:
	_clear_land_bump()
	_impulse_settling = false
	var dir: float = -1.0 if direction_x < 0.0 else 1.0
	if is_zero_approx(direction_x):
		dir = 1.0
	offset = Vector2(dir * COMBAT_IMPULSE_PIXELS, 0.0)
	if hold:
		_impulse_holding = true
	else:
		_impulse_holding = false
		_begin_impulse_settle()


## Begin smooth return from a held impulse to zero (no overshoot).
## No-op if not currently holding, so it cannot restart/clobber an active settle
## (e.g. hitstop end after a fatal hurt impulse already started settling).
func release_impulse(duration: float = COMBAT_IMPULSE_SETTLE_DURATION) -> void:
	if not _impulse_holding:
		return
	_impulse_holding = false
	_begin_impulse_settle(duration)


func _begin_impulse_settle(duration: float = COMBAT_IMPULSE_SETTLE_DURATION) -> void:
	if offset == Vector2.ZERO:
		_impulse_settling = false
		return
	_impulse_settle_from = offset
	_impulse_settle_duration = maxf(duration, 0.001)
	_impulse_settle_elapsed = 0.0
	_impulse_settling = true


## Deterministic hard-landing vertical bump: down 2px → rebound -1px → ease to 0.
func play_hard_land_bump() -> void:
	clear_combat_impulse()
	_begin_land_phase(0, 0.0, HARD_LAND_DOWN_PX, HARD_LAND_DOWN_DURATION)


func clear_combat_impulse() -> void:
	_impulse_holding = false
	_impulse_settling = false
	_impulse_settle_elapsed = 0.0
	offset.x = 0.0


func _clear_land_bump() -> void:
	_land_phase = -1
	_land_elapsed = 0.0


func _begin_land_phase(phase: int, from_y: float, to_y: float, duration: float) -> void:
	_land_phase = phase
	_land_from_y = from_y
	_land_to_y = to_y
	_land_phase_duration = maxf(duration, 0.001)
	_land_elapsed = 0.0
	offset = Vector2(0.0, from_y)


func _process(delta: float) -> void:
	if _impulse_holding:
		# Keep the directional displacement fixed (e.g. through kick hitstop).
		return

	if _impulse_settling:
		_impulse_settle_elapsed = minf(
			_impulse_settle_elapsed + delta,
			_impulse_settle_duration
		)
		var u: float = _impulse_settle_elapsed / _impulse_settle_duration
		# Ease-out cubic: fast leave from peak, smooth into center. No overshoot.
		var inv: float = 1.0 - u
		var eased: float = 1.0 - inv * inv * inv
		offset = _impulse_settle_from.lerp(Vector2.ZERO, eased)
		if _impulse_settle_elapsed >= _impulse_settle_duration:
			offset = Vector2.ZERO
			_impulse_settling = false
		return

	if _land_phase >= 0:
		_land_elapsed = minf(_land_elapsed + delta, _land_phase_duration)
		var u: float = _land_elapsed / _land_phase_duration
		var eased: float
		match _land_phase:
			0:
				eased = 1.0 - (1.0 - u) * (1.0 - u)
			1:
				eased = u * u * (3.0 - 2.0 * u)
			_:
				var inv: float = 1.0 - u
				eased = 1.0 - inv * inv * inv
		offset = Vector2(0.0, lerpf(_land_from_y, _land_to_y, eased))
		if _land_elapsed >= _land_phase_duration:
			match _land_phase:
				0:
					_begin_land_phase(
						1,
						HARD_LAND_DOWN_PX,
						HARD_LAND_REBOUND_PX,
						HARD_LAND_REBOUND_DURATION
					)
				1:
					_begin_land_phase(
						2,
						HARD_LAND_REBOUND_PX,
						0.0,
						HARD_LAND_SETTLE_DURATION
					)
				_:
					_clear_land_bump()
					offset = Vector2.ZERO
		return

	# Idle
	offset = Vector2.ZERO
