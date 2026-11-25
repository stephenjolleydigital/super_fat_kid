extends Area2D
const Identity := preload("res://scripts/pickups/persistent_identity.gd")
enum Source { PLACED, ENEMY_DROP }
@export var source: Source = Source.PLACED
@export var pickup_id: String = ""
var collected: bool = false
var _valid: bool = false

func persistence_id() -> String:
	return pickup_id

func _ready() -> void:
	if source == Source.PLACED:
		add_to_group("persistent_owners")
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("idle")
	call_deferred("_initialize")

func _initialize() -> void:
	if source == Source.PLACED:
		_valid = Identity.validate(self, pickup_id)
		if not _valid:
			$CollisionShape2D.set_deferred("disabled", true)
			return
		if GameState.has_reward(pickup_id):
			queue_free()
			return
	else:
		_valid = true

func _on_body_entered(body: Node2D) -> void:
	if not _valid or collected or SceneTransition.busy:
		return
	if not body.is_in_group("player") or body.state == body.State.DEAD:
		return
	collected = true
	$CollisionShape2D.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	if source == Source.PLACED:
		GameState.collect_reward(pickup_id)
	GameState.add_lives()
	var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
	audio.reparent(get_parent())
	audio.play()
	audio.finished.connect(audio.queue_free, CONNECT_ONE_SHOT)
	var ui := get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("fly_life_to_hud"):
		ui.fly_life_to_hud(get_global_transform_with_canvas().origin)
	# The HUD owns the single animated copy from here onward.
	hide()
	queue_free()

func invalidate_persistence() -> void:
	_valid = false
	$CollisionShape2D.set_deferred("disabled", true)
