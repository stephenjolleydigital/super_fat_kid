extends Area2D

@export var lifetime: float = 4.0
@export var slow_multiplier: float = 0.6
@export var slow_duration: float = 0.35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _life_timer: float = 0.0


func _ready() -> void:
	_life_timer = lifetime
	on_screen.screen_exited.connect(queue_free)
	_play_if_exists("idle")


func _physics_process(delta: float) -> void:
	_life_timer = maxf(0.0, _life_timer - delta)
	if _life_timer <= 0.0:
		queue_free()
		return

	for area in get_overlapping_areas():
		if not area.is_in_group("player_hurtbox"):
			continue
		var player := area.get_parent()
		if player and player.has_method("apply_slow"):
			player.call("apply_slow", slow_multiplier, slow_duration)


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
