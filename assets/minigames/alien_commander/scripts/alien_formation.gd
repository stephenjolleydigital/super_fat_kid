extends Node2D

signal fire_order_changed(ratio: float, ready: bool)
signal move_meter_changed(ratio: float, ready: bool)
signal refill_finished

# Set by alien_commander_game.gd; decides which systems tick each frame.
# LOCKED: nothing (intro, wave clear, upgrade, game over)
# PREP:   navigate, swap (free), micro-move — no firing, meters scripted
# ACTIVE: full combat
# REFILL: formation animates itself back to a full 3x3
enum Phase { LOCKED, PREP, ACTIVE, REFILL }

const ALIEN_BULLET_SCENE := preload("res://assets/minigames/alien_commander/scenes/AlienBullet.tscn")
const SELECT_MODULATE := Color(1.2, 1.2, 1.0, 1.0)
const IDLE_FRAME_DURATION := 0.5
const IDLE_ROW_OFFSETS := [0.0, 0.2, 0.4]
const GRID_SIZE := 9

# Scene grid layout (Alien_Commander.tscn): 64px columns, 24px rows, formation origin (64, 24).
const GRID_COL_SPACING := 64
const GRID_ROW_SPACING := 24
const ALIEN_SPRITE_SIZE := 16
const CURSOR_FRAME_PADDING := 6
const CURSOR_FRAME_SIZE := ALIEN_SPRITE_SIZE + CURSOR_FRAME_PADDING * 2

# Slot cursor — palette crimson reads as command UI, not damage flash.
const CURSOR_COLOR := Color(162.0 / 255.0, 59.0 / 255.0, 59.0 / 255.0)
# Grab cursor — palette cream + tighter inset signal "carrying this alien".
const CURSOR_GRAB_COLOR := Color(253.0 / 255.0, 243.0 / 255.0, 207.0 / 255.0)
const CURSOR_GRAB_INSET := 4
const CURSOR_ARM_LENGTH := 5
const CURSOR_INSET_A := 2
const CURSOR_INSET_B := 3
const CURSOR_ANIM_FPS := 8.0
const CURSOR_ANIM_STEP := 4

# Two independent shared meters gate firing and movement; both latch READY and only reset on use.
@export var fire_order_fill_time := 0.75
@export var move_fill_time := 1.5

# Selected-alien horizontal micro-movement (dodge) — free, never consumes the MOVE meter.
# Speeds are px/sec and exported so a future upgrade can raise them.
# Recenter is tuned to ~2.5x manual speed: clearly faster than the player, not a snap.
@export var micro_move_speed := 40.0
@export var micro_recenter_speed := 100.0
# Wave-clear refill: survivors sink, revived aliens descend from above.
@export var refill_speed := 60.0
# Entry gap above each alien's target slot. Uniform, so a column's revived
# aliens keep their final row spacing while descending instead of stacking.
@export var refill_entry_height := 96.0
# Half cell (32) - sprite half (8) - 4px safety inset so neighbors can never overlap.
const MICRO_MAX_OFFSET_X := 20.0
# Matches the 0.5 deadzone the project InputMap uses for stick/trigger bindings.
const STICK_DEADZONE := 0.5
const TRIGGER_DEADZONE := 0.5
const CURSOR_ERROR_DURATION := 0.2
const CURSOR_ERROR_COLOR := Color(217.0 / 255.0, 108.0 / 255.0, 108.0 / 255.0)
const CURSOR_ERROR_SHAKES: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i.ZERO,
	Vector2i(1, 0),
	Vector2i.ZERO,
]
# Canonical top-left reticle glyph; other corners mirror via _draw_corner_at().
# Select glyph: long plain 1px arms, no hooks — a smooth tracking frame.
const CORNER_PIXELS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5),
]
# Grab glyph: shorter L with inward hooks at the arm tips — claws gripping the alien.
# Diagonally symmetric so every mirrored corner reads as the same bracket rotated.
const CORNER_GRAB_PIXELS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(4, 1),
	Vector2i(1, 4),
]

