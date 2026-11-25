extends CanvasLayer

const TOAST_DOUBLE_JUMP_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_double_jump_frames.tres")
const TOAST_CROUCH_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_crouch_frames.tres")
const TOAST_MAX_GAS_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_max_gas_frames.tres")
const TOAST_MAX_HP_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_max_hp_frames.tres")
const TOAST_RUN_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_run_frames.tres")
const TOAST_BLASTER_FRAMES := preload("res://assets/sprites/ui/toasts/ui_toast_upgrade_blaster_frames.tres")

const TITLE_SCENE := "res://scenes/ui/TitleScreen.tscn"
const PAUSE_OPTION_COUNT := 3
const LEVEL_CLEAR_DELAY: float = 0.6
const LEVEL_CLEAR_DISPLAY_DURATION: float = 1.85

@onready var upgrade_toast: AnimatedSprite2D = $UpgradeToast
@onready var player_hud: Control = $PlayerHUD
@onready var money_label: Label = $PlayerHUD/MoneyLabel
@onready var level_complete_overlay: Control = $LevelCompleteOverlay
@onready var level_complete_banner: Control = $LevelCompleteOverlay/CenterContainer/BannerSlot/Banner
@onready var level_complete_label: Label = $LevelCompleteOverlay/CenterContainer/BannerSlot/Banner/LevelCompleteLabel
@onready var boss_health_container: Control = $BossHealthContainer
@onready var boss_name_label: Label = $BossHealthContainer/BossNameLabel
@onready var boss_bar_fill: ColorRect = $BossHealthContainer/BossBarFrame/BossBarFill
@onready var pause_menu_overlay: Control = $PauseMenuOverlay
@onready var pause_resume_label: Label = $PauseMenuOverlay/CenterContainer/MenuPanel/ResumeLabel
@onready var pause_main_menu_label: Label = $PauseMenuOverlay/CenterContainer/MenuPanel/MainMenuLabel
@onready var pause_quit_label: Label = $PauseMenuOverlay/CenterContainer/MenuPanel/QuitLabel
@onready var sfx_pause_open: AudioStreamPlayer = $SfxPauseOpen
@onready var sfx_pause_close: AudioStreamPlayer = $SfxPauseClose
@onready var sfx_ui_move: AudioStreamPlayer = $SfxUiMove
@onready var sfx_ui_confirm: AudioStreamPlayer = $SfxUiConfirm
@onready var sfx_level_complete_jingle: AudioStreamPlayer = $SfxLevelCompleteJingle
@onready var sfx_extra_life_arrive: AudioStreamPlayer = $SfxExtraLifeArrive

var _kick_toast_frames: SpriteFrames
var _current_toast_animation: String = "kick_upgrade"
var _boss_hp_max: int = 1
var _boss_fill_max_width: int = 0


var _level_complete_sequence_running: bool = false
var _level_complete_tween: Tween
var _completion_cancelled_by_death: bool = false

# --- Pause menu (get_tree().paused; this CanvasLayer uses PROCESS_MODE_ALWAYS) ---
var _pause_menu_open: bool = false
var _pause_selection: int = 0
var _unpause_after_release_action: StringName = &""
var _confirm_in_progress: bool = false

func _enter_tree() -> void:
	GameState.continue_destination = get_parent().scene_file_path

func _ready() -> void:
	player_hud.bind_player(get_parent().get_node_or_null("Player"))
	SceneTransition.transition_failed.connect(_on_transition_failed)
	_clear_pending_deferred_unpause()
	upgrade_toast.visible = false
	_kick_toast_frames = upgrade_toast.sprite_frames
	boss_health_container.visible = false
	_boss_fill_max_width = int(round(boss_bar_fill.size.x))
	if pause_menu_overlay:
		pause_menu_overlay.visible = false
	if not SceneTransition.busy:
		get_tree().paused = false
	GameState.quarters_changed.connect(update_money_label)
	update_money_label()
	_setup_lives_ui()
	call_deferred("_check_continue_configuration")

