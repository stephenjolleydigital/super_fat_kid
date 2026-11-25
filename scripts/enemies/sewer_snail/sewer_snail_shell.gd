extends CharacterBody2D

@export var direction: int = 1
@export var gravity: float = 800.0
@export var friction: float = 300.0
@export var kick_push_speed: float = 180.0
## A movable shell gives less resistance than a fixed chest or wall.
@export_range(0.1, 1.0, 0.05) var player_recoil_strength: float = 0.7

## Minimum ground speed (px/s) before the shell counts as "sliding".
const MIN_SLIDE_SPEED := 8.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var sfx_shell_slide: AudioStreamPlayer2D = get_node_or_null("SFX_ShellSlide") as AudioStreamPlayer2D

var hitstop_frames: int = 0
var _spawn_overlapping_players: Array[PhysicsBody2D] = []


func _ready() -> void:
	direction = -1 if direction < 0 else 1

	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Snail family art is authored facing right; direction -1 mirrors it.
	# Mirroring the authored offset keeps the shell centered on the origin
	# so it matches the snail's final death frame for either facing.
	sprite.flip_h = direction < 0
	if direction < 0:
		sprite.offset.x = -sprite.offset.x

	# A newly solid shell must not eject a player already inside its body.
	for player in get_tree().get_nodes_in_group("player"):
		if player is PhysicsBody2D and _overlaps_player_body(player):
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)
			_spawn_overlapping_players.append(player)


func _overlaps_player_body(player: PhysicsBody2D) -> bool:
	var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not player_shape or player_shape.disabled or player_shape.shape == null:
		return false
	return body_shape.shape.collide(body_shape.global_transform, player_shape.shape, player_shape.global_transform)


func _update_spawn_collisions() -> void:
	for player in _spawn_overlapping_players.duplicate():
		if not is_instance_valid(player):
			_spawn_overlapping_players.erase(player)
		elif not _overlaps_player_body(player):
			remove_collision_exception_with(player)
			player.remove_collision_exception_with(self)
			_spawn_overlapping_players.erase(player)


func _exit_tree() -> void:
	for player in _spawn_overlapping_players:
		if is_instance_valid(player):
			player.remove_collision_exception_with(self)
	_spawn_overlapping_players.clear()


func apply_hitstop(hitstop_count := 2) -> void:
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)


func push(push_velocity: Vector2) -> void:
	velocity = push_velocity


func _physics_process(delta: float) -> void:
	_update_spawn_collisions()
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_shell_slide_sfx()


func _update_shell_slide_sfx() -> void:
	if not is_instance_valid(sfx_shell_slide) or sfx_shell_slide.stream == null:
		return
	# Loop only while genuinely sliding on the ground; starts once on entry,
	# re-triggers after the sample ends, and stops on stop / leaving the floor.
	var moving := is_on_floor() and absf(velocity.x) > MIN_SLIDE_SPEED
	if moving:
		if not sfx_shell_slide.playing:
			sfx_shell_slide.play()
	elif sfx_shell_slide.playing:
		sfx_shell_slide.stop()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_attack"):
		return

	# Re-arming the hitbox after hitstop must not push this shell twice in one swing.
	var kick_player: Node = null
	if area.name == &"KickHitbox":
		var kick_pivot := area.get_parent()
		kick_player = kick_pivot.get_parent() if kick_pivot else null
		if kick_player and kick_player.has_method("register_kick_damage_target") and kick_player.get("kick_hitbox") == area:
			if not kick_player.call("register_kick_damage_target", self):
				return
		else:
			kick_player = null

	# Kicks push the shell away from the attacker instead of damaging it.
	var push_dir: float = signf(global_position.x - area.global_position.x)
	if push_dir == 0.0:
		push_dir = float(direction)
	push(Vector2(push_dir * kick_push_speed, velocity.y))
	if kick_player and kick_player.has_method("apply_solid_kick_recoil"):
		kick_player.call("apply_solid_kick_recoil", area, player_recoil_strength)
