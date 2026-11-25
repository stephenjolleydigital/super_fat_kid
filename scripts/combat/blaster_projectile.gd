extends Area2D

@export var speed: float = 300.0
@export var flight_lifetime: float = 2.0
var direction: int = 1
var spawn_from: Vector2
var shooter: CollisionObject2D
var impacted: bool = false
var wall_overlap_ticks: int = 0
var leading_edge_x: float = 0.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var impact_sound: AudioStreamPlayer2D = $SFX_Impact

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	anim.animation_finished.connect(_on_animation_finished)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	anim.flip_h = direction < 0
	if direction < 0:
		$CollisionShape2D.position.x = -$CollisionShape2D.position.x
	var hitbox: CollisionShape2D = $CollisionShape2D
	var rectangle: RectangleShape2D = hitbox.shape
	leading_edge_x = hitbox.position.x + direction * rectangle.size.x * 0.5
	anim.play("flight")
	_check_wall(spawn_from, global_position + Vector2(leading_edge_x, 0.0))

func _physics_process(delta: float) -> void:
	if impacted:
		# Give the contact position a physics overlap pass before disabling attacks.
		if wall_overlap_ticks > 0:
			wall_overlap_ticks -= 1
			if wall_overlap_ticks == 0:
				_disable_attack.call_deferred()
		return
	flight_lifetime -= delta
	if flight_lifetime <= 0.0:
		queue_free()
		return
	var next_position: Vector2 = global_position + Vector2(direction * speed * delta, 0.0)
	var leading_offset := Vector2(leading_edge_x, 0.0)
	if not _check_wall(global_position + leading_offset, next_position + leading_offset):
		global_position = next_position

func _check_wall(from: Vector2, to: Vector2) -> bool:
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(shooter):
		excluded.append(shooter.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, to, 0xFFFFFFFF, excluded)
	query.hit_from_inside = true
	# Bodies provide terrain collision; enemies are hit through their Areas instead.
	for _attempt in range(64):
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		if hit.collider is CharacterBody2D:
			excluded.append(hit.rid)
			query.exclude = excluded
			continue
		global_position = hit.position - Vector2(direction * 0.5, 0.0)
		_impact(true)
		return true
	return false

func _on_area_entered(area: Area2D) -> void:
	if not impacted and area.is_in_group("enemy_hurtbox"):
		_impact(false)

func _impact(wall_hit: bool) -> void:
	if impacted:
		return
	impacted = true
	# Let the impact finish even after this projectile's animation frees it.
	impact_sound.reparent(get_parent())
	impact_sound.global_position = global_position
	impact_sound.finished.connect(impact_sound.queue_free, CONNECT_ONE_SHOT)
	impact_sound.play()
	if wall_hit:
		wall_overlap_ticks = 2
		# Keep the attack area at contact, but put the flash outside the wall.
		anim.position.x -= leading_edge_x
	else:
		_disable_attack.call_deferred()
	anim.play("impact")

func _disable_attack() -> void:
	monitoring = false
	monitorable = false
	$CollisionShape2D.disabled = true

func _on_animation_finished() -> void:
	if impacted and anim.animation == "impact":
		queue_free()
