extends Node2D
## Two editable sprite layers share a deterministic clock so pause/hitstop never desync them.
@export var crouch_offset := Vector2(0, 9)
@export_range(0.0, 1.0, 0.05) var sweat_1_opacity: float = 0.65
@export_range(0.0, 1.0, 0.05) var sweat_2_opacity: float = 0.45
@export_range(1, 8) var second_start_frame: int = 3
@export_range(0.01, 1.0, 0.01) var layer_fade_seconds: float = 0.15
@export_range(0.01, 1.0, 0.01) var recovery_fade_seconds: float = 0.25

@onready var player = get_parent()
@onready var body: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
# Preserve the placement authored on the Sweat node in the scene.
@onready var _head_offset: Vector2 = position - body.position
@onready var first: AnimatedSprite2D = $Sweat1
@onready var second: AnimatedSprite2D = $Sweat2
var resource: RefCounted
var elapsed: float = 0.0
var envelope: float = 0.0
var exhausted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	resource = player.movement_resource
	resource.exhaustion_changed.connect(_on_exhaustion_changed)
	resource.enabled_changed.connect(_on_enabled_changed)
	_clear()
	if resource.enabled and resource.exhausted:
		_on_exhaustion_changed(true)

func _on_enabled_changed(active: bool) -> void:
	if not active:
		_clear()

func _on_exhaustion_changed(active: bool) -> void:
	exhausted = active and resource.enabled
	if exhausted:
		elapsed = 0.0
		envelope = 0.0
		visible = true
		_update_position()
		_draw_layers()
		set_physics_process(true)

func _clear() -> void:
	exhausted = false
	elapsed = 0.0
	envelope = 0.0
	visible = false
	first.modulate.a = 0.0
	second.modulate.a = 0.0
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if player.state == player.State.DEAD or not resource.enabled:
		_clear()
		return
	if SceneTransition.busy or player.hitstop_frames > 0 or player._resource_suspended_this_tick:
		return
	_update_position()
	elapsed += delta
	envelope = move_toward(envelope, 1.0 if exhausted else 0.0, delta / recovery_fade_seconds)
	_draw_layers()
	if not exhausted and envelope <= 0.0:
		_clear()

func _update_position() -> void:
	var offset: Vector2 = _head_offset + (crouch_offset if player.is_crouching else Vector2.ZERO)
	offset.x *= -1.0 if body.flip_h else 1.0
	position = (body.position + offset).round()
	# Mirror the whole arrangement, including each layer's editor-authored offset.
	scale.x = -1.0 if body.flip_h else 1.0
	first.flip_h = false
	second.flip_h = false

func _draw_layers() -> void:
	var delay: float = 0.0
	var frames: SpriteFrames = first.sprite_frames
	var fps: float = maxf(frames.get_animation_speed(&"sweat_1"), 0.01)
	for index in range(mini(second_start_frame - 1, frames.get_frame_count(&"sweat_1"))):
		delay += frames.get_frame_duration(&"sweat_1", index) / fps
	_draw_layer(first, &"sweat_1", elapsed, sweat_1_opacity)
	_draw_layer(second, &"sweat_2", elapsed - delay, sweat_2_opacity)

func _draw_layer(sprite: AnimatedSprite2D, animation: StringName, time: float, opacity: float) -> void:
	if time < 0.0:
		sprite.modulate.a = 0.0
		return
	var frames: SpriteFrames = sprite.sprite_frames
	var fps: float = maxf(frames.get_animation_speed(animation), 0.01)
	var duration: float = 0.0
	for index in range(frames.get_frame_count(animation)):
		duration += frames.get_frame_duration(animation, index) / fps
	if duration <= 0.0:
		return
	var phase: float = fposmod(time, duration)
	var remaining: float = phase
	var frame_index: int = 0
	while frame_index < frames.get_frame_count(animation) - 1:
		var frame_time: float = frames.get_frame_duration(animation, frame_index) / fps
		if remaining < frame_time:
			break
		remaining -= frame_time
		frame_index += 1
	sprite.animation = animation
	sprite.frame = frame_index
	var fade: float = minf(layer_fade_seconds, duration * 0.5)
	var blend: float = clampf(minf(phase, duration - phase) / fade, 0.0, 1.0)
	sprite.modulate.a = opacity * blend * envelope
