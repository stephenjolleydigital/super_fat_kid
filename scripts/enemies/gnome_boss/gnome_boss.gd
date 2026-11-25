extends CharacterBody2D

## Pause on stone statue before the eyes glow (seconds).
const INTRO_PAUSE_AFTER_STONE_SEC := 0.5
## Brief idle breath after awaken before the temp cast (seconds).
const IDLE_BEAT_BEFORE_CAST_SEC := 0.25

## TEMP magic rain pattern parameters.
const MAGICRAIN_DROP_COUNT := 5
const MAGICRAIN_HORIZONTAL_SPACING_PX := 64.0
const MAGICRAIN_STAGGER_SEC := 0.35
## Pause after cast_magicrain finishes, before the first drop spawns (seconds).
const MAGICRAIN_POST_CAST_DELAY_SEC := 0.25
const MAGICRAIN_SPAWN_HEIGHT_ABOVE_BOSS_PX := 112.0
const MAGICRAIN_PATTERN_START_X_OFFSET := -128.0
## Shift whole pattern along boss facing (see helper: LEFT=-1, RIGHT=+1).
const MAGICRAIN_PATTERN_FORWARD_OFFSET_PX := 192.0
## Brief hold on release/cast pose after spawn before returning to combat idle.
const MAGICBALL_RELEASE_TO_IDLE_SEC := 0.12
const MAGICSIGIL_CAST_TO_IDLE_SEC := 0.30
const SPELL_IDLE_GAP_SEC := 0.45
const POST_TELEPORT_IDLE_GAP_SEC := 0.95

## TEMP teleport reposition slam test (tune for arena layout).
const TELEPORT_SLAM_TEST_SIDE_OFFSET_X := -380.0
const TELEPORT_SLAM_TEST_AIR_RAISE_Y := -120.0
const TELEPORT_SLAM_TEST_GRAVITY := 700.0
const TELEPORT_SLAM_TEST_FALL_FRAME_GUARD := 720
## TEMP: shallow rect under feet for landing-only damage pulse (enemy_attack group).
const TELEPORT_SLAM_TEST_PULSE_HALF_EXTENTS := Vector2(16.0, 18.0)
const TELEPORT_SLAM_TEST_PULSE_CENTER_Y := 52.0

const MAX_HP := 6
const DAMAGE_LOCKOUT_TIME := 0.35
const HIT_FLASH_COLOR := Color(1.0, 0.15, 0.15, 1.0)
const HIT_FLASH_IN_SEC := 0.02
const HIT_FLASH_OUT_SEC := 0.14
const DEATH_LOOP_SPEEDS := [1.0, 1.5, 2.0]
## Target FPS keeps the flash cadence increasing despite different scene animation speeds.
## Each entry is [sound index, target FPS]; frame indices below are zero-based.
const DEATH_FLASH_STAGES := {
	&"death_start_loop": [0, 5.0],
	&"laugh": [1, 11.0],
	&"cast_final_start": [1, 12.0],
	&"cast_final_release": [1, 12.0],
	&"death_continued_1": [2, 14.0],
	&"death_continued_2": [2, 14.0],
	&"death_continued_3": [3, 16.0],
}
const COMIC_LAUGH := preload("res://scripts/effects/comic_laugh.gd")
## Centers beside the face/hat in the 256px laugh frames, for right-facing art.
const LAUGH_TEXT_OFFSETS := [
	Vector2(62, -37), Vector2(-62, -37),
	Vector2(62, -51), Vector2(-62, -51),
	Vector2(62, -43), Vector2(-62, -43),
]
const DEATH_FLASH_SHADER := preload("res://scripts/enemies/gnome_boss/death_flash.gdshader")
@export_range(0.0, 3.0, 0.05) var final_cast_pause_sec := 0.75

const MAGICBALL_SCENE: PackedScene = preload("res://scenes/enemies/gnome_boss/Gnome_Magicball.tscn")
const MAGICSIGIL_SCENE: PackedScene = preload("res://scenes/enemies/gnome_boss/Gnome_Magicsigil.tscn")
const MAGICRAIN_SCENE: PackedScene = preload("res://scenes/enemies/gnome_boss/Gnome_Magicrain.tscn")
const MAGICFINAL_SCENE: PackedScene = preload("res://scenes/enemies/gnome_boss/Gnome_Magicfinal.tscn")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_origin: Marker2D = $AttackOrigin
@onready var final_attack_origin: Marker2D = $FinalAttackOrigin
@onready var cast_hitbox: Area2D = $CastHitbox
@onready var cast_hitbox_shape: CollisionShape2D = $CastHitbox/CollisionShape2D
@onready var activate_zone: Area2D = $ActivateZone
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

