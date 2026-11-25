extends Area2D

const UpgradePickupEffect = preload("res://scripts/effects/upgrade_pickup_effect.gd")

# Generic permanent-upgrade pickup: gives player an upgrade by ID, optional toast, SFX, "collect" anim, then frees.
# Player must be in group "player" and implement add_upgrade(id).
# Toast IDs must match scripts/ui/ui.gd play_upgrade_toast(anim_name): e.g. "double_jump_upgrade", "crouch_upgrade", "kick_upgrade".

@export var upgrade_id: String = ""
@export var upgrade_toast: String = ""
@export var transmutes_stamina: bool = false
@export var requires_stamina_curse: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("SFX_Pickup")

var persistent_reward_id: String = ""
var collected := false

func _ready() -> void:
	if not persistent_reward_id.is_empty() and GameState.has_reward(persistent_reward_id):
		queue_free()
		return
	# Loose pickups vanish once owned; a taco still has to deliver pending gas.
	if persistent_reward_id.is_empty() and GameState.has_upgrade(upgrade_id) \
			and not (transmutes_stamina and not GameState.gas_transmuted):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	set_physics_process(transmutes_stamina)
	visible = not requires_stamina_curse or (GameState.stamina_cursed and not GameState.stamina_curse_reveal_pending)
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")

func _physics_process(_delta: float) -> void:
	if collected:
		return
	visible = not requires_stamina_curse or (GameState.stamina_cursed and not GameState.stamina_curse_reveal_pending)
	if visible:
		# A player already overlapping when the curse ends should still collect it.
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _on_body_entered(body: Node) -> void:
	if collected or SceneTransition.busy:
		return
	if body == null or not body.is_in_group("player"):
		return

	if requires_stamina_curse and (not GameState.stamina_cursed or GameState.stamina_curse_reveal_pending):
		return
	if transmutes_stamina and body.curse_sequence_active:
		return
	if body.state == body.State.DEAD:
		return
	collected = true
	GameState.collect_reward(persistent_reward_id)

	if col:
		col.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	var staged_taco: bool = transmutes_stamina and body.collect_stamina_taco()
	if staged_taco:
		pass # The player-owned sequence grants the upgrade after the reveal.
	elif body.has_method("add_upgrade") and upgrade_id:
		var had_upgrade := GameState.has_upgrade(upgrade_id)
		body.add_upgrade(upgrade_id)
		if not had_upgrade and GameState.has_upgrade(upgrade_id):
			UpgradePickupEffect.spawn(get_parent(), global_position)
		if upgrade_toast != "":
			var ui := get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("play_upgrade_toast"):
				ui.play_upgrade_toast(upgrade_toast)
	else:
		print("PICKUP_UPGRADE: player has no add_upgrade() or upgrade_id empty")

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
