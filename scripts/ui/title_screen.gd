extends Node2D

const CURSOR_POSITIONS := [
	Vector2(26, 182),
	Vector2(26, 204),
	Vector2(26, 227),
]
const MODULATE_SELECTED := Color(0.9765, 1.3007, 2.0256, 1.0)
const MODULATE_UNSELECTED := Color(0.65, 0.65, 0.65, 1)
const CONFIRM_POST_DELAY_SEC := 0.10
const FLASH_COUNT := 8
const FLASH_INTERVAL_SEC := 0.055
const MENU_SFX_VOLUME_DB := -8.0
const LEVEL_1_1_SCENE := "res://scenes/levels/Level_1_1.tscn"
const TITLE_MUSIC_PATH := "res://assets/audio/music/title/bgm_title_01.ogg"
const SFX_CONFIRM_STREAM := preload("res://assets/audio/sfx/ui/sfx_ui_confirm_01.wav")
const SFX_START_GAME_STREAM := preload("res://assets/audio/sfx/ui/sfx_ui_start_game_01.wav")
const VOLUME_STEP := 0.1
## Pixels left of the selected Options label's left edge (cursor center).
const OPTIONS_CURSOR_X_GAP := 16.0

@onready var _menu: Node2D = $Menu
@onready var _menu_cursor: Sprite2D = $Menu/Cursor
@onready var _menu_items: Array[Sprite2D] = [
	$Menu/Start,
	$Menu/Options,
	$Menu/Exit,
]
@onready var _sfx_confirm: AudioStreamPlayer = $SFX_Confirm
@onready var _sfx_move: AudioStreamPlayer = $SFX_Move
@onready var _options_overlay: CanvasLayer = $OptionsOverlay
@onready var _options_cursor: Sprite2D = $OptionsOverlay/OptionsCursor
@onready var _options_master_label: Label = $OptionsOverlay/CenterContainer/Panel/MasterLabel
@onready var _options_music_label: Label = $OptionsOverlay/CenterContainer/Panel/MusicLabel
@onready var _options_back_label: Label = $OptionsOverlay/CenterContainer/Panel/BackLabel

var _selected_index: int = 0
var _confirm_busy: bool = false
var _in_options: bool = false
var _options_selection: int = 0


func _ready() -> void:
	SceneTransition.transition_failed.connect(func() -> void: _confirm_busy = false)
	_sfx_confirm.stream = SFX_CONFIRM_STREAM
	_sfx_confirm.volume_db = MENU_SFX_VOLUME_DB
	_sfx_confirm.bus = &"Master"
	_options_overlay.visible = false
	MusicManager.play_music(TITLE_MUSIC_PATH)
	_refresh_menu()
	_refresh_options_labels()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_busy or SceneTransition.busy:
		return
	if _in_options:
		_handle_options_input(event)
		return
	if event.is_action_pressed(&"ui_down"):
		_selected_index = (_selected_index + 1) % _menu_items.size()
		_sfx_move.stop()
		_sfx_move.play()
		_refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		_selected_index = (_selected_index - 1 + _menu_items.size()) % _menu_items.size()
		_sfx_move.stop()
		_sfx_move.play()
		_refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_run_confirm_action(_selected_index)


func _handle_options_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_options_selection = (_options_selection + 1) % 3
		_sfx_move.stop()
		_sfx_move.play()
		_refresh_options_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		_options_selection = (_options_selection - 1 + 3) % 3
		_sfx_move.stop()
		_sfx_move.play()
		_refresh_options_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		_adjust_selected_volume(-VOLUME_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_adjust_selected_volume(VOLUME_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if _options_selection == 2:
			_sfx_confirm.stop()
			_sfx_confirm.play()
			_close_options()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_options()


func _adjust_selected_volume(delta: float) -> void:
	if _options_selection == 0:
		MusicManager.set_master_volume(MusicManager.master_volume + delta)
		_sfx_move.stop()
		_sfx_move.play()
	elif _options_selection == 1:
		MusicManager.set_music_volume(MusicManager.music_volume + delta)
		_sfx_move.stop()
		_sfx_move.play()
	_refresh_options_labels()


func _run_confirm_action(index: int) -> void:
	_confirm_busy = true
	if _sfx_confirm:
		_sfx_confirm.stop()
		_sfx_confirm.stream = SFX_START_GAME_STREAM if index == 0 else SFX_CONFIRM_STREAM
		_sfx_confirm.volume_db = MENU_SFX_VOLUME_DB
		_sfx_confirm.play()
	match index:
		0:
			# TEMP: Start goes directly to Level_1_1 until a New Game / Load Game menu exists.
			# Flash immediately, concurrently with the confirm sound.
			# The scene change ends the start sound; no explicit stop needed.
			await _flash_start()
			MusicManager.stop_music()
			if not SceneTransition.change_scene(LEVEL_1_1_SCENE, SceneTransition.Effect.STAR, false, SceneTransition.SessionAction.NEW_GAME):
				_confirm_busy = false
		1:
			if _sfx_confirm and _sfx_confirm.playing:
				await _sfx_confirm.finished
			await get_tree().create_timer(CONFIRM_POST_DELAY_SEC).timeout
			_open_options()
			_confirm_busy = false
		2:
			if _sfx_confirm and _sfx_confirm.playing:
				await _sfx_confirm.finished
			await get_tree().create_timer(CONFIRM_POST_DELAY_SEC).timeout
			get_tree().quit()


func _open_options() -> void:
	_in_options = true
	_options_selection = 0
	_menu.visible = false
	_options_overlay.visible = true
	_refresh_options_labels()


func _close_options() -> void:
	_in_options = false
	_options_overlay.visible = false
	_menu.visible = true
	_refresh_menu()


func _flash_start() -> void:
	var start_item: Sprite2D = _menu_items[0]
	for i in FLASH_COUNT:
		start_item.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(FLASH_INTERVAL_SEC).timeout
		start_item.modulate = MODULATE_SELECTED
		await get_tree().create_timer(FLASH_INTERVAL_SEC).timeout
	_refresh_menu()


func _refresh_menu() -> void:
	_menu_cursor.position = CURSOR_POSITIONS[_selected_index]
	for i in _menu_items.size():
		_menu_items[i].modulate = MODULATE_SELECTED if i == _selected_index else MODULATE_UNSELECTED


func _refresh_options_labels() -> void:
	var master_pct: int = int(round(MusicManager.master_volume * 100.0))
	var music_pct: int = int(round(MusicManager.music_volume * 100.0))
	_options_master_label.text = "MASTER  %d%%" % master_pct
	_options_music_label.text = "MUSIC   %d%%" % music_pct
	_options_back_label.text = "BACK"

	var option_labels: Array[Label] = [
		_options_master_label,
		_options_music_label,
		_options_back_label,
	]
	for i in option_labels.size():
		option_labels[i].modulate = (
			MODULATE_SELECTED if i == _options_selection else MODULATE_UNSELECTED
		)

	# Wait for Control layout so cursor aligns to the selected row.
	call_deferred("_place_options_cursor")


func _place_options_cursor() -> void:
	if not is_instance_valid(_options_cursor):
		return
	var option_labels: Array[Label] = [
		_options_master_label,
		_options_music_label,
		_options_back_label,
	]
	var label: Label = option_labels[_options_selection]
	var cursor_x: float = label.global_position.x - OPTIONS_CURSOR_X_GAP
	var cursor_y: float = label.global_position.y + label.size.y * 0.5
	_options_cursor.global_position = Vector2(round(cursor_x), round(cursor_y))
