extends Control
## Owns one visit to the cabinet. The level stays loaded while the games use
## their own 256x224 viewport, physics space, input and camera transform.
signal closed

enum Mode { OPENING, MENU, PLAYING, LEAVE_GAME, RESULT, CLOSING }
const GAMES := [
	"res://assets/minigames/alien_commander/scenes/Alien_Commander.tscn",
	"res://assets/minigames/snack_kid_superstar/scenes/Snack_Kid_Superstar.tscn",
]
const IDS := [&"alien_commander", &"snack_run"]
const OPTIONS := ["ALIEN COMMANDER", "SNACK RUN", "LEVEL UP", "LEAVE CABINET"]
const SHEET := preload("res://assets/sprites/objects/arcade_cabinet/arcade_cabinet.png")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const MOVE_SOUND := preload("res://assets/audio/sfx/ui/sfx_ui_move_01.wav")
const SELECT_SOUND := preload("res://assets/audio/sfx/ui/sfx_ui_confirm_01.wav")
const NATIVE := Vector2i(256, 224)
const INK := Color("#131724")
const PANEL := Color("#252c3a")
const GOLD := Color("#fac75a")
const PAPER := Color("#fff2d6")
const MUTED := Color("#aebac3")

var glass_on_screen: Rect2
var glass_region: Rect2
var mode := Mode.OPENING
var selected := 0
var zoom_amount := 0.0:
	set(value):
		zoom_amount = value
		queue_redraw()
var notice := ""
var result := {}
var game: Node
var display := SubViewport.new()
var sound := AudioStreamPlayer.new()
var resume_selected := true
var stick_direction := 0
var controller_controls := false
var music_was_paused := false
var hud: CanvasLayer
var hud_was_visible := false
var owns_pause := false
var host_space: RID
var owns_physics := false


