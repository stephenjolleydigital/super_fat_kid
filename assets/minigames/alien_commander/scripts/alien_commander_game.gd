extends Node2D

signal enemy_destroyed
signal alien_destroyed(alien: Area2D)
signal all_aliens_destroyed
signal wave_cleared
signal game_over
## Host sets arcade_mode before add_child. A finished run emits this once and does not reload.
signal arcade_finished(result: Dictionary)

# DEV_COMPLETE is temporary scaffolding: it stands in for the eventual victory
# sequence while only some of the ten ships exist.
enum State { WAVE_INTRO, PREP, ACTIVE, WAVE_CLEAR, REFILL, UPGRADE, GAME_OVER, DEV_COMPLETE }

# Wave N uses WAVE_SHIPS[N - 1]. Append a scene to make the next wave playable;
# an unavailable wave is never substituted with an implemented ship.
const WAVE_SHIPS: Array[PackedScene] = [
	preload("res://assets/minigames/alien_commander/scenes/Enemy_Ship_01.tscn"),
	preload("res://assets/minigames/alien_commander/scenes/Enemy_Ship_02.tscn"),
	preload("res://assets/minigames/alien_commander/scenes/Enemy_Ship_03.tscn"),
	preload("res://assets/minigames/alien_commander/scenes/Enemy_Ship_04.tscn"),
]
const SHIP_NODE_NAME := "EnemyShip"
# Keeps the spawned ship at the tree position the authored instance used to hold.
const SHIP_TREE_INDEX := 3
const SHIP_FALLBACK_HALF_HEIGHT := 32.0
const COUNTDOWN_STEPS := 3

@export var wave_intro_time := 1.5
@export var get_ready_time := 1.5
@export var countdown_step_time := 1.0
@export var command_text_time := 0.6
@export var wave_clear_text_time := 1.5
@export var upgrade_stub_delay := 1.0
@export var dev_complete_time := 2.0
# Stands in for the length of the not-yet-authored sad sting.
@export var game_over_delay := 2.5

## One paid run inside a host SubViewport. Standalone stays false and still reloads on game over.
var arcade_mode := false:
	set(value):
		arcade_mode = value
		if value and is_inside_tree():
			process_mode = Node.PROCESS_MODE_ALWAYS

var _state: State = State.WAVE_INTRO
var _wave := 1
var _waves_cleared := 0
var _terminal := ""
var _arcade_emitted := false
var _finish_confirm_was := false
var _state_time := 0.0
var _text_hold := 0.0
var _last_cue := ""
var _restarting := false
var _enemy_ship: Area2D = null
var _ship_home := Vector2.ZERO
var _ship_entry_start_y := 0.0

@onready var _formation: Node2D = $AlienFormation
@onready var _status_label: Label = $UI/StatusLabel
@onready var _fire_order_meter: Control = $UI/FireOrderMeter
@onready var _move_meter: Control = $UI/MoveMeter
@onready var _ship_home_marker: Marker2D = $Bounds/ShipHome


func _ready() -> void:
	if arcade_mode:
		process_mode = Node.PROCESS_MODE_ALWAYS
	_status_label.visible = false
	_ship_home = _ship_home_marker.position
	_connect_aliens()
	_connect_meters()
	_connect_formation()
	_start_wave(1)


func is_playing() -> bool:
	return _state == State.ACTIVE


func get_playfield_global_origin() -> Vector2:
	return global_position


func _connect_aliens() -> void:
	# Aliens persist across waves now, so connecting once here is enough.
	for alien in $AlienFormation/Aliens.get_children():
		if alien is Area2D and alien.has_signal(&"destroyed"):
			alien.connect(&"destroyed", Callable(self, "_on_alien_destroyed").bind(alien))


func _connect_meters() -> void:
	if _formation == null:
		return
	if _fire_order_meter and _formation.has_signal(&"fire_order_changed"):
		_formation.connect(&"fire_order_changed", Callable(_fire_order_meter, "set_meter"))
	if _move_meter and _formation.has_signal(&"move_meter_changed"):
		_formation.connect(&"move_meter_changed", Callable(_move_meter, "set_meter"))
	# Formation emits before this connect; sync once so gutters aren't blank on frame 0.
	if _fire_order_meter:
		_fire_order_meter.set_meter(0.0, false)
	if _move_meter:
		_move_meter.set_meter(0.0, false)


func _connect_formation() -> void:
	if _formation and _formation.has_signal(&"refill_finished"):
		_formation.connect(&"refill_finished", Callable(self, "_on_refill_finished"))


func _process(delta: float) -> void:
	_poll_finish_confirm()
	if _arcade_emitted:
		return
	_state_time += delta
	_update_text_hold(delta)
	match _state:
		State.WAVE_INTRO:
			_update_wave_intro()
		State.PREP:
			_update_prep()
		State.WAVE_CLEAR:
			_update_wave_clear()
		State.UPGRADE:
			_update_upgrade()
		State.DEV_COMPLETE:
			_update_dev_complete()
		State.GAME_OVER:
			_update_game_over()


