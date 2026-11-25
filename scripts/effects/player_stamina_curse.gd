extends Node
## Shared player-owned curse/taco presentation. All timing follows gameplay pause.
const SHADER := preload("res://scripts/effects/stamina_curse.gdshader")
const BANNER := preload("res://scripts/ui/stamina_curse_banner.gd")
var gas_mode := false
var player: CharacterBody2D
var _elapsed := 0.0
var _material: ShaderMaterial
var _previous_material: Material
var _overlay: CanvasLayer
var _banner: Control
var _meter: Control
var _revealed := false
var _pose_held := false
var _converted := false
var _puffed := false
var _granted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = get_parent()
	player.curse_sequence_active = true
	player.reset_for_external_launch()
	player._cancel_shooting()
	player._disable_kick_hitbox()
	player.velocity = Vector2.ZERO
	if player.anim.sprite_frames.has_animation(&"hurt"):
		player.anim.play(&"hurt")
	player.anim.modulate = Color.WHITE
	player.movement_resource.set_stamina_phase(true)
	_previous_material = player.anim.material
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	player.anim.material = _material
	_overlay = CanvasLayer.new()
	_overlay.layer = 0
	add_child(_overlay)
	_banner = BANNER.new()
	_banner.gas_mode = gas_mode
	_overlay.add_child(_banner)
	var ui := get_tree().get_first_node_in_group("ui")
	if ui != null:
		_meter = ui.get_node_or_null("PlayerHUD/ResourceMeter")
	if _meter != null:
		_meter.set_reveal_progress(1.0 if gas_mode else 0.0)
		_meter.set_transmutation_progress(0.0)
		_banner.meter_rect = Rect2(
			(_meter.get_global_transform_with_canvas() * Vector2(_meter._label_width() + 1, 1)).round(),
			Vector2(player.movement_resource.capacity * _meter.pixels_per_point, _meter.fill_height))

func _process(delta: float) -> void:
	if player.state == player.State.DEAD:
		queue_free()
		return
	if SceneTransition.busy:
		return
	_elapsed += delta
	_banner.elapsed = _elapsed
	_banner.queue_redraw()
	_material.set_shader_parameter("phase", int(_elapsed / 0.08))
	_material.set_shader_parameter("active", not _converted and (_elapsed >= _banner.title_start() or int(_elapsed / 0.16) % 2 == 0))
	if _elapsed >= _banner.title_start() and not _pose_held:
		_pose_held = true
		if player.anim.sprite_frames.has_animation(&"hurt"):
			player.anim.animation = &"hurt"
			player.anim.frame = player.anim.sprite_frames.get_frame_count(&"hurt") - 1
			player.anim.pause()
	var progress: float = _banner.bar_progress()
	if progress > 0.0 and not _revealed:
		_revealed = true
		if not player.movement_resource.enabled:
			player.movement_resource.set_enabled(true)
	if _revealed and is_instance_valid(_meter):
		if gas_mode:
			_meter.set_transmutation_progress(progress)
		else:
			_meter.set_reveal_progress(progress)
	if not gas_mode:
		if _elapsed >= _banner.morph_finish():
			GameState.stamina_curse_reveal_pending = false
			queue_free()
		return
	if _elapsed >= _banner.morph_finish() and not _converted:
		_converted = true
		GameState.gas_transmuted = true
		player.movement_resource.set_stamina_phase(false)
		player._play("idle" if player.is_on_floor() else "jump_down")
	if _elapsed >= _banner.puff_start() and not _puffed:
		_puffed = true
		_play_small_fart()
	if _elapsed >= _banner.unlock_start() and not _granted:
		_granted = true
		player.add_upgrade("double_jump_upgrade")
	if _elapsed >= _banner.gas_finish():
		GameState.gas_reveal_pending = false
		queue_free()

func _play_small_fart() -> void:
	# Reuse only the compact early cloud frames, then contract: no blurry scaling.
	var source: SpriteFrames = player.fart_cloud.sprite_frames
	var frames := SpriteFrames.new()
	frames.add_animation(&"puff")
	frames.set_animation_loop(&"puff", false)
	frames.set_animation_speed(&"puff", 18.0)
	for index in [0, 1, 2, 1, 0]:
		frames.add_frame(&"puff", source.get_frame_texture(&"fart_cloud", index))
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = frames
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puff.z_index = player.z_index - 1
	add_child(puff)
	var facing := -1.0 if player.anim.flip_h else 1.0
	puff.global_position = player.to_global(Vector2(-16 * facing, 10)).round()
	puff.flip_h = player.anim.flip_h
	puff.play(&"puff")
	puff.animation_finished.connect(puff.queue_free)
	var sound := AudioStreamPlayer2D.new()
	sound.stream = player.sfx_fart.stream
	sound.bus = player.sfx_fart.bus
	sound.volume_db = player.sfx_fart.volume_db - 8.0
	sound.pitch_scale = 1.15
	add_child(sound)
	sound.global_position = player.global_position
	sound.play()
	sound.finished.connect(sound.queue_free)

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.curse_sequence_active = false
		if is_instance_valid(player.anim) and player.anim.material == _material:
			player.anim.material = _previous_material
		player.invuln_timer = maxf(player.invuln_timer, 0.5)
		if player.state != player.State.DEAD:
			player.state = player.State.GROUND if player.is_on_floor() else player.State.AIR
			player._play("idle" if player.is_on_floor() else "jump_down")
			if not gas_mode and not GameState.stamina_curse_reveal_pending and GameState.gas_reveal_pending:
				player.call_deferred("_begin_taco_gas_reveal")
	if is_instance_valid(_meter):
		_meter.set_reveal_progress(1.0)
		_meter.set_transmutation_progress(0.0)