func _unhandled_input(event: InputEvent) -> void:
	if SceneTransition.busy:
		return
	if _death_menu.visible:
		_handle_death_input(event)
		return
	if _player_is_dead():
		return
	if event.is_action_pressed(&"game_pause"):
		if _level_complete_sequence_running:
			return
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if not _pause_menu_open:
		return
	if _confirm_in_progress:
		# Lock input while a confirm action is resolving so mashing can't double-trigger.
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_down"):
		_pause_selection = (_pause_selection + 1) % PAUSE_OPTION_COUNT
		if sfx_ui_move:
			sfx_ui_move.play()
		_refresh_pause_menu_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		_pause_selection = (_pause_selection - 1 + PAUSE_OPTION_COUNT) % PAUSE_OPTION_COUNT
		if sfx_ui_move:
			sfx_ui_move.play()
		_refresh_pause_menu_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_close_pause_menu(&"ui_cancel")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm_pause_selection()

func _toggle_pause_menu() -> void:
	if _pause_menu_open:
		_close_pause_menu(&"game_pause")
	else:
		_open_pause_menu()

func _confirm_pause_selection() -> void:
	if _confirm_in_progress:
		return
	match _pause_selection:
		0:
			# Resume
			if sfx_ui_confirm:
				sfx_ui_confirm.play()
			_close_pause_menu(&"ui_accept")
		1:
			# Main Menu
			_confirm_in_progress = true
			if sfx_ui_confirm:
				sfx_ui_confirm.play()
			_clear_pending_deferred_unpause()
			if not SceneTransition.change_scene(TITLE_SCENE, SceneTransition.Effect.FADE):
				_confirm_in_progress = false
		2:
			# Quit — wait for confirm SFX so it is not cut off by quit()
			_confirm_in_progress = true
			if sfx_ui_confirm:
				sfx_ui_confirm.play()
				if sfx_ui_confirm.playing:
					await sfx_ui_confirm.finished
			_clear_pending_deferred_unpause()
			get_tree().paused = false
			get_tree().quit()

func _process(_delta: float) -> void:
	if SceneTransition.busy:
		return
	if _unpause_after_release_action.is_empty():
		return
	if not Input.is_action_pressed(_unpause_after_release_action):
		_unpause_after_release_action = &""
		get_tree().paused = false

func _open_pause_menu() -> void:
	_clear_pending_deferred_unpause()
	_confirm_in_progress = false
	_pause_menu_open = true
	_pause_selection = 0
	if pause_menu_overlay:
		pause_menu_overlay.visible = true
	_refresh_pause_menu_labels()
	get_tree().paused = true
	if sfx_pause_open:
		sfx_pause_open.play()

func _close_pause_menu(unpause_after_release: StringName = &"") -> void:
	if sfx_pause_close:
		sfx_pause_close.play()
	_pause_menu_open = false
	if pause_menu_overlay:
		pause_menu_overlay.visible = false
	if unpause_after_release.is_empty():
		get_tree().paused = false
	else:
		_unpause_after_release_action = unpause_after_release
		get_tree().paused = true

func _clear_pending_deferred_unpause() -> void:
	_unpause_after_release_action = &""

func _refresh_pause_menu_labels() -> void:
	if not pause_resume_label or not pause_main_menu_label or not pause_quit_label:
		return
	pause_resume_label.text = "%s RESUME" % (">" if _pause_selection == 0 else " ")
	pause_main_menu_label.text = "%s MAIN MENU" % (">" if _pause_selection == 1 else " ")
	pause_quit_label.text = "%s CLOSE GAME" % (">" if _pause_selection == 2 else " ")