# --- SFX ---
@onready var _sfx_awaken: AudioStreamPlayer2D = $SFX_Awaken
@onready var _sfx_eyes_glow: AudioStreamPlayer2D = $SFX_EyesGlow
@onready var _sfx_cast_magicrain: AudioStreamPlayer2D = $SFX_CastMagicrain
@onready var _sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var _sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var _sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var _sfx_land: AudioStreamPlayer2D = $SFX_Land
@onready var _sfx_magicball_release: AudioStreamPlayer2D = $SFX_MagicballRelease
@onready var _sfx_magicsigil_release: AudioStreamPlayer2D = $SFX_MagicsigilRelease
@onready var _sfx_teleport_out: AudioStreamPlayer2D = $SFX_TeleportOut
@onready var _sfx_teleport_in: AudioStreamPlayer2D = $SFX_TeleportIn
## Each pass uses one clip: normal on frame 2, five semitones lower on frame 4.
@onready var _laugh_players: Array[AudioStreamPlayer2D] = [
	$SFX_Laugh01, $SFX_Laugh01Low,
	$SFX_Laugh02, $SFX_Laugh02Low,
	$SFX_Laugh03, $SFX_Laugh03Low,
]
@onready var _death_flash_players: Array[AudioStreamPlayer2D] = [
	$SFX_DeathFlash01, $SFX_DeathFlash02, $SFX_DeathFlash03, $SFX_DeathFlash04,
]

var _death_flash_material: ShaderMaterial
var _starting_death_animation := false
var _laugh_pass_index := 0

var _activated: bool = false
var _is_dead := false
var _can_take_damage := true
var _hp := MAX_HP
var _is_busy_with_attack := false
var _hit_flash_tween: Tween
var _arena_center_x := 0.0
## Local nonfatal hitstop (Stage 1). Does not alter fatal/death flow.
var hitstop_frames: int = 0
var _hitstop_sprite_paused: bool = false


func _get_ui() -> CanvasLayer:
	return get_tree().get_first_node_in_group("ui") as CanvasLayer


func apply_hitstop(hitstop_count := 2) -> void:
	if _is_dead:
		return
	var clamped_frames: int = maxi(0, hitstop_count)
	hitstop_frames = maxi(hitstop_frames, clamped_frames)
	if hitstop_frames > 0 and animated_sprite and not _hitstop_sprite_paused:
		animated_sprite.pause()
		_hitstop_sprite_paused = true


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return
	if hitstop_frames > 0:
		hitstop_frames -= 1
		if animated_sprite and not _hitstop_sprite_paused:
			animated_sprite.pause()
			_hitstop_sprite_paused = true
		velocity = Vector2.ZERO
		if hitstop_frames > 0:
			return
	if _hitstop_sprite_paused:
		# Resume the same animation that was paused (cast/idle/hurt/etc.).
		animated_sprite.play()
		_hitstop_sprite_paused = false


