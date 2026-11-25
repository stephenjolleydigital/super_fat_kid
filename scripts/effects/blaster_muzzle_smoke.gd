extends AnimatedSprite2D

const FRAME_OPACITY := [0.60, 0.45, 0.30, 0.15]

func _ready() -> void:
	animation_finished.connect(queue_free)
	frame_changed.connect(_update_opacity)
	play("smoke")
	_update_opacity()

func _update_opacity() -> void:
	# Fade in discrete steps with the four pixel-art poses.
	self_modulate.a = FRAME_OPACITY[clampi(frame, 0, FRAME_OPACITY.size() - 1)]