# Fixed 9 slots — navigation and visuals share slot indices; collapsing a survivor list breaks grid math.
var _grid: Array = [null, null, null, null, null, null, null, null, null]
var _grid_built := false
# Slot 7 (bottom-middle) is the most intuitive starting command position, closest to the hero ship.
var _selected_slot: int = 7
var _fire_order := 0.0
var _move_meter := 0.0
var _grab_held := false
var _cursor_time := 0.0
var _cursor_inset := CURSOR_INSET_A
var _cursor_error_left := 0.0
# Float per-slot dodge offsets; rendered positions are always rounded to whole pixels.
var _micro_offsets_x: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
# Previous-frame nav state [left, right, up, down] for one-step-per-press edge detection.
var _nav_prev: Array[bool] = [false, false, false, false]
var _phase: Phase = Phase.LOCKED
# Casualties parked per column, keyed on the column they occupied when they died,
# so the refill returns them to that same column.
var _dead_by_col: Array = [[], [], []]
# Float in-flight positions during REFILL; rendered positions stay whole pixels.
var _refill_pos: Array[Vector2] = []

@onready var _bullets_root: Node2D = $"../AlienBullets"


func _ready() -> void:
	_ensure_grid_ready()
	_start_idle_animations()
	_apply_selection_visual()
	fire_order_changed.emit(_fire_order, false)
	move_meter_changed.emit(_move_meter, false)
	queue_redraw()


func _ensure_grid_ready() -> void:
	# Sibling _ready() order can call us before _build_grid(); keep nine slots either way.
	if _grid.size() != GRID_SIZE:
		_grid.resize(GRID_SIZE)
		for slot in GRID_SIZE:
			_grid[slot] = null
	if not _grid_built:
		_build_grid()
		_grid_built = true


func _start_idle_animations() -> void:
	for slot in GRID_SIZE:
		if not _is_slot_living(slot):
			continue
		var alien := _grid[slot] as Area2D
		var spr := alien.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr:
			spr.play(&"idle")
			spr.frame = 0
			var row := int(slot / 3.0)
			var offset_seconds: float = IDLE_ROW_OFFSETS[row]
			spr.frame_progress = clampf(offset_seconds / IDLE_FRAME_DURATION, 0.0, 0.999)


func _process(delta: float) -> void:
	_update_cursor_animation(delta)
	_sync_grid()
	if _phase == Phase.REFILL:
		_update_refill(delta)
		return
	if _phase == Phase.LOCKED:
		return
	# PREP and ACTIVE share command input; only ACTIVE may fire or build meters.
	_update_grab_state()
	_handle_nav()
	_update_micro_movement(delta)
	if _phase != Phase.ACTIVE:
		return
	# Meters only build during active play so readiness can't bank during win/loss screens.
	_advance_fire_order(delta)
	_advance_move_meter(delta)
	_handle_fire()


func set_phase_locked() -> void:
	_phase = Phase.LOCKED


func set_phase_prep() -> void:
	_phase = Phase.PREP


func set_phase_active() -> void:
	_phase = Phase.ACTIVE


func begin_refill() -> void:
	_ensure_grid_ready()
	_sync_grid()
	_phase = Phase.REFILL
	_assign_refill_slots()


func reset_meters() -> void:
	_fire_order = 0.0
	_move_meter = 0.0
	fire_order_changed.emit(_fire_order, false)
	move_meter_changed.emit(_move_meter, false)


func set_prep_meters(ratio: float) -> void:
	# Scripted intro fill: both meters ride the same ramp from empty at GET READY
	# to full exactly at COMMAND, ignoring their normal fill rates.
	var r := clampf(ratio, 0.0, 1.0)
	var is_ready := r >= 1.0
	_fire_order = r
	_move_meter = r
	fire_order_changed.emit(r, is_ready)
	move_meter_changed.emit(r, is_ready)


func _update_grab_state() -> void:
	var grab_now := _is_grab_pressed()
	if grab_now != _grab_held:
		_grab_held = grab_now
		queue_redraw()