func play_upgrade_toast(anim_name: String = "kick_upgrade") -> void:
	if not upgrade_toast:
		return

	# Clear all previous toast callbacks so only this toast's "play twice then hide" runs.
	# (If Belt and Shorts overlap in main.tscn, both can fire; separating those pickups fixes the root cause.)
	if upgrade_toast.animation_finished.is_connected(_on_upgrade_toast_finished):
		upgrade_toast.animation_finished.disconnect(_on_upgrade_toast_finished)
	if upgrade_toast.animation_finished.is_connected(_on_upgrade_toast_finished_second):
		upgrade_toast.animation_finished.disconnect(_on_upgrade_toast_finished_second)

	_current_toast_animation = anim_name
	if anim_name == "double_jump_upgrade":
		upgrade_toast.sprite_frames = TOAST_DOUBLE_JUMP_FRAMES
	elif anim_name == "crouch_upgrade":
		upgrade_toast.sprite_frames = TOAST_CROUCH_FRAMES
	elif anim_name == "max_gas_upgrade":
		upgrade_toast.sprite_frames = TOAST_MAX_GAS_FRAMES
	elif anim_name == "max_hp_upgrade":
		upgrade_toast.sprite_frames = TOAST_MAX_HP_FRAMES
	elif anim_name == "run_upgrade":
		upgrade_toast.sprite_frames = TOAST_RUN_FRAMES
	elif anim_name == "blaster_upgrade":
		upgrade_toast.sprite_frames = TOAST_BLASTER_FRAMES
	else:
		upgrade_toast.sprite_frames = _kick_toast_frames

	upgrade_toast.visible = true
	upgrade_toast.frame = 0
	upgrade_toast.play(_current_toast_animation)

	# Play it twice total
	upgrade_toast.animation_finished.connect(_on_upgrade_toast_finished, CONNECT_ONE_SHOT)

func _on_upgrade_toast_finished() -> void:
	# First finish -> play again
	upgrade_toast.frame = 0
	upgrade_toast.play(_current_toast_animation)

	# Second finish -> hide
	if upgrade_toast.animation_finished.is_connected(_on_upgrade_toast_finished_second):
		upgrade_toast.animation_finished.disconnect(_on_upgrade_toast_finished_second)
	upgrade_toast.animation_finished.connect(_on_upgrade_toast_finished_second, CONNECT_ONE_SHOT)

func _on_upgrade_toast_finished_second() -> void:
	upgrade_toast.stop()
	upgrade_toast.visible = false

func add_quarters(amount: int) -> void:
	GameState.add_quarters(amount)

func update_money_label() -> void:
	var cents: int = GameState.get_quarters() * 25
	var dollars: int = int(cents / 100.0)
	var remainder: int = cents % 100
	money_label.text = "$%d.%02d" % [dollars, remainder]


func show_world_complete(complete_text: String, jingle: AudioStream = null) -> void:
	_level_complete_sequence_running = true
	level_complete_label.text = complete_text
	level_complete_label.add_theme_font_size_override("font_size", 20)
	level_complete_label.offset_left = 12
	level_complete_label.offset_right = 340
	level_complete_overlay.show()
	level_complete_banner.celebrate(true)
	if jingle:
		sfx_level_complete_jingle.stream = jingle
	sfx_level_complete_jingle.play()

func finish_world_complete() -> void:
	level_complete_overlay.hide()
	_level_complete_sequence_running = false

