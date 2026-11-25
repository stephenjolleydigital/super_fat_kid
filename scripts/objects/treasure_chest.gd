extends Node2D

const REWARD_POP_OFFSET_Y: float = -18.0
const REWARD_POP_DURATION_S: float = 0.2

const Identity := preload("res://scripts/pickups/persistent_identity.gd")
@export var chest_id: String = ""
var _persistent_valid: bool = false

@export var reward_scene: PackedScene
@export var hit_animation: StringName = &"hit"
## Turn off for secret/optional chests; Automatic playtest starts skip them.
@export var required_for_progression: bool = true
@export var chest_solid_open_shape_size: Vector2 = Vector2(31, 11)
@export var chest_solid_open_shape_offset: Vector2 = Vector2(-0.5, 4)

@onready var chest_base: AnimatedSprite2D = $ChestBase
@onready var chest_lid: AnimatedSprite2D = $ChestLid
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx
@onready var hit_sfx_2: AudioStreamPlayer2D = $HitSfx2
@onready var lid_open_sfx: AudioStreamPlayer2D = $LidOpenSfx
@onready var item_pop_sfx: AudioStreamPlayer2D = $ItemPopSfx
@onready var hurtbox: Area2D = $Hurtbox
@onready var item_spawn: Marker2D = $ItemSpawn
@onready var chest_solid_shape: CollisionShape2D = $ChestSolid/CollisionShape2D

var has_opened: bool = false
var has_spawned_reward: bool = false
var last_hit_sfx_frame: int = -1

func _ready() -> void:
	add_to_group("persistent_owners")
	call_deferred("_restore_chest")
	add_to_group("custom_kick_contact")
	chest_base.play("idle")
	chest_lid.play("idle")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	chest_lid.frame_changed.connect(_on_chest_lid_frame_changed)
	chest_lid.animation_finished.connect(_on_chest_lid_animation_finished)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _persistent_valid or not area.is_in_group("player_attack"):
		return
	# An opened chest still resists kicks; only its opening and reward are one-shot.
	if area.name == &"KickHitbox":
		var kick_pivot := area.get_parent()
		var player: Node = kick_pivot.get_parent() if kick_pivot else null
		if player and player.has_method("apply_solid_kick_recoil"):
			player.call("apply_solid_kick_recoil", area)
	if has_opened:
		return
	has_opened = true
	GameState.opened_chest_ids.append(chest_id)
	last_hit_sfx_frame = 0
	if is_instance_valid(hit_sfx) and hit_sfx.stream:
		hit_sfx.play()
	chest_base.play(hit_animation)
	chest_lid.play(hit_animation)

func _on_chest_lid_frame_changed() -> void:
	if chest_lid.animation != hit_animation:
		last_hit_sfx_frame = -1
		return
	var current_frame: int = chest_lid.frame
	if current_frame == last_hit_sfx_frame:
		return
	last_hit_sfx_frame = current_frame
	if current_frame == 2:
		if is_instance_valid(hit_sfx_2) and hit_sfx_2.stream:
			hit_sfx_2.play()

func _on_chest_lid_animation_finished() -> void:
	if chest_lid.animation == hit_animation:
		chest_base.play("open")
		chest_lid.play("open")
		if is_instance_valid(lid_open_sfx) and lid_open_sfx.stream:
			lid_open_sfx.play()
	elif chest_lid.animation == "open":
		var base_open_frame_count: int = chest_base.sprite_frames.get_frame_count("open")
		var lid_open_frame_count: int = chest_lid.sprite_frames.get_frame_count("open")
		chest_base.stop()
		chest_lid.stop()
		if base_open_frame_count > 0:
			chest_base.frame = base_open_frame_count - 1
		if lid_open_frame_count > 0:
			chest_lid.frame = lid_open_frame_count - 1
		_apply_chest_solid_open_collision()
		_spawn_reward()

func _apply_chest_solid_open_collision() -> void:
	var rect: RectangleShape2D = chest_solid_shape.shape.duplicate() as RectangleShape2D
	if rect == null:
		return
	chest_solid_shape.shape = rect
	rect.size = chest_solid_open_shape_size
	chest_solid_shape.position = chest_solid_open_shape_offset

func _spawn_reward(restoring: bool = false) -> void:
	if has_spawned_reward or GameState.has_reward(persistence_id()):
		return
	if reward_scene == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var reward_instance: Node = reward_scene.instantiate()
	if not "persistent_reward_id" in reward_instance:
		push_error("Chest requires a permanent ability or max-HP reward: " + chest_id)
		reward_instance.free()
		return
	reward_instance.persistent_reward_id = persistence_id()
	current_scene.add_child(reward_instance)
	if not restoring and is_instance_valid(item_pop_sfx) and item_pop_sfx.stream:
		item_pop_sfx.play()
	if reward_instance is Node2D:
		var reward_node_2d: Node2D = reward_instance as Node2D
		var start_pos: Vector2 = item_spawn.global_position
		var end_pos: Vector2 = start_pos + Vector2(0.0, REWARD_POP_OFFSET_Y)
		reward_node_2d.global_position = start_pos
		reward_node_2d.z_index = maxi(chest_base.z_index, chest_lid.z_index) + 1
		if restoring:
			reward_node_2d.global_position = end_pos
			has_spawned_reward = true
			return
		var tween: Tween = reward_node_2d.create_tween()
		tween.tween_property(
			reward_node_2d,
			"global_position",
			end_pos,
			REWARD_POP_DURATION_S
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	has_spawned_reward = true


func persistence_id() -> String:
	return "chest:" + chest_id if not chest_id.strip_edges().is_empty() else ""

func _restore_chest() -> void:
	_persistent_valid = Identity.validate(self, persistence_id())
	if not _persistent_valid:
		return
	if chest_id not in GameState.opened_chest_ids:
		return
	has_opened = true
	for sprite: AnimatedSprite2D in [chest_base, chest_lid]:
		sprite.animation = &"open"
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count(&"open") - 1
	_apply_chest_solid_open_collision()
	_spawn_reward(true)

func invalidate_persistence() -> void:
	_persistent_valid = false
