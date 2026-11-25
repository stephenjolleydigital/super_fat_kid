extends Area2D

## Set by the spawner before add_child so _ready sees the correct direction.
@export var direction: int = -1
## Outward speed (px/s) along the launch angle.
@export var launch_speed: float = 170.0
## Launch tilt above horizontal; 0 = straight outward. Mirrors with direction.
@export_range(-45.0, 45.0, 0.5) var launch_angle_degrees: float = 8.0
## Seconds of straight flight before gravity kicks in.
@export var gravity_delay: float = 0.25
## Downward acceleration (px/s^2) once gravity_delay has elapsed.
@export var fall_gravity: float = 520.0
@export var max_fall_speed: float = 360.0
## Silent cleanup if the spit never hits anything.
@export var lifetime: float = 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sfx_impact: AudioStreamPlayer2D = get_node_or_null("SFX_Impact") as AudioStreamPlayer2D

var velocity: Vector2 = Vector2.ZERO
var _flight_time: float = 0.0
var _life_timer: float = 0.0
var _splatted: bool = false


func _ready() -> void:
	add_to_group("enemy_attack")
	direction = -1 if direction < 0 else 1
	_life_timer = lifetime

	body_shape_entered.connect(_on_body_shape_entered)
	area_entered.connect(_on_area_entered)
	on_screen.screen_exited.connect(_despawn)

	var launch_angle := deg_to_rad(launch_angle_degrees)
	velocity = Vector2(cos(launch_angle) * float(direction), -sin(launch_angle)) * launch_speed

	# Spit art is authored facing right (trail on the left).
	sprite.flip_h = direction < 0
	_play_if_exists("fly")


func _physics_process(delta: float) -> void:
	if _splatted:
		return

	_life_timer -= delta
	if _life_timer <= 0.0:
		_despawn()
		return

	if _flight_time >= gravity_delay:
		velocity.y = minf(velocity.y + fall_gravity * delta, max_fall_speed)
	_flight_time += delta
	global_position += velocity * delta


func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	if _splatted:
		return

	if has_meta("spawner_body") and body == get_meta("spawner_body"):
		return

	# Only level geometry stops the spit. Actors (player, enemies, apples) are
	# CharacterBody2D; player damage is routed through player_hurtbox only.
	if not _is_solid_geometry(body):
		return

	# One-way platforms only catch the spit from above, like the player.
	if velocity.y <= 0.0 and _is_one_way_shape(body, body_rid, body_shape_index):
		return

	_splat()


func _on_area_entered(area: Area2D) -> void:
	if _splatted:
		return

	if area.is_in_group("player_hurtbox"):
		_splat()


func _is_solid_geometry(body: Node) -> bool:
	return body is TileMapLayer or body is StaticBody2D


func _is_one_way_shape(body: Node, body_rid: RID, body_shape_index: int) -> bool:
	if body is TileMapLayer:
		var layer := body as TileMapLayer
		if layer.tile_set == null:
			return false
		var tile_data := layer.get_cell_tile_data(layer.get_coords_for_body_rid(body_rid))
		if tile_data == null:
			return false
		for physics_layer in layer.tile_set.get_physics_layers_count():
			for polygon in tile_data.get_collision_polygons_count(physics_layer):
				if tile_data.is_collision_polygon_one_way(physics_layer, polygon):
					return true
		return false

	if body is CollisionObject2D:
		var collision_object := body as CollisionObject2D
		var owner_id := collision_object.shape_find_owner(body_shape_index)
		return collision_object.is_shape_owner_one_way_collision_enabled(owner_id)

	return false


func _splat() -> void:
	if _splatted:
		return

	_splatted = true
	velocity = Vector2.ZERO
	# Disable collision immediately; defer group removal so the same-frame
	# Hurtbox area_entered still sees enemy_attack if our signal ran first.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)
	call_deferred("_remove_from_enemy_attack")

	_play_sfx(sfx_impact)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("splat"):
		sprite.play("splat")
		sprite.animation_finished.connect(_on_splat_finished, CONNECT_ONE_SHOT)
	else:
		_finish_splat()


func _on_splat_finished() -> void:
	_finish_splat()


func _finish_splat() -> void:
	# Let the impact cue finish before freeing so it is never cut off; collisions
	# are already disabled above, so waiting does not change gameplay.
	if is_instance_valid(sfx_impact) and sfx_impact.playing:
		await sfx_impact.finished
	queue_free()


## Lifetime / offscreen cleanup: no splat animation or impact SFX.
func _despawn() -> void:
	if _splatted:
		return
	_splatted = true
	queue_free()


func _remove_from_enemy_attack() -> void:
	if is_in_group("enemy_attack"):
		remove_from_group("enemy_attack")


func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if is_instance_valid(p) and p.stream:
		p.play()


func _play_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