# --- Wave flow -------------------------------------------------------------


func _start_wave(wave: int) -> void:
	if not _has_ship_for_wave(wave):
		push_error("Alien Commander: no ship scene implemented for wave %d" % wave)
		_enter_dev_complete()
		return
	_wave = wave
	_formation.set_phase_locked()
	_formation.reset_meters()
	_spawn_ship_for_wave(wave)
	_on_wave_start()
	_set_state(State.WAVE_INTRO)
	_show_text("WAVE %d" % wave)


func _update_wave_intro() -> void:
	if _state_time < wave_intro_time:
		return
	_set_state(State.PREP)
	_last_cue = ""
	_formation.set_phase_prep()
	_formation.reset_meters()


func _update_prep() -> void:
	var total := _prep_total()
	# Both meters ride one ramp: empty at GET READY, exactly full at COMMAND.
	_formation.set_prep_meters(_state_time / total)
	_update_prep_cue()
	if _state_time >= get_ready_time:
		var entrance_time := COUNTDOWN_STEPS * countdown_step_time
		var ratio := clampf((_state_time - get_ready_time) / entrance_time, 0.0, 1.0)
		_position_ship_entrance(ratio)
	if _state_time >= total:
		_enter_active()


func _update_prep_cue() -> void:
	var cue := "GET READY"
	if _state_time >= get_ready_time:
		var step := int((_state_time - get_ready_time) / countdown_step_time)
		cue = str(COUNTDOWN_STEPS - clampi(step, 0, COUNTDOWN_STEPS - 1))
	if cue != _last_cue:
		_last_cue = cue
		_show_text(cue)


func _prep_total() -> float:
	return maxf(0.001, get_ready_time + COUNTDOWN_STEPS * countdown_step_time)


func _enter_active() -> void:
	if _enemy_ship and is_instance_valid(_enemy_ship):
		_enemy_ship.position = _ship_home
	_formation.set_prep_meters(1.0)
	_formation.set_phase_active()
	_set_state(State.ACTIVE)
	_last_cue = ""
	# Combat is already live; the banner just lingers a beat.
	_show_text("COMMAND!", command_text_time)


func _on_enemy_destroyed() -> void:
	if _state != State.ACTIVE:
		return
	_waves_cleared += 1
	enemy_destroyed.emit()
	wave_cleared.emit()
	_formation.set_phase_locked()
	_clear_bullets()
	_on_wave_cleared()
	_set_state(State.WAVE_CLEAR)
	_show_text("WAVE %d CLEARED" % _wave)


func _update_wave_clear() -> void:
	if _state_time < wave_clear_text_time:
		return
	_clear_text()
	_set_state(State.REFILL)
	_formation.begin_refill()


func _on_refill_finished() -> void:
	if _state != State.REFILL:
		return
	_set_state(State.UPGRADE)
	_show_text("UPGRADE")


func _update_upgrade() -> void:
	if _state_time >= upgrade_stub_delay:
		_resolve_upgrade_choice()


func _resolve_upgrade_choice() -> void:
	# TODO: present three upgrade options and wait for the player's pick.
	# Until then the stub simply advances the run.
	_clear_text()
	var next_wave := _wave + 1
	if not _has_ship_for_wave(next_wave):
		_enter_dev_complete()
		return
	_start_wave(next_wave)


func _enter_dev_complete() -> void:
	# Not a win: shipped waves ran out. The real ending is still unwritten.
	_terminal = "dev_complete"
	_formation.set_phase_locked()
	_despawn_ship()
	_set_state(State.DEV_COMPLETE)
	_show_text("WAVES COMPLETE")


func _update_dev_complete() -> void:
	if _state_time >= dev_complete_time:
		_restart_run()


# --- Failure ---------------------------------------------------------------


func _on_alien_destroyed(alien: Area2D) -> void:
	if _state != State.ACTIVE:
		return
	alien_destroyed.emit(alien)
	call_deferred(&"_check_all_aliens_destroyed")


func _check_all_aliens_destroyed() -> void:
	if _state != State.ACTIVE:
		return
	if not _all_aliens_gone():
		return
	all_aliens_destroyed.emit()
	_terminal = "dead"
	game_over.emit()
	_formation.set_phase_locked()
	_clear_bullets()
	_on_game_over_started()
	_set_state(State.GAME_OVER)
	_show_text("GAME OVER")


func _clear_bullets() -> void:
	# Bullets fly and damage regardless of state. Left alone, one landing during
	# the refill would pull an alien out of the grid mid-animation.
	for root in [$EnemyBullets, $AlienBullets]:
		for bullet in (root as Node).get_children():
			bullet.queue_free()


