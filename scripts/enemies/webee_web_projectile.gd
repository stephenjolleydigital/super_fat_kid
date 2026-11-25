extends Area2D

@export var direction: int = 1
@export var speed: float = 140.0
@export var trap_lifetime: float = 4.0
@export var slow_multiplier: float = 0.6
@export var slow_duration: float = 0.35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sfx_stick: AudioStreamPlayer2D = $SFX_Stick
@onready var sfx_dissolve: AudioStreamPlayer2D = $SFX_Dissolve
@onready var sfx_slow_contact: AudioStreamPlayer2D = $SFX_SlowContact
@onready var sfx_slow_loop: AudioStreamPlayer2D = $SFX_SlowLoop

var _stuck: bool = false
var _dissolving: bool = false
var _trap_timer: float = 0.0
var _stuck_shape: RectangleShape2D
var _player_in_web: bool = false


func _ready() -> void:
	direction = -1 if direction < 0 else 1
	if sprite:
		sprite.flip_h = direction < 0

	_stuck_shape = RectangleShape2D.new()
	_stuck_shape.size = Vector2(18, 12)

	# Loop a private copy; the louder contact cue uses the original one-shot.
	var loop_stream := sfx_slow_loop.stream.duplicate() as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = roundi(loop_stream.get_length() * loop_stream.mix_rate)
	sfx_slow_loop.stream = loop_stream

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	on_screen.screen_exited.connect(queue_free)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"spawn_grow"):
		sprite.play(&"spawn_grow")
		sprite.animation_finished.connect(_on_spawn_grow_finished, CONNECT_ONE_SHOT)
	else:
		_start_fly()


func set_direction_x(dir: int) -> void:
	direction = -1 if dir < 0 else 1
	if sprite:
		sprite.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	if _dissolving:
		return

	if not _stuck:
		global_position.x += float(direction) * speed * delta
		return

	_trap_timer = maxf(0.0, _trap_timer - delta)
	_apply_slow_to_overlapping_player()

	if _trap_timer <= 0.0:
		_start_dissolve()


func _on_spawn_grow_finished() -> void:
	if _stuck or _dissolving:
		return
	_start_fly()


func _start_fly() -> void:
	_play_if_exists(&"fly")


func _on_body_entered(body: Node2D) -> void:
	if _stuck or _dissolving:
		return

	if has_meta(&"spawner_body") and body == get_meta(&"spawner_body"):
		return

	if body.is_in_group(&"player"):
		return

	_stick()


func _on_area_entered(area: Area2D) -> void:
	if _stuck or _dissolving:
		return

	if area.is_in_group(&"player_hurtbox"):
		_stick()


func _stick() -> void:
	if _stuck or _dissolving:
		return

	_stuck = true
	_trap_timer = trap_lifetime
	_play_sfx(sfx_stick)

	if is_instance_valid(shape) and _stuck_shape:
		shape.set_deferred("shape", _stuck_shape)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"web_form"):
		sprite.play(&"web_form")
		sprite.animation_finished.connect(_on_web_form_finished, CONNECT_ONE_SHOT)
	else:
		_play_if_exists(&"web_idle")


func _on_web_form_finished() -> void:
	if _dissolving:
		return
	_play_if_exists(&"web_idle")


func _start_dissolve() -> void:
	if _dissolving:
		return

	_dissolving = true
	_update_slow_audio(false, false)
	_play_sfx(sfx_dissolve)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"web_dissolve"):
		sprite.play(&"web_dissolve")
		sprite.animation_finished.connect(_on_dissolve_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_dissolve_finished() -> void:
	queue_free()


func _apply_slow_to_overlapping_player() -> void:
	var player_touching := false
	var player_moving := false
	for area in get_overlapping_areas():
		if not area.is_in_group(&"player_hurtbox"):
			continue
		var player := area.get_parent()
		if player and player.has_method(&"apply_slow"):
			player.call(&"apply_slow", slow_multiplier, slow_duration)
			player_touching = true
			if player is CharacterBody2D and player.velocity.length_squared() > 4.0:
				player_moving = true
	_update_slow_audio(player_touching, player_moving)


func _update_slow_audio(player_touching: bool, player_moving: bool) -> void:
	if player_touching and not _player_in_web:
		_play_sfx(sfx_slow_contact)
	_player_in_web = player_touching

	# Let the entry cue finish before switching to the quieter moving loop.
	if player_touching and player_moving and not sfx_slow_contact.playing:
		if not sfx_slow_loop.playing:
			sfx_slow_loop.play()
	elif sfx_slow_loop.playing:
		sfx_slow_loop.stop()


func _play_if_exists(anim_name: StringName) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()
