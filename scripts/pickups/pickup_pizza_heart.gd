extends Area2D

const UpgradePickupEffect = preload("res://scripts/effects/upgrade_pickup_effect.gd")

# Pizza heart upgrade pickup: +1 max_hp (stacks per pickup), heal 1, collect anim, then frees.

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("SFX_Pickup")

var persistent_reward_id: String = ""
var collected := false

func _ready() -> void:
	if not persistent_reward_id.is_empty() and GameState.has_reward(persistent_reward_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	if anim:
		anim.play("idle")

func _on_body_entered(body: Node) -> void:
	if collected or SceneTransition.busy:
		return
	if body == null or not body.is_in_group("player"):
		return

	if body.state == body.State.DEAD:
		return
	collected = true
	GameState.collect_reward(persistent_reward_id)

	if body.has_method("grant_max_hp_upgrade"):
		body.grant_max_hp_upgrade()
		UpgradePickupEffect.spawn(get_parent(), global_position)
		print("Pizza heart upgrade collected — max_hp:", body.max_hp, "hp:", body.hp)

	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("play_upgrade_toast"):
		ui.play_upgrade_toast("max_hp_upgrade")

	if col:
		col.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	if sfx and sfx.stream:
		var parent := get_parent()
		if parent:
			sfx.reparent(parent)
		sfx.global_position = global_position
		sfx.play()
		sfx.finished.connect(sfx.queue_free, CONNECT_ONE_SHOT)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("collect"):
		anim.play("collect")
		if anim.animation_finished.is_connected(_on_collect_finished):
			anim.animation_finished.disconnect(_on_collect_finished)
		anim.animation_finished.connect(_on_collect_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()

func _on_collect_finished() -> void:
	queue_free()