func _ready() -> void:
	# Canonical facing for the boss is LEFT.
	_face_left()
	_arena_center_x = global_position.x
	animated_sprite.play(&"stone_idle")
	_set_cast_hitbox_active(false)
	activate_zone.area_entered.connect(_on_activate_zone_area_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	animated_sprite.frame_changed.connect(_on_death_frame_changed)


func _on_activate_zone_area_entered(area: Area2D) -> void:
	if _activated or _is_dead:
		return
	if not area.is_in_group("player_hurtbox"):
		return
	_activated = true
	var ui := _get_ui()
	if ui and ui.has_method("show_boss_health"):
		ui.show_boss_health("GNOME", _hp, MAX_HP)
	await _run_boss_activation_sequence()


func _run_boss_activation_sequence() -> void:
	if _is_dead:
		return
	await _play_intro_awaken_sequence()
	if _is_dead:
		return

	while not _is_dead:
		_begin_attack_busy()
		await _cast_magicball_test()
		_end_attack_busy()
		if _is_dead:
			return
		await _idle_gap(SPELL_IDLE_GAP_SEC)
		if _is_dead:
			return

		_begin_attack_busy()
		await _cast_magicsigil_test()
		_end_attack_busy()
		if _is_dead:
			return
		await _idle_gap(SPELL_IDLE_GAP_SEC)
		if _is_dead:
			return

		_begin_attack_busy()
		await _cast_magicrain_test()
		_end_attack_busy()
		if _is_dead:
			return
		await _idle_gap(SPELL_IDLE_GAP_SEC)
		if _is_dead:
			return

		_begin_attack_busy()
		await _teleport_slam_test()
		_end_attack_busy()
		if _is_dead:
			return
		await _idle_gap(POST_TELEPORT_IDLE_GAP_SEC)
		if _is_dead:
			return


func _play_intro_awaken_sequence() -> void:
	if _is_dead:
		return
	# Frozen statue, then eyes, break out, combat idle.
	animated_sprite.play(&"stone_idle")
	await get_tree().create_timer(INTRO_PAUSE_AFTER_STONE_SEC).timeout
	if _is_dead:
		return

	animated_sprite.play(&"eyes_glow")
	_play_sfx(_sfx_eyes_glow)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	animated_sprite.play(&"awaken")
	_play_sfx(_sfx_awaken)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	animated_sprite.play(&"idle")


func _idle_gap(seconds: float) -> void:
	if _is_dead:
		return
	animated_sprite.play(&"idle")
	await get_tree().create_timer(seconds).timeout


## TEMP: first cast/spawn test; remove when a real attack cycle exists.
func _cast_magicball_test() -> void:
	if _is_dead:
		return
	await get_tree().create_timer(IDLE_BEAT_BEFORE_CAST_SEC).timeout
	if _is_dead:
		return

	# Startup: pure wind-up, no projectile yet.
	_set_cast_hitbox_active(true)
	animated_sprite.play(&"cast_magicball_start")
	await animated_sprite.animation_finished
	if _is_dead:
		_set_cast_hitbox_active(false)
		return

	# Release: projectile emerges with the throw motion.
	animated_sprite.play(&"cast_magicball_release")
	_play_sfx(_sfx_magicball_release)
	_spawn_magicball_test()
	await get_tree().create_timer(MAGICBALL_RELEASE_TO_IDLE_SEC).timeout
	_set_cast_hitbox_active(false)
	if _is_dead:
		return

	animated_sprite.play(&"idle")


## TEMP: spawn helper for the first projectile test.
func _spawn_magicball_test() -> void:
	if _is_dead:
		return
	var dir_x := _get_facing_sign()
	var ball := MAGICBALL_SCENE.instantiate()
	ball.direction = Vector2(dir_x, 0.0)
	add_sibling(ball)
	# Temporary: mirror AttackOrigin.x by hand. AnimatedSprite2D.flip_h does not flip Marker2D,
	# so local AttackOrigin does not follow the sprite flip until we parent or sync it properly.
	ball.global_position = global_position + Vector2(attack_origin.position.x * dir_x, attack_origin.position.y)


## TEMP: cast/spawn test for Gnome_Magicsigil; remove when a real attack cycle exists.
func _cast_magicsigil_test() -> void:
	if _is_dead:
		return
	await get_tree().create_timer(IDLE_BEAT_BEFORE_CAST_SEC).timeout
	if _is_dead:
		return

	# Startup holds the baked-in windup visual.
	_set_cast_hitbox_active(true)
	animated_sprite.play(&"cast_magicsigil_start")
	await animated_sprite.animation_finished
	if _is_dead:
		_set_cast_hitbox_active(false)
		return

	# Release has no baked-in sigil, so spawn the real projectile at start.
	animated_sprite.play(&"cast_magicsigil_release")
	_play_sfx(_sfx_magicsigil_release)
	_spawn_magicsigil_test()
	await get_tree().create_timer(MAGICSIGIL_CAST_TO_IDLE_SEC).timeout
	_set_cast_hitbox_active(false)
	if _is_dead:
		return

	animated_sprite.play(&"idle")


## TEMP: spawn helper for the sigil test.
func _spawn_magicsigil_test() -> void:
	if _is_dead:
		return
	var dir_x := _get_facing_sign()
	var sigil := MAGICSIGIL_SCENE.instantiate()
	sigil.direction = Vector2(dir_x, 0.0)
	add_sibling(sigil)
	# Same mirror as magicball: AttackOrigin.x does not follow flip_h yet.
	# Spawn slightly farther out so the real sigil does not overlap baked cast visuals.
	sigil.global_position = global_position + Vector2((attack_origin.position.x + 12.0) * dir_x, attack_origin.position.y)


## TEMP: cast/spawn test for Gnome_Magicrain; remove when a real attack cycle exists.
func _cast_magicrain_test() -> void:
	if _is_dead:
		return
	await get_tree().create_timer(IDLE_BEAT_BEFORE_CAST_SEC).timeout
	if _is_dead:
		return

	_set_cast_hitbox_active(true)
	animated_sprite.play(&"cast_magicrain")
	_play_sfx(_sfx_cast_magicrain)
	await animated_sprite.animation_finished
	_set_cast_hitbox_active(false)
	if _is_dead:
		return
	await get_tree().create_timer(MAGICRAIN_POST_CAST_DELAY_SEC).timeout
	if _is_dead:
		return

	# Staggered left-to-right spawn line above the arena. Always world-space LTR;
	# anchor shifts forward in facing dir so rain does not sit on the boss body.
	var dir_x := _get_facing_sign()
	var base_pos := global_position + Vector2(
		MAGICRAIN_PATTERN_START_X_OFFSET + dir_x * MAGICRAIN_PATTERN_FORWARD_OFFSET_PX,
		-MAGICRAIN_SPAWN_HEIGHT_ABOVE_BOSS_PX
	)
	for i in MAGICRAIN_DROP_COUNT:
		if _is_dead:
			return
		var spawn_pos := base_pos + Vector2(
			float(i) * MAGICRAIN_HORIZONTAL_SPACING_PX, 0.0
		)
		_spawn_magicrain_test(spawn_pos)
		if i == 0 and not _is_dead:
			animated_sprite.play(&"idle")
		await get_tree().create_timer(MAGICRAIN_STAGGER_SEC).timeout
		if _is_dead:
			return


## TEMP: spawn helper for one rain drop.
func _spawn_magicrain_test(global_spawn_position: Vector2) -> void:
	if _is_dead:
		return
	var drop := MAGICRAIN_SCENE.instantiate()
	add_sibling(drop)
	drop.global_position = global_spawn_position


## TEMP: teleport out → fixed opposite-side air spot → flip → teleport in → fall → landing pulse → idle.
func _teleport_slam_test() -> void:
	if _is_dead:
		return
	await get_tree().create_timer(IDLE_BEAT_BEFORE_CAST_SEC).timeout
	if _is_dead:
		return

	var ground_y := global_position.y
	var teleport_dir: float = _get_facing_sign()

	animated_sprite.play(&"teleport_out")
	_play_sfx(_sfx_teleport_out)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	var side_offset: float = absf(TELEPORT_SLAM_TEST_SIDE_OFFSET_X)
	global_position = Vector2(
		global_position.x + (teleport_dir * side_offset),
		ground_y + TELEPORT_SLAM_TEST_AIR_RAISE_Y
	)
	if global_position.x >= _arena_center_x:
		_face_left()
	else:
		_face_right()

	animated_sprite.play(&"teleport_in")
	_play_sfx(_sfx_teleport_in)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	animated_sprite.play(&"jump_descend")
	_play_sfx(_sfx_jump)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	velocity = Vector2.ZERO
	var fall_guard := 0
	while fall_guard < TELEPORT_SLAM_TEST_FALL_FRAME_GUARD:
		# Nonfatal hitstop: hold fall in place until local freeze expires.
		if hitstop_frames > 0 or _hitstop_sprite_paused:
			velocity = Vector2.ZERO
			move_and_slide()
			await get_tree().physics_frame
			if _is_dead:
				return
			continue
		velocity.x = 0.0
		velocity.y += TELEPORT_SLAM_TEST_GRAVITY * get_physics_process_delta_time()
		move_and_slide()
		fall_guard += 1
		if is_on_floor():
			break
		await get_tree().physics_frame
		if _is_dead:
			return

	velocity = Vector2.ZERO
	await _temp_teleport_slam_damage_pulse()
	if _is_dead:
		return

	animated_sprite.play(&"land")
	_play_sfx(_sfx_land)
	await animated_sprite.animation_finished
	if _is_dead:
		return

	if global_position.x >= _arena_center_x:
		_face_left()
	else:
		_face_right()
	animated_sprite.play(&"idle")


## TEMP: one physics tick of enemy_attack overlap under feet; landing only (see Player._on_hurtbox_area_entered).
func _temp_teleport_slam_damage_pulse() -> void:
	if _is_dead:
		return
	var hit := Area2D.new()
	hit.add_to_group("enemy_attack")
	hit.set_meta(&"gnome_teleport_slam_kill", true)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = TELEPORT_SLAM_TEST_PULSE_HALF_EXTENTS * 2.0
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, TELEPORT_SLAM_TEST_PULSE_CENTER_Y)
	hit.add_child(shape_node)
	add_child(hit)
	await get_tree().physics_frame
	hit.queue_free()