func _all_aliens_gone() -> bool:
	# Dead aliens stay in the tree now, so liveness has to come from the formation.
	return (_formation.get_living_aliens() as Array).is_empty()


func _update_game_over() -> void:
	if _state_time >= game_over_delay:
		_restart_run()


func _restart_run() -> void:
	# Full reload is the cheapest guaranteed reset: wave 1, all aliens, no upgrades.
	# Arcade mode has already been paid for, so the same run must not start again.
	if _restarting:
		return
	if arcade_mode:
		_finish_arcade(_terminal if _terminal != "" else "dead")
		return
	_restarting = true
	get_tree().call_deferred(&"reload_current_scene")


## Snapshot for the host. outcome is the caller's label ("exit" on game_pause).
## terminal is set only after a real ending has started: "dead" or "dev_complete".
## There is no score in this game.
func get_arcade_result(outcome: String) -> Dictionary:
	var result := {
		"game": "alien_commander",
		"outcome": outcome,
		"wave": _wave,
		"waves_cleared": _waves_cleared,
	}
	if _terminal != "":
		result["terminal"] = _terminal
	return result


func _finish_arcade(outcome: String) -> void:
	if _arcade_emitted:
		return
	_arcade_emitted = true
	_restarting = true
	arcade_finished.emit(get_arcade_result(outcome))
	if is_instance_valid(self):
		process_mode = Node.PROCESS_MODE_DISABLED


func _poll_finish_confirm() -> void:
	if _restarting or _arcade_emitted:
		return
	if _state != State.GAME_OVER and _state != State.DEV_COMPLETE:
		return
	var down := Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
	for device in Input.get_connected_joypads():
		down = down or Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	var pressed := down and not _finish_confirm_was
	_finish_confirm_was = down
	if pressed:
		_restart_run()


# --- Enemy ship ------------------------------------------------------------


func _has_ship_for_wave(wave: int) -> bool:
	return wave >= 1 and wave <= WAVE_SHIPS.size()


func _ship_scene_for_wave(wave: int) -> PackedScene:
	# Callers must check _has_ship_for_wave() first; no clamping, no fallback ship.
	return WAVE_SHIPS[wave - 1]


func _spawn_ship_for_wave(wave: int) -> void:
	_despawn_ship()
	var ship := _ship_scene_for_wave(wave).instantiate() as Area2D
	if ship == null:
		push_error("Alien Commander: wave %d ship scene is not an Area2D" % wave)
		return
	ship.name = SHIP_NODE_NAME
	add_child(ship)
	move_child(ship, mini(SHIP_TREE_INDEX, get_child_count() - 1))
	_enemy_ship = ship
	_ship_entry_start_y = _ship_offscreen_y(_ship_half_height(ship))
	ship.position = Vector2(_ship_home.x, _ship_entry_start_y)
	if ship.has_signal(&"destroyed"):
		ship.connect(&"destroyed", Callable(self, "_on_enemy_destroyed"))


func _despawn_ship() -> void:
	if _enemy_ship and is_instance_valid(_enemy_ship):
		_enemy_ship.queue_free()
	_enemy_ship = null


func _ship_half_height(ship: Node) -> float:
	# Derived per ship so differently sized hulls all start fully offscreen.
	var sprite := ship.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		return ceilf(sprite.texture.get_height() * 0.5)
	return SHIP_FALLBACK_HALF_HEIGHT


func _ship_offscreen_y(half_height: float) -> float:
	# The window is taller than the 224px playfield, so clearing the playfield
	# alone would leave the ship visible below it. Use whichever is lower.
	var below := ACPlayfield.RECT.size.y
	var viewport := get_viewport_rect().size.y
	return maxf(below, viewport) + half_height


func _position_ship_entrance(ratio: float) -> void:
	if _enemy_ship == null or not is_instance_valid(_enemy_ship):
		return
	var y := lerpf(_ship_entry_start_y, _ship_home.y, ratio)
	_enemy_ship.position = Vector2(_ship_home.x, roundf(y))


# --- Text ------------------------------------------------------------------


func _show_text(text: String, hold: float = 0.0) -> void:
	_status_label.text = text
	_status_label.visible = true
	_text_hold = hold


func _clear_text() -> void:
	_status_label.visible = false
	_text_hold = 0.0


func _update_text_hold(delta: float) -> void:
	if _text_hold <= 0.0:
		return
	_text_hold -= delta
	if _text_hold <= 0.0:
		_status_label.visible = false


# --- Music hooks (audio not authored yet) ----------------------------------


func _on_wave_start() -> void:
	# TODO: wave-start jingle.
	pass


func _on_wave_cleared() -> void:
	# TODO: happy wave-cleared sting.
	pass


func _on_game_over_started() -> void:
	# TODO: sad game-over sting; game_over_delay later waits on its length.
	pass


# --- Misc ------------------------------------------------------------------


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.GAME_OVER and _state != State.DEV_COMPLETE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_restart_run()
