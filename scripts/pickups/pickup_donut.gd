extends Area2D

# Donut pickup: heals the player, plays SFX, optionally plays a "collect" anim, then frees.

@export var heal_amount: int = 1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("SFX_Pickup")

var collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if anim:
		anim.play("idle")

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body == null or not body.is_in_group("player"):
		return

	collected = true

	# IMPORTANT: defer collision changes so Godot doesn't error during query flush
	if col:
		col.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	# Heal
	if body.has_method("heal"):
		body.call("heal", heal_amount)
		print("DONUT: healed player by", heal_amount, "HP")
	else:
		print("DONUT: player has no heal() method")

	if sfx and sfx.stream:
		var parent := get_parent()
		if parent:
			sfx.reparent(parent)
		sfx.global_position = global_position
		sfx.play()
		sfx.finished.connect(sfx.queue_free, CONNECT_ONE_SHOT)

	# Play collect animation then remove
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("collect"):
		anim.play("collect")
		# If the signal might already be connected (scene reloads etc.), disconnect safely
		if anim.animation_finished.is_connected(_on_collect_finished):
			anim.animation_finished.disconnect(_on_collect_finished)
		anim.animation_finished.connect(_on_collect_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()

func _on_collect_finished() -> void:
	queue_free()