# Raw-input reads below deliberately bypass the shared ui_*/alien_* actions: this minigame
# reinterprets arrows, face buttons, and triggers without touching the project InputMap.
func _is_grab_pressed() -> bool:
	if Input.is_physical_key_pressed(KEY_SHIFT):
		return true
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER):
			return true
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) >= TRIGGER_DEADZONE:
			return true
	return false


func _is_fire_pressed() -> bool:
	if Input.is_physical_key_pressed(KEY_SPACE):
		return true
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
			return true
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) >= TRIGGER_DEADZONE:
			return true
	return false


func _advance_fire_order(delta: float) -> void:
	if _fire_order >= 1.0:
		return
	_fire_order = minf(1.0, _fire_order + delta / fire_order_fill_time)
	fire_order_changed.emit(_fire_order, _fire_order >= 1.0)


func _advance_move_meter(delta: float) -> void:
	if _move_meter >= 1.0:
		return
	_move_meter = minf(1.0, _move_meter + delta / move_fill_time)
	move_meter_changed.emit(_move_meter, _move_meter >= 1.0)


func _handle_fire() -> void:
	if not _is_fire_pressed():
		return
	if _fire_order < 1.0:
		return
	if _is_slot_living(_selected_slot):
		_spawn_alien_bullet()
		_fire_order = 0.0
		fire_order_changed.emit(_fire_order, false)
	elif _cursor_error_left <= 0.0:
		# Empty slot: invalid feedback, throttled to the shake duration; Fire Order stays READY.
		_trigger_cursor_error()


func _is_grabbing() -> bool:
	return _grab_held and _is_slot_living(_selected_slot)


func _build_grid() -> void:
	_grid = [null, null, null, null, null, null, null, null, null]
	var rx := RegEx.new()
	rx.compile("^Alien(\\d+)_(\\d+)$")
	for child in $Aliens.get_children():
		if child is not Area2D:
			continue
		var m := rx.search(String(child.name))
		if m == null:
			continue
		var row := int(m.get_string(1)) - 1
		var col := int(m.get_string(2)) - 1
		if row < 0 or row > 2 or col < 0 or col > 2:
			push_warning("Alien_Commander: alien outside 3x3 grid: %s" % child.name)
			continue
		var slot := row * 3 + col
		if _grid[slot] != null:
			push_warning("Alien_Commander: duplicate grid slot %d" % slot)
		_grid[slot] = child
	for i in GRID_SIZE:
		if _grid[i] == null:
			push_error("Alien_Commander: missing alien for grid slot %d" % i)


func _sync_grid() -> void:
	_ensure_grid_ready()
	var changed := false
	for slot in GRID_SIZE:
		var alien = _grid[slot]
		if alien == null:
			continue
		if not is_instance_valid(alien) or not alien.is_inside_tree():
			_grid[slot] = null
			changed = true
		elif not _is_alien_alive(alien):
			# Park the casualty under the column it died in; the refill returns it there.
			_dead_by_col[slot % 3].append(alien)
			_grid[slot] = null
			changed = true
	if changed:
		_apply_selection_visual()
		queue_redraw()


