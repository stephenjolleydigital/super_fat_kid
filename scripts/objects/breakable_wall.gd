extends Node2D

@export var passable_frame: int = 3
@export var broken_visual_z_index: int = 5
@export var break_animation_name: StringName = &"break"

@onready var wall_visual: AnimatedSprite2D = $WallVisual
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var wall_solid_shape: CollisionShape2D = $WallSolid/CollisionShape2D
@onready var broken_edge_shape: CollisionShape2D = get_node_or_null("BrokenEdgeCollision/CollisionShape2D")
@onready var sfx_break: AudioStreamPlayer2D = $SFX_Break

var has_broken: bool = false
var has_become_passable: bool = false

func _ready() -> void:
	add_to_group("custom_kick_contact")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	wall_visual.frame_changed.connect(_on_wall_visual_frame_changed)
	wall_visual.animation_finished.connect(_on_wall_visual_animation_finished)
	if broken_edge_shape:
		broken_edge_shape.set_deferred("disabled", true)
	wall_visual.play(&"idle")

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if has_broken:
		return
	if not area.is_in_group("player_attack"):
		return

	has_broken = true
	if area.name == &"KickHitbox":
		var kick_pivot := area.get_parent()
		var player: Node = kick_pivot.get_parent() if kick_pivot else null
		if player and player.has_method("apply_solid_kick_recoil"):
			player.call("apply_solid_kick_recoil", area)
	if is_instance_valid(sfx_break) and sfx_break.stream:
		sfx_break.play()
	wall_visual.play(break_animation_name)

func _on_wall_visual_frame_changed() -> void:
	if not has_broken or has_become_passable:
		return
	if wall_visual.animation != break_animation_name:
		return
	if wall_visual.frame < _get_passable_frame():
		return

	_set_passable_state()

func _on_wall_visual_animation_finished() -> void:
	if wall_visual.animation != break_animation_name:
		return

	if not has_become_passable:
		_set_passable_state()

	var frame_count: int = wall_visual.sprite_frames.get_frame_count(break_animation_name)
	wall_visual.stop()
	if frame_count > 0:
		wall_visual.frame = frame_count - 1

func _get_passable_frame() -> int:
	var frame_count: int = wall_visual.sprite_frames.get_frame_count(break_animation_name)
	if frame_count <= 0:
		return 0
	return clampi(passable_frame, 0, frame_count - 1)

func _set_passable_state() -> void:
	has_become_passable = true
	# The remaining solid edge/rubble now behaves like ordinary terrain.
	remove_from_group("custom_kick_contact")

	if wall_solid_shape:
		wall_solid_shape.set_deferred("disabled", true)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hurtbox_shape:
		hurtbox_shape.set_deferred("disabled", true)

	if broken_edge_shape:
		broken_edge_shape.set_deferred("disabled", false)

	wall_visual.z_index = broken_visual_z_index
