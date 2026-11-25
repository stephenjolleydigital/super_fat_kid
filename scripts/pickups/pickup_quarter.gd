extends Area2D

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.play("idle")

func _on_body_entered(body: Node) -> void:
	if collected:
		return

	if body.name != "Player":
		return

	collected = true
	collision.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("add_quarters"):
		ui.add_quarters(1)

	if audio and audio.stream:
		var parent := get_parent()
		if parent:
			audio.reparent(parent)
		audio.global_position = global_position
		audio.play()
		audio.finished.connect(audio.queue_free, CONNECT_ONE_SHOT)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("collect"):
		sprite.play("collect")
		if sprite.animation_finished.is_connected(_on_collect_finished):
			sprite.animation_finished.disconnect(_on_collect_finished)
		sprite.animation_finished.connect(_on_collect_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()

func _on_collect_finished() -> void:
	queue_free()