func _update_cursor_animation(delta: float) -> void:
	_cursor_time += delta
	var step := int(_cursor_time * CURSOR_ANIM_FPS)
	var phase := step >> 2  # CURSOR_ANIM_STEP ticks per phase
	var inset := CURSOR_INSET_A if phase % 2 == 0 else CURSOR_INSET_B
	var needs_redraw := false
	if inset != _cursor_inset:
		_cursor_inset = inset
		needs_redraw = true
	if _cursor_error_left > 0.0:
		_cursor_error_left = maxf(0.0, _cursor_error_left - delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _trigger_cursor_error() -> void:
	_cursor_error_left = CURSOR_ERROR_DURATION
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_alien_select_error()
	queue_redraw()


func _get_cursor_draw_params() -> Dictionary:
	if _cursor_error_left <= 0.0:
		return {"offset": Vector2i.ZERO, "color": CURSOR_COLOR}
	var elapsed := CURSOR_ERROR_DURATION - _cursor_error_left
	var frame := mini(int(elapsed / (CURSOR_ERROR_DURATION / 4.0)), 3)
	var color := CURSOR_COLOR if frame == 3 else CURSOR_ERROR_COLOR
	return {"offset": CURSOR_ERROR_SHAKES[frame], "color": color}


func _draw() -> void:
	var rect := _get_slot_rect(_selected_slot)
	var params := _get_cursor_draw_params()
	rect.position += params.offset
	# Grabbing clamps to a tighter, cream grip frame; breathing inset is paused while carrying.
	if _is_grabbing():
		_draw_slot_brackets(rect, CURSOR_GRAB_INSET, CURSOR_GRAB_COLOR, CORNER_GRAB_PIXELS)
	else:
		_draw_slot_brackets(rect, _cursor_inset, params.color, CORNER_PIXELS)


func _get_slot_rect(slot: int) -> Rect2i:
	# Brackets hug the selected alien's rendered position; empty slots stay at cell center.
	var center := Vector2i(_slot_local_center(slot))
	if _is_slot_living(slot):
		var alien := _grid[slot] as Node2D
		center = Vector2i(roundi(alien.position.x), roundi(alien.position.y))
	var half := CURSOR_FRAME_SIZE >> 1
	return Rect2i(center.x - half, center.y - half, CURSOR_FRAME_SIZE, CURSOR_FRAME_SIZE)


func _draw_slot_brackets(rect: Rect2i, inset: int, color: Color, pixels: Array[Vector2i]) -> void:
	# Inclusive pixel edges: rect covers position .. position + size - 1.
	var left := rect.position.x + inset
	var top := rect.position.y + inset
	var right := rect.position.x + rect.size.x - 1 - inset
	var bottom := rect.position.y + rect.size.y - 1 - inset

	_draw_corner_at(Vector2i(left, top), 1, 1, color, pixels)
	_draw_corner_at(Vector2i(right, top), -1, 1, color, pixels)
	_draw_corner_at(Vector2i(left, bottom), 1, -1, color, pixels)
	_draw_corner_at(Vector2i(right, bottom), -1, -1, color, pixels)


func _draw_corner_at(corner: Vector2i, mx: int, my: int, color: Color, pixels: Array[Vector2i]) -> void:
	for offset in pixels:
		var px := corner.x + offset.x * mx
		var py := corner.y + offset.y * my
		draw_rect(Rect2i(px, py, 1, 1), color)


func _handle_nav() -> void:
	# WASD / d-pad / left stick only — arrow keys are reserved for micro-movement.
	var pressed := _read_nav_pressed()
	var just: Array[bool] = [false, false, false, false]
	for i in 4:
		just[i] = pressed[i] and not _nav_prev[i]
	_nav_prev = pressed
	var drow := 0
	var dcol := 0
	if just[0]:
		dcol = -1
	elif just[1]:
		dcol = 1
	elif just[2]:
		drow = -1
	elif just[3]:
		drow = 1
	else:
		return
	if _is_grabbing():
		_try_grab_move(drow, dcol)
	else:
		_move_cursor(drow, dcol)


func _read_nav_pressed() -> Array[bool]:
	var left := Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_physical_key_pressed(KEY_S)
	for device in Input.get_connected_joypads():
		var stick_x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var stick_y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		left = left or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT) or stick_x <= -STICK_DEADZONE
		right = right or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT) or stick_x >= STICK_DEADZONE
		up = up or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP) or stick_y <= -STICK_DEADZONE
		down = down or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN) or stick_y >= STICK_DEADZONE
	return [left, right, up, down]


func _move_cursor(drow: int, dcol: int) -> void:
	var row := (int(_selected_slot / 3.0) + drow + 3) % 3
	var col := (_selected_slot % 3 + dcol + 3) % 3
	_selected_slot = row * 3 + col
	_apply_selection_visual()
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_alien_select()
	queue_redraw()


