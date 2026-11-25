class_name CombatTuning
extends RefCounted

## Temporary shared combat hitstop tuning.
## Change these constants only to retune kick vs apple independently.
const PLAYER_KICK_HITSTOP_FRAMES: int = 7
const APPLE_HITSTOP_FRAMES: int = 7

## Shared player-kick knockback base (px/s and px/s²).
## Final speed = base × player_multiplier × enemy_resistance.
## Player perk / per-enemy resistance stay at 1.0 until those systems exist.
const PLAYER_KICK_KNOCKBACK_SPEED: float = 140.0
const PLAYER_KICK_KNOCKBACK_DECELERATION: float = 320.0

## Baseline push applied to the player by enemy attacks (px/s).
## Enemy components can override these speeds; hazards retain their own response.
const ENEMY_HIT_KNOCKBACK_SPEED: float = 260.0
const ENEMY_HIT_KNOCKBACK_UP_SPEED: float = 120.0


static func enemy_hit_knockback(
	player_position: Vector2,
	attack_origin: Vector2,
	fallback_direction: float,
	sideways_speed: float = ENEMY_HIT_KNOCKBACK_SPEED,
	upward_speed: float = ENEMY_HIT_KNOCKBACK_UP_SPEED
) -> Vector2:
	var push_direction := signf(player_position.x - attack_origin.x)
	if is_zero_approx(push_direction):
		push_direction = fallback_direction
	return Vector2(push_direction * sideways_speed, -upward_speed)


## Priority: enemy/custom provider, explicit hazard vector, original default.
## Providers receive the player's current position and centered-hit fallback direction.
static func resolve_player_hurt_knockback(
	attack_area: Area2D,
	player_position: Vector2,
	fallback_direction: float,
	current_vertical_speed: float
) -> Vector2:
	if is_instance_valid(attack_area):
		var provider: Variant = null
		if attack_area.has_meta(&"hurt_knockback_provider"):
			provider = attack_area.get_meta(&"hurt_knockback_provider")
		if provider is Callable and provider.is_valid():
			var provided: Variant = provider.call(player_position, fallback_direction)
			if provided is Vector2:
				return provided
		if attack_area.has_meta(&"hurt_knockback"):
			var explicit_knockback: Variant = attack_area.get_meta(&"hurt_knockback")
			if explicit_knockback is Vector2:
				return explicit_knockback
	return Vector2(fallback_direction * 80.0, minf(current_vertical_speed, -120.0))


## Resolves kick knockback speed without a shared manager.
## Pass future perk multiplier and per-enemy resistance when those exist.
static func resolve_kick_knockback_speed(
	player_multiplier: float = 1.0,
	enemy_resistance: float = 1.0
) -> float:
	return PLAYER_KICK_KNOCKBACK_SPEED * player_multiplier * enemy_resistance