func _face_left() -> void:
	animated_sprite.flip_h = true
	_sync_cast_hitbox_facing()


func _face_right() -> void:
	animated_sprite.flip_h = false
	_sync_cast_hitbox_facing()


func _get_facing_sign() -> float:
	return -1.0 if animated_sprite.flip_h else 1.0


func _sync_cast_hitbox_facing() -> void:
	if not is_instance_valid(cast_hitbox_shape):
		return
	# Match AttackOrigin mirroring: flip_h does not move child markers/shapes.
	cast_hitbox_shape.position.x = absf(cast_hitbox_shape.position.x) * _get_facing_sign()


func _set_cast_hitbox_active(active: bool) -> void:
	if not is_instance_valid(cast_hitbox):
		return
	_sync_cast_hitbox_facing()
	if active:
		if not cast_hitbox.is_in_group(&"enemy_attack"):
			cast_hitbox.add_to_group(&"enemy_attack")
	else:
		if cast_hitbox.is_in_group(&"enemy_attack"):
			cast_hitbox.remove_from_group(&"enemy_attack")
	cast_hitbox.set_deferred(&"monitoring", active)
	cast_hitbox.set_deferred(&"monitorable", active)
	if is_instance_valid(cast_hitbox_shape):
		cast_hitbox_shape.set_deferred(&"disabled", not active)