func _try_grab_move(drow: int, dcol: int) -> void:
	# Movement is gated by the MOVE meter; not READY means the order is ignored, no reset.
	# PREP is exempt: intro swapping is free and must not disturb the scripted fill.
	if _phase != Phase.PREP and _move_meter < 1.0:
		return
	var cur := _selected_slot
	var row := (int(cur / 3.0) + drow + 3) % 3
	var col := (cur % 3 + dcol + 3) % 3
	var target := row * 3 + col
	if target == cur:
		return
	var moving = _grid[cur]
	if _is_slot_living(target):
		# Swap: both aliens trade tiles instantly.
		var other = _grid[target]
		_grid[cur] = other
		_grid[target] = moving
		(other as Node2D).position = _slot_local_center(cur)
	else:
		_grid[target] = moving
		_grid[cur] = null
	(moving as Node2D).position = _slot_local_center(target)
	# Formation swaps are authoritative: no dodge offset survives into either affected cell.
	_micro_offsets_x[cur] = 0.0
	_micro_offsets_x[target] = 0.0
	_selected_slot = target
	if _phase != Phase.PREP:
		_move_meter = 0.0
		move_meter_changed.emit(_move_meter, false)
	_apply_selection_visual()
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_alien_select()
	queue_redraw()


func _slot_local_center(slot: int) -> Vector2:
	# Integer tile centers keep instant repositioning pixel-perfect.
	return Vector2((slot % 3) * GRID_COL_SPACING, int(slot / 3.0) * GRID_ROW_SPACING)


func _read_micro_direction() -> int:
	# Held input: Left/Right arrows, X/B face buttons, right stick. Opposing inputs cancel.
	var left := Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_RIGHT)
	for device in Input.get_connected_joypads():
		left = left or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
		right = right or Input.is_joy_button_pressed(device, JOY_BUTTON_B)
		var stick_x := Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		# Sign-only so dodge speed stays constant and pixel motion stays uniform.
		if stick_x <= -STICK_DEADZONE:
			left = true
		elif stick_x >= STICK_DEADZONE:
			right = true
	return int(right) - int(left)


func _update_micro_movement(delta: float) -> void:
	var dir := _read_micro_direction()
	for slot in GRID_SIZE:
		if not _is_slot_living(slot):
			_micro_offsets_x[slot] = 0.0
			continue
		var offset := _micro_offsets_x[slot]
		if slot == _selected_slot:
			# Selected alien holds its position when idle; only deselected aliens recenter.
			if dir != 0:
				offset = clampf(offset + dir * micro_move_speed * delta, -MICRO_MAX_OFFSET_X, MICRO_MAX_OFFSET_X)
		else:
			offset = move_toward(offset, 0.0, micro_recenter_speed * delta)
		_micro_offsets_x[slot] = offset
		# Float offset lives only in the array; applied position is always whole pixels.
		var alien := _grid[slot] as Node2D
		var rendered := _slot_local_center(slot) + Vector2(roundf(offset), 0.0)
		if slot == _selected_slot and alien.position != rendered:
			queue_redraw()
		alien.position = rendered


func _is_slot_living(slot: int) -> bool:
	if slot < 0 or slot >= GRID_SIZE or _grid.size() != GRID_SIZE:
		return false
	var alien = _grid[slot]
	if alien == null or not is_instance_valid(alien) or not alien.is_inside_tree():
		return false
	return _is_alien_alive(alien)


func _is_alien_alive(alien) -> bool:
	if alien.has_method(&"is_alive"):
		return bool(alien.call(&"is_alive"))
	return true


func _apply_selection_visual() -> void:
	for slot in GRID_SIZE:
		if not _is_slot_living(slot):
			continue
		var alien := _grid[slot] as Area2D
		var spr := alien.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr:
			spr.modulate = SELECT_MODULATE if slot == _selected_slot else Color.WHITE


func get_living_aliens() -> Array:
	_ensure_grid_ready()
	_sync_grid()
	var living: Array = []
	for slot in GRID_SIZE:
		if _is_slot_living(slot):
			living.append(_grid[slot])
	return living