func show_level_complete(next_scene_path: String = "", complete_text: String = "") -> void:
	if _level_complete_sequence_running or _completion_cancelled_by_death or SceneTransition.busy:
		return
	if not level_complete_overlay or not level_complete_banner or not level_complete_label:
		return
	_level_complete_sequence_running = true
	level_complete_label.text = complete_text if not complete_text.is_empty() else "LEVEL CLEAR!"
	level_complete_overlay.visible = false
	_level_complete_tween = create_tween()
	var tween := _level_complete_tween
	tween.tween_interval(LEVEL_CLEAR_DELAY)
	tween.tween_callback(func() -> void:
		level_complete_overlay.visible = true
		level_complete_banner.celebrate()
		if sfx_level_complete_jingle:
			sfx_level_complete_jingle.play()
	)
	tween.tween_interval(LEVEL_CLEAR_DISPLAY_DURATION)
	tween.tween_callback(func() -> void:
		if next_scene_path.is_empty():
			# Development case: stay in the level with the pause menu usable
			# instead of restarting it, so the missing setup is obvious.
			var level := get_tree().current_scene
			push_warning(
				"Level complete with no next_level_path configured: %s"
				% (level.scene_file_path if level else "unknown level")
			)
			level_complete_overlay.visible = false
			_level_complete_sequence_running = false
		else:
			if not SceneTransition.change_scene(next_scene_path):
				level_complete_overlay.hide()
				_level_complete_sequence_running = false
	)


func _on_transition_failed() -> void:
	if _player_is_dead():
		_show_death_menu(true)
	_confirm_in_progress = false
	level_complete_overlay.hide()
	_level_complete_sequence_running = false


func cancel_level_complete() -> void:
	_completion_cancelled_by_death = true
	if _level_complete_tween and _level_complete_tween.is_valid():
		_level_complete_tween.kill()
	level_complete_overlay.hide()
	_level_complete_sequence_running = false
	if sfx_level_complete_jingle:
		sfx_level_complete_jingle.stop()


func show_boss_health(label_text: String, current_hp: int, max_hp: int) -> void:
	if not boss_health_container or not boss_name_label or not boss_bar_fill:
		return
	_boss_hp_max = max(max_hp, 1)
	boss_name_label.text = label_text
	boss_health_container.visible = true
	update_boss_health(current_hp)


func update_boss_health(current_hp: int) -> void:
	if not boss_bar_fill:
		return
	var clamped_hp := clampi(current_hp, 0, _boss_hp_max)
	var ratio := float(clamped_hp) / float(_boss_hp_max)
	var fill_width := int(round(ratio * float(_boss_fill_max_width)))
	boss_bar_fill.custom_minimum_size.x = fill_width
	boss_bar_fill.size.x = fill_width


func hide_boss_health() -> void:
	if not boss_health_container:
		return
	boss_health_container.visible = false


const LIFE_TEXTURE := preload("res://assets/sprites/pickups/pickup_extra_life.png")
var _life_icon: TextureRect
var _life_x_label: Label
var _life_label: Label
var _death_menu: Control
var _death_title: Label
var _death_options: Label
var _death_selection: int = 0
var _death_confirming: bool = false
var _retry_path: String = ""
var _retry_action: int = SceneTransition.SessionAction.KEEP
var _retry_effect: int = SceneTransition.Effect.CIRCLE
var _retry_is_restart: bool = true
var _life_flash: Tween

func _check_continue_configuration() -> void:
	if not get_parent().has_node("SessionEntry"):
		GameState.continue_destination = get_parent().scene_file_path
		push_warning("No SessionEntry: Continue restarts " + GameState.continue_destination)

func _player_is_dead() -> bool:
	var player := get_parent().get_node_or_null("Player")
	return player != null and player.state == player.State.DEAD

func _make_life_label(parent: Node, at: Vector2, size_px: int = 8) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_override("font", money_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	parent.add_child(label)
	return label

func _setup_lives_ui() -> void:
	_life_icon = player_hud.life_icon
	_life_x_label = $PlayerHUD/Lives/Times
	_life_label = player_hud.life_label
	GameState.lives_changed.connect(_update_lives)
	_update_lives(GameState.get_lives())
	_death_menu = Control.new()
	_death_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_death_menu)
	var backing := ColorRect.new()
	backing.color = Color(0.04, 0.04, 0.06, 0.94)
	backing.position = Vector2(100, 91)
	backing.size = Vector2(280, 88)
	_death_menu.add_child(backing)
	_death_title = _make_life_label(_death_menu, Vector2(112, 103), 16)
	_death_options = _make_life_label(_death_menu, Vector2(112, 133))
	_death_menu.hide()