## Boss Damage / Death
func _begin_attack_busy() -> void:
	if _is_dead:
		return
	_is_busy_with_attack = true


func _end_attack_busy() -> void:
	if _is_dead:
		return
	_is_busy_with_attack = false


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if _is_dead:
		return
	if not area.is_in_group("player_attack"):
		return
	if not _can_take_damage:
		return

	# Once per KickHitbox target per swing (blocks hitstop re-arm doubles).
	if area.name == "KickHitbox":
		var kick_pivot := area.get_parent()
		var kick_owner: Node = kick_pivot.get_parent() if kick_pivot else null
		if kick_owner != null and kick_owner.has_method("register_kick_damage_target"):
			if not kick_owner.register_kick_damage_target(self):
				return

	_can_take_damage = false
	take_damage(1)
	_start_damage_lockout()


func _start_damage_lockout() -> void:
	await get_tree().create_timer(DAMAGE_LOCKOUT_TIME).timeout
	if _is_dead:
		return
	_can_take_damage = true


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	_play_sfx(_sfx_hurt)
	_hp = max(_hp - amount, 0)
	var ui := _get_ui()
	if ui and ui.has_method("update_boss_health"):
		ui.update_boss_health(_hp)
	if _hp <= 0:
		await _die()
		return

	_flash_hit()
	if _is_busy_with_attack:
		return

	animated_sprite.play(&"hurt")
	await animated_sprite.animation_finished
	if _is_dead:
		return
	animated_sprite.play(&"idle")


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_can_take_damage = false
	var ui := _get_ui()
	if ui and ui.has_method("hide_boss_health"):
		ui.hide_boss_health()
	if is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	_hit_flash_tween = null
	animated_sprite.modulate = Color.WHITE

	set_physics_process(false)
	velocity = Vector2.ZERO
	hitstop_frames = 0
	_hitstop_sprite_paused = false

	if is_instance_valid(hurtbox_shape):
		hurtbox_shape.set_deferred("disabled", true)
	_set_cast_hitbox_active(false)

	# Keep the body on the arena floor if the fatal hit interrupted the slam.
	for frame in 180:
		velocity.y += TELEPORT_SLAM_TEST_GRAVITY * get_physics_process_delta_time()
		move_and_slide()
		if is_on_floor():
			break
		await get_tree().physics_frame
	velocity = Vector2.ZERO
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)

	# Use a private non-looping copy so each pass ends before another flash starts.
	animated_sprite.sprite_frames = animated_sprite.sprite_frames.duplicate()
	animated_sprite.sprite_frames.set_animation_loop(&"death_start_loop", false)
	_death_flash_material = ShaderMaterial.new()
	_death_flash_material.shader = DEATH_FLASH_SHADER
	animated_sprite.material = _death_flash_material
	animated_sprite.stop()
	animated_sprite.speed_scale = 1.0
	for loop_speed in DEATH_LOOP_SPEEDS:
		await _play_death_part(&"death_start_loop", loop_speed)
	for laugh_pass in 3:
		_laugh_pass_index = laugh_pass
		await _play_death_part(&"laugh")
	await _play_death_part(&"cast_final_start")
	_start_death_animation(&"cast_final_release")
	_spawn_final_spell()
	await animated_sprite.animation_finished
	_start_death_animation(&"cast_final_after_pause")
	await get_tree().create_timer(final_cast_pause_sec).timeout
	for part in [&"death_continued_1", &"death_continued_2", &"death_continued_3", &"death_continued_4"]:
		await _play_death_part(part)
	_start_death_animation(&"death_explode")
	_play_sfx(_sfx_death)
	await animated_sprite.animation_finished
	# Wait for death SFX tail so queue_free does not cut it off.
	# Combat is already disabled (shapes off, _is_dead true) so this only delays the visual despawn.
	if _sfx_death and _sfx_death.playing:
		await _sfx_death.finished
	queue_free()


