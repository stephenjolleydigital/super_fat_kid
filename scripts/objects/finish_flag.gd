class_name FinishFlag
extends AnimatedSprite2D

## Emitted the first time the player reaches the flag. The flag owns the
## celebration only; the level script decides what happens after it.
signal activated

const RISE_ANIMATION: StringName = &"rise"
const WAVE_ANIMATION: StringName = &"wave"
const CONFETTI_ANIMATION: StringName = &"burst"
const PLAYER_GROUP: StringName = &"player"

@export_range(0.0, 1.0, 0.05) var complete_sfx_progress_at_wave_start: float = 0.6

@onready var _confetti: AnimatedSprite2D = $Confetti
@onready var _player_detector: Area2D = $PlayerDetector
@onready var _sfx_rise: AudioStreamPlayer2D = $SFX_Rise
@onready var _sfx_complete: AudioStreamPlayer2D = $SFX_Complete
@onready var _complete_sfx_timer: Timer = $CompleteSFXTimer

var _activated: bool = false
var _rise_sfx_played: bool = false
var _complete_sfx_played: bool = false


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	_complete_sfx_timer.timeout.connect(_play_complete_sfx_once)
	_confetti.animation_finished.connect(_on_confetti_finished)
	_confetti.hide()
	_player_detector.body_entered.connect(_on_player_detector_body_entered)


## Public so a scripted sequence (for example a boss level) can raise the flag
## without the player walking into it.
func activate() -> void:
	if _activated:
		return
	_activated = true
	_player_detector.set_deferred("monitoring", false)
	play(RISE_ANIMATION)
	_play_rise_sfx_once()
	_schedule_complete_sfx()
	_play_confetti()
	activated.emit()


func _on_player_detector_body_entered(body: Node2D) -> void:
	if not body.is_in_group(PLAYER_GROUP):
		return
	activate()


func _play_confetti() -> void:
	_confetti.show()
	_confetti.frame = 0
	_confetti.play(CONFETTI_ANIMATION)


func _on_confetti_finished() -> void:
	_confetti.hide()


func _schedule_complete_sfx() -> void:
	if not _sfx_complete.stream:
		return
	var rise_duration := _get_animation_duration(RISE_ANIMATION)
	var sound_progress_before_wave := (
		_sfx_complete.stream.get_length() * complete_sfx_progress_at_wave_start
	)
	var delay := maxf(rise_duration - sound_progress_before_wave, 0.0)
	if is_zero_approx(delay):
		_play_complete_sfx_once()
	else:
		_complete_sfx_timer.start(delay)


func _get_animation_duration(animation_name: StringName) -> float:
	if not sprite_frames or not sprite_frames.has_animation(animation_name):
		return 0.0
	var animation_speed := sprite_frames.get_animation_speed(animation_name) * absf(speed_scale)
	if animation_speed <= 0.0:
		return 0.0
	var duration := 0.0
	for frame_index in range(sprite_frames.get_frame_count(animation_name)):
		duration += sprite_frames.get_frame_duration(animation_name, frame_index) / animation_speed
	return duration


func _on_animation_finished() -> void:
	if animation == RISE_ANIMATION:
		play(WAVE_ANIMATION)


func _play_rise_sfx_once() -> void:
	if _rise_sfx_played:
		return
	_rise_sfx_played = true
	_sfx_rise.play()


func _play_complete_sfx_once() -> void:
	if _complete_sfx_played:
		return
	_complete_sfx_played = true
	_sfx_complete.play()