func _spawn_alien_bullet() -> void:
	_ensure_grid_ready()
	if not _is_slot_living(_selected_slot):
		return
	var alien := _grid[_selected_slot] as Area2D
	var bullet: Node2D = ALIEN_BULLET_SCENE.instantiate()
	# Owner must be set before add_child so spawn overlap never damages the shooter.
	if bullet.has_method(&"set_owner_alien"):
		bullet.call(&"set_owner_alien", alien)
	_bullets_root.add_child(bullet)
	bullet.global_position = alien.global_position + Vector2(0, 4)
	var audio := ACAudio.find_audio(self)
	if audio:
		audio.play_alien_shoot()


func _assign_refill_slots() -> void:
	# Per column: survivors compact toward the bottom keeping relative order,
	# then that column's own casualties refill the open top slots from above.
	var new_grid: Array = [null, null, null, null, null, null, null, null, null]
	var unfilled: Array[int] = []
	for col in 3:
		var survivors: Array = []
		for row in 3:
			var slot := row * 3 + col
			if _is_slot_living(slot):
				survivors.append(_grid[slot])
		var count := survivors.size()
		for i in count:
			new_grid[(3 - count + i) * 3 + col] = survivors[i]
		# Open rows are 0 .. (2 - count); fill the lowest of them first.
		var open_rows: Array[int] = []
		for row in (3 - count):
			open_rows.append(row)
		open_rows.reverse()
		var pool: Array = _dead_by_col[col]
		for row in open_rows:
			if pool.is_empty():
				unfilled.append(row * 3 + col)
			else:
				new_grid[row * 3 + col] = pool.pop_front()
	# A living alien can migrate columns into a vacated slot, leaving one column
	# short and another holding surplus dead. Globally the counts always balance,
	# so borrow from the nearest column that still has casualties parked.
	for slot in unfilled:
		var donor := _nearest_stocked_column(slot % 3)
		if donor >= 0:
			new_grid[slot] = _dead_by_col[donor].pop_front()
		else:
			push_warning("Alien_Commander: refill could not fill grid slot %d" % slot)
	_grid = new_grid
	_begin_refill_motion()


func _nearest_stocked_column(col: int) -> int:
	for distance in 3:
		var left := col - distance
		if left >= 0 and not (_dead_by_col[left] as Array).is_empty():
			return left
		var right := col + distance
		if right <= 2 and not (_dead_by_col[right] as Array).is_empty():
			return right
	return -1


func _begin_refill_motion() -> void:
	_refill_pos.resize(GRID_SIZE)
	for slot in GRID_SIZE:
		# Formation swaps and dodges are both resolved by the refill movement.
		_micro_offsets_x[slot] = 0.0
		var alien = _grid[slot]
		if alien == null:
			_refill_pos[slot] = _slot_local_center(slot)
			continue
		var node := alien as Node2D
		if not _is_alien_alive(alien):
			if alien.has_method(&"revive"):
				alien.call(&"revive")
			# Uniform gap above the target keeps a column's arrivals evenly spaced.
			node.position = _slot_local_center(slot) - Vector2(0.0, refill_entry_height)
		_refill_pos[slot] = node.position
	_apply_selection_visual()
	queue_redraw()


func _update_refill(delta: float) -> void:
	if _refill_pos.size() != GRID_SIZE:
		_finish_refill()
		return
	var settled := true
	var step := refill_speed * delta
	for slot in GRID_SIZE:
		var alien = _grid[slot]
		if alien == null or not is_instance_valid(alien):
			continue
		var target := _slot_local_center(slot)
		var pos: Vector2 = _refill_pos[slot]
		if not pos.is_equal_approx(target):
			pos = pos.move_toward(target, step)
			_refill_pos[slot] = pos
			if not pos.is_equal_approx(target):
				settled = false
		var rendered := Vector2(roundf(pos.x), roundf(pos.y))
		if slot == _selected_slot and (alien as Node2D).position != rendered:
			queue_redraw()
		(alien as Node2D).position = rendered
	if settled:
		_finish_refill()


func _finish_refill() -> void:
	for slot in GRID_SIZE:
		var alien = _grid[slot]
		if alien != null and is_instance_valid(alien):
			(alien as Node2D).position = _slot_local_center(slot)
	_refill_pos.clear()
	_phase = Phase.LOCKED
	_apply_selection_visual()
	queue_redraw()
	refill_finished.emit()