func _update_lives(value: int) -> void:
	_life_label.text = "%d" % value

const LIFE_FLIGHT_FRAMES := [4, 5, 6, 6, 5, 4, 0]
const LIFE_REFORM_SPEED := 1.8

func fly_life_to_hud(screen_position: Vector2) -> void:
	var flying := Sprite2D.new()
	flying.texture = LIFE_TEXTURE
	flying.hframes = 7
	flying.frame = LIFE_FLIGHT_FRAMES[0]
	flying.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flying.position = screen_position.round()
	add_child(flying)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(func(t: float) -> void:
		# One clock keeps the shrink/reform frames and travel in sync through pauses.
		var frame_progress := t * LIFE_FLIGHT_FRAMES.size()
		# Keep the shrink timing; reform faster, then hold frame zero until arrival.
		if frame_progress > 4.0:
			frame_progress = 4.0 + (frame_progress - 4.0) * LIFE_REFORM_SPEED
		var frame_index := mini(int(frame_progress), LIFE_FLIGHT_FRAMES.size() - 1)
		flying.frame = LIFE_FLIGHT_FRAMES[frame_index]
		var travel := smoothstep(0.0, 1.0, t)
		flying.position = screen_position.lerp(player_hud.life_icon_center(), travel).round()
	, 0.0, 1.0, 0.5)
	tween.tween_callback(func() -> void:
		flying.queue_free()
		sfx_extra_life_arrive.play()
		if _life_flash and _life_flash.is_valid():
			_life_flash.kill()
		_life_icon.modulate = Color(2, 2, 2, 1)
		_life_flash = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		_life_flash.tween_property(_life_icon, "modulate", Color.WHITE, 0.15)
	)

func finish_player_death() -> void:
	_clear_pending_deferred_unpause()
	_pause_menu_open = false
	pause_menu_overlay.hide()
	if GameState.get_lives() == 0:
		_retry_path = GameState.continue_destination
		_retry_action = SceneTransition.SessionAction.CONTINUE
		_retry_effect = SceneTransition.Effect.STAR
		_retry_is_restart = false
		_show_death_menu(false)
	else:
		_retry_path = get_parent().scene_file_path
		_retry_action = SceneTransition.SessionAction.KEEP
		_retry_effect = SceneTransition.Effect.CIRCLE
		_retry_is_restart = true
		_attempt_death_transition()

func _show_death_menu(recovery: bool) -> void:
	_death_confirming = false
	_death_selection = 0
	_death_title.text = "TRANSITION FAILED" if recovery else "GAME OVER"
	_death_menu.set_meta("recovery", recovery)
	_death_menu.show()
	get_tree().paused = true
	_refresh_death_menu()

func _refresh_death_menu() -> void:
	var action := "RETRY TRANSITION" if _death_menu.get_meta("recovery", false) else "CONTINUE"
	_death_options.text = "%s %s\n\n%s MAIN MENU" % [
		">" if _death_selection == 0 else " ", action,
		">" if _death_selection == 1 else " "]

func _handle_death_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _death_confirming or event.is_echo():
		return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down"):
		_death_selection = 1 - _death_selection
		sfx_ui_move.play()
		_refresh_death_menu()
	elif event.is_action_pressed(&"ui_accept"):
		sfx_ui_confirm.play()
		if _death_selection == 1:
			_retry_path = TITLE_SCENE
			_retry_action = SceneTransition.SessionAction.KEEP
			_retry_effect = SceneTransition.Effect.FADE
			_retry_is_restart = false
		_attempt_death_transition()

func _attempt_death_transition() -> void:
	_death_confirming = true
	if not SceneTransition.change_scene(_retry_path, _retry_effect, _retry_is_restart, _retry_action):
		_show_death_menu(true)
