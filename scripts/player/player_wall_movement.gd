extends RefCounted
## Physical wall contacts and per-airtime restrictions; animation playback stays in Player.

enum Pose { NONE, PUSH, HOLD }

var contact_side: int = 0 # -1 = wall on left, +1 = wall on right.
var spent_side: int = 0
var grace_side: int = 0
var grace_time: float = 0.0
var launch_elapsed: float = -1.0
var launch_x: float = 0.0
var sliding: bool = false
var pose: Pose = Pose.NONE
var cue_time: float = 0.0
var cue_ready: bool = false


func tick(delta: float) -> void:
	grace_time = maxf(0.0, grace_time - delta)
	if grace_time <= 0.0:
		grace_side = 0
	if launch_elapsed >= 0.0:
		launch_elapsed += delta


func clear_grace() -> void:
	grace_time = 0.0
	grace_side = 0
	contact_side = 0
	cue_time = 0.0
	cue_ready = false


func advance_cue(delta: float, visible: bool, duration: float) -> void:
	if contact_side == 0 or cue_ready:
		return
	if visible:
		cue_time += delta
		cue_ready = cue_time + 0.000001 >= duration
	else:
		cue_time = 0.0


func cancel_launch() -> void:
	launch_elapsed = -1.0
	sliding = false
	pose = Pose.NONE


func reset(landed: bool = false) -> void:
	clear_grace()
	cancel_launch()
	if landed:
		spent_side = 0


func observe(player: CharacterBody2D, shape: CollisionShape2D, grace_duration: float, use_collisions: bool) -> void:
	if player.is_on_floor():
		reset(true)
		return
	var previous_side := contact_side
	var next_side := 0
	if use_collisions:
		for i in range(player.get_slide_collision_count()):
			var collision := player.get_slide_collision(i)
			var normal := collision.get_normal()
			if absf(normal.x) < 0.95:
				continue
			var side := -int(signf(normal.x))
			if _torso_touches(player, shape, side):
				next_side = side
				# Prefer an actual opposing contact if wedged between two walls.
				if side == -spent_side:
					break
	# A tangent fall may stop reporting slide collisions. Only retain a previously
	# confirmed side, at the body's contact boundary (not a wall-detection radius).
	if next_side == 0 and previous_side != 0 and _torso_touches(player, shape, previous_side):
		next_side = previous_side
	if next_side != 0:
		if next_side != previous_side:
			clear_grace()
		if next_side == -spent_side:
			spent_side = 0
			clear_grace()
		contact_side = next_side
		grace_side = next_side
		grace_time = grace_duration
	else:
		contact_side = 0


func eligible_side() -> int:
	if not cue_ready:
		return 0
	var side := contact_side if contact_side != 0 else grace_side
	if side == spent_side or (contact_side == 0 and grace_time <= 0.0):
		return 0
	return side


func begin_jump(side: int, outward_speed: float) -> void:
	spent_side = side
	clear_grace()
	sliding = false
	launch_elapsed = 0.0
	launch_x = -side * outward_speed
	pose = Pose.PUSH


func protecting(duration: float) -> bool:
	return launch_elapsed >= 0.0 and launch_elapsed < duration


func blend_steering(normal_velocity: float, protection: float, recovery: float) -> float:
	if protecting(protection):
		return launch_x
	var weight := clampf((launch_elapsed - protection) / maxf(recovery, 0.001), 0.0, 1.0)
	weight = smoothstep(0.0, 1.0, weight)
	if weight >= 1.0:
		launch_elapsed = -1.0
	return lerpf(launch_x, normal_velocity, weight)


func apply_slide(player: CharacterBody2D, direction: int, enabled: bool, cap: float, deceleration: float, delta: float) -> void:
	sliding = enabled and not player.is_on_floor() and player.velocity.y > 0.0 and contact_side != 0 and direction == contact_side and launch_elapsed < 0.0
	if sliding:
		if player.velocity.y > cap:
			player.velocity.y = move_toward(player.velocity.y, cap, deceleration * delta)
		pose = Pose.NONE


func ground_nearby(player: CharacterBody2D, shape: CollisionShape2D, distance: float) -> bool:
	var rect := shape.shape as RectangleShape2D
	if rect == null:
		return false
	for x in [-rect.size.x * 0.5 + 2.0, 0.0, rect.size.x * 0.5 - 2.0]:
		var from := shape.to_global(Vector2(x, rect.size.y * 0.5))
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2.DOWN * distance, player.collision_mask, [player.get_rid()])
		var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP) >= cos(player.floor_max_angle):
			return true
	return false


func _torso_touches(player: CharacterBody2D, shape: CollisionShape2D, side: int) -> bool:
	var rect := shape.shape as RectangleShape2D
	if rect == null:
		return false
	# All three torso samples must touch. This excludes isolated top/bottom corners,
	# while allowing separate tiles along a continuous vertical wall.
	for y in [-8.0, 0.0, 8.0]:
		var from := shape.to_global(Vector2(0.0, y))
		var to := shape.to_global(Vector2(side * (rect.size.x * 0.5 + player.safe_margin + 0.02), y))
		var query := PhysicsRayQueryParameters2D.create(from, to, player.collision_mask, [player.get_rid()])
		var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector2).x * side > -0.95:
			return false
	return true