func _ready() -> void:
	stick_direction = roundi(Input.get_axis(&"ui_up", &"ui_down"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.size = NATIVE
	display.disable_3d = true
	display.world_2d = World2D.new()
	display.handle_input_locally = true
	display.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	display.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(display)
	add_child(sound)
	host_space = get_viewport().world_2d.space
	hud = get_tree().get_first_node_in_group(&"ui") as CanvasLayer
	if hud:
		hud_was_visible = hud.visible
		hud.hide()
	music_was_paused = MusicManager.is_music_paused()
	MusicManager.set_music_paused(true)
	owns_pause = true
	get_tree().paused = true
	await _zoom(1.0).finished
	mode = Mode.MENU
	queue_redraw()


func _zoom(target: float) -> Tween:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "zoom_amount", target, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tween


func _close() -> void:
	mode = Mode.CLOSING
	await _zoom(0.0).finished
	_restore_level()
	closed.emit()


func _restore_level() -> void:
	if not owns_pause:
		return
	owns_pause = false
	_stop_game_physics()
	if is_instance_valid(hud):
		hud.visible = hud_was_visible
	MusicManager.set_music_paused(music_was_paused)
	get_tree().paused = false


func _exit_tree() -> void:
	_restore_level()


func _start_game() -> void:
	var scene := load(GAMES[selected]) as PackedScene
	var next := scene.instantiate() if scene else null
	if not next or not next.has_signal(&"arcade_finished") or not next.has_method(&"get_arcade_result"):
		if next:
			next.free()
		notice = "GAME UNAVAILABLE"
		queue_redraw()
		return
	game = next
	game.set(&"arcade_mode", true)
	game.connect(&"arcade_finished", _finish_game, CONNECT_ONE_SHOT)
	mode = Mode.PLAYING
	notice = ""
	# Pausing the SceneTree also stops the physics server. Run only the arcade
	# space so Alien Commander projectiles still collide during a paid game.
	PhysicsServer2D.space_set_active(host_space, false)
	PhysicsServer2D.set_active(true)
	owns_physics = true
	display.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(game)
	queue_redraw()


func _stop_game_physics() -> void:
	if owns_physics:
		PhysicsServer2D.set_active(false)
		PhysicsServer2D.space_set_active(host_space, true)
		owns_physics = false


func _finish_game(summary: Dictionary) -> void:
	if mode != Mode.PLAYING and mode != Mode.LEAVE_GAME:
		return
	result = summary.duplicate(true)
	mode = Mode.RESULT
	if game.has_method(&"shutdown"):
		game.call(&"shutdown")
	game.queue_free()
	game = null
	display.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stop_game_physics()
	GameState.report_arcade_run_finished(IDS[selected], result)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not owns_pause:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton:
		controller_controls = true
	elif event is InputEventKey:
		controller_controls = false
	if event is InputEventJoypadMotion and mode != Mode.PLAYING:
		if event.axis != JOY_AXIS_LEFT_Y:
			return
		var direction := signi(roundi(event.axis_value))
		if direction == 0 or direction == stick_direction:
			stick_direction = direction
			return
		stick_direction = direction
	var back := event.is_action_pressed(&"game_pause")
	var cancel := event.is_action_pressed(&"ui_cancel")
	var accept := event.is_action_pressed(&"ui_accept")
	match mode:
		Mode.MENU:
			if back or cancel:
				_close()
			elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_up"):
				var direction := 1 if event.is_action_pressed(&"ui_down") else -1
				selected = posmod(selected + direction, OPTIONS.size())
				notice = ""
				_beep(MOVE_SOUND)
			elif accept:
				_beep(SELECT_SOUND)
				match selected:
					0, 1: _start_game()
					2: notice = "UPGRADES COMING SOON"
					3: _close()
		Mode.PLAYING:
			if back:
				mode = Mode.LEAVE_GAME
				resume_selected = true
				game.process_mode = Node.PROCESS_MODE_DISABLED
				PhysicsServer2D.set_active(false)
			else:
				display.push_input(event, true)
		Mode.LEAVE_GAME:
			if back or cancel or (accept and resume_selected):
				game.process_mode = Node.PROCESS_MODE_INHERIT
				PhysicsServer2D.set_active(true)
				mode = Mode.PLAYING
			elif accept:
				_finish_game(game.call(&"get_arcade_result", "exit"))
			elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_up"):
				resume_selected = not resume_selected
				_beep(MOVE_SOUND)
		Mode.RESULT:
			if accept or back or cancel:
				mode = Mode.MENU
				notice = ""
	queue_redraw()


func _beep(stream: AudioStream) -> void:
	sound.stream = stream
	sound.play()


func _draw() -> void:
	var target := Rect2(((size - Vector2(NATIVE)) * 0.5).floor(), Vector2(NATIVE))
	var glass := Rect2(glass_on_screen.position.lerp(target.position, zoom_amount).round(),
			glass_on_screen.size.lerp(target.size, zoom_amount).round())
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.043, 0.067, zoom_amount))
	draw_rect(glass.grow(2), Color("#58665e"))
	if mode == Mode.OPENING or mode == Mode.CLOSING:
		draw_texture_rect_region(SHEET, glass, glass_region)
		return
	draw_set_transform(target.position)
	draw_rect(Rect2(Vector2.ZERO, Vector2(NATIVE)), INK)
	if mode == Mode.PLAYING or mode == Mode.LEAVE_GAME:
		draw_texture(display.get_texture(), Vector2.ZERO)
		var hint: String
		if selected == 0:
			hint = "D-PAD MOVE   LB GRAB   RB FIRE   START MENU" if controller_controls else "WASD MOVE   SHIFT GRAB   SPACE FIRE   ESC MENU"
		else:
			hint = "STICK MOVE   A FLOP   X USE   START MENU" if controller_controls else "WASD MOVE   SPACE FLOP   E USE   ESC MENU"
		_text(hint, (NATIVE.x - hint.length() * 8) >> 1, 238, MUTED)
		if mode == Mode.PLAYING:
			return
		draw_rect(Rect2(12, 66, 232, 94), INK)
		draw_rect(Rect2(12, 66, 232, 94), GOLD, false)
		_text("LEAVE THIS PLAY?", 28, 90, PAPER)
		_text(("> " if resume_selected else "  ") + "RESUME", 28, 116, GOLD if resume_selected else MUTED)
		_text(("  " if resume_selected else "> ") + "END PLAY", 28, 140, MUTED if resume_selected else GOLD)
		return
	if mode == Mode.RESULT:
		_text(OPTIONS[selected], 14, 38, GOLD)
		draw_line(Vector2(14, 49), Vector2(242, 49), GOLD)
		var outcome := str(result.get("outcome", ""))
		var headline := "PLAY ENDED"
		if outcome in ["dead", "loss", "game_over"]: headline = "GAME OVER"
		if outcome in ["win", "victory", "completed"]: headline = "GAME CLEAR"
		if outcome == "dev_complete": headline = "WAVES COMPLETE"
		_text(headline, 14, 87, PAPER)
		if result.has("score"):
			_text("SCORE  %s" % result.score, 14, 114, GOLD)
		elif result.has("wave"):
			_text("WAVE  %s" % result.wave, 14, 114, GOLD)
		_text("SELECT TO RETURN", 14, 197, MUTED)
		return
	_text("SELECT GAME", 12, 22, PAPER)
	draw_line(Vector2(12, 32), Vector2(244, 32), GOLD)
	for i in OPTIONS.size():
		var row := Rect2(12, 41 + i * 34, 232, 29)
		var active := i == selected
		draw_rect(row, PANEL)
		if active:
			draw_rect(row, GOLD, false)
			draw_rect(Rect2(row.position, Vector2(3, row.size.y)), GOLD)
		_text(OPTIONS[i], 23, int(row.position.y) + 18, GOLD if active else PAPER)
		if i < 2:
			draw_texture_rect_region(SHEET, Rect2(198, row.position.y, 43, 29),
					Rect2(16 + (0 if i == 0 else 7 * 76), 31, 43, 29))
	var cents := GameState.get_quarters() * 25
	_text("WALLET  $%d.%02d" % [floori(cents / 100.0), cents % 100], 12, 194, GOLD)
	_text("ENTER/A SELECT   ESC/B BACK" if notice.is_empty() else notice, 12, 214, MUTED if notice.is_empty() else PAPER)


func _text(value: String, x: int, baseline: int, color: Color) -> void:
	draw_string(FONT, Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