func _play_death_part(animation_name: StringName, speed_multiplier := 1.0) -> void:
	_start_death_animation(animation_name, speed_multiplier)
	await animated_sprite.animation_finished


func _start_death_animation(animation_name: StringName, speed_multiplier := 1.0) -> void:
	var stage: Array = DEATH_FLASH_STAGES.get(animation_name, [])
	var playback_speed: float = speed_multiplier
	if not stage.is_empty():
		playback_speed *= float(stage[1]) / animated_sprite.sprite_frames.get_animation_speed(animation_name)
	# play() may emit frame_changed during setup; handle frame zero exactly once.
	_starting_death_animation = true
	animated_sprite.stop()
	animated_sprite.play(animation_name, playback_speed)
	_starting_death_animation = false
	_on_death_frame_changed()


func _on_death_frame_changed() -> void:
	if not _is_dead or _starting_death_animation or not _death_flash_material:
		return
	var animation_name := animated_sprite.animation
	var stage: Array = DEATH_FLASH_STAGES.get(animation_name, [])
	var is_flash := not stage.is_empty() and animated_sprite.frame in [0, 2]
	# The cast art has no baked flashes; match the white/red silhouettes used by death frames.
	var is_cast := animation_name in [&"cast_final_start", &"cast_final_release"]
	_death_flash_material.set_shader_parameter(&"flash_amount", 1.0 if is_flash and is_cast else 0.0)
	if is_flash:
		_death_flash_material.set_shader_parameter(&"flash_color",
			Color("edf9ff") if animated_sprite.frame == 0 else Color("d92127"))
		_play_sfx(_death_flash_players[int(stage[0])])
	if animation_name == &"laugh" and animated_sprite.frame in [1, 3]:
		var pair_offset := 0 if animated_sprite.frame == 1 else 1
		var beat_index := _laugh_pass_index * 2 + pair_offset
		_play_sfx(_laugh_players[beat_index])
		_spawn_laugh_text(beat_index)


func _spawn_laugh_text(beat_index: int) -> void:
	var effect := COMIC_LAUGH.new()
	var offset: Vector2 = LAUGH_TEXT_OFFSETS[beat_index]
	offset.x *= _get_facing_sign()
	effect.position = (animated_sprite.position + offset).round()
	effect.outward = signf(offset.x)
	# Sibling of the sprite: follows the boss, but never inherits silhouette flashes
	# or mirrors the letters when flip_h changes. Freed with the boss if interrupted.
	add_child(effect)


func _spawn_final_spell() -> void:
	# Deliberately allowed after _is_dead: the final spell survives its caster.
	var spell := MAGICFINAL_SCENE.instantiate()
	var dir_x := _get_facing_sign()
	spell.direction = Vector2(dir_x, 0.0)
	spell.position = get_parent().to_local(global_position + Vector2(
		final_attack_origin.position.x * dir_x, final_attack_origin.position.y
	))
	add_sibling(spell)


func _flash_hit() -> void:
	if _is_dead:
		return
	if is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(animated_sprite, "modulate", HIT_FLASH_COLOR, HIT_FLASH_IN_SEC)
	_hit_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, HIT_FLASH_OUT_SEC)
	_hit_flash_tween.finished.connect(_on_hit_flash_finished, CONNECT_ONE_SHOT)


func _on_hit_flash_finished() -> void:
	if _is_dead:
		return
	animated_sprite.modulate = Color.WHITE
	_hit_flash_tween = null


## SFX
func _play_sfx(p: AudioStreamPlayer2D) -> void:
	if p and p.stream:
		p.play()
