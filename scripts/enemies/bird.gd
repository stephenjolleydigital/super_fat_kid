extends CharacterBody2D

enum State { DORMANT, FLYING, HURT, FALLING, EXPLODING }

## Art faces right; -1 flies left and 1 flies right.
@export var direction: int = -1
@export var move_speed: float = 80.0
@export var poop_interval: float = 2.0
## Camera margin that wakes the bird before its body enters view.
@export_range(0.0, 512.0, 1.0) var activation_lead_px: float = 32.0
@export var require_screen_activation: bool = true
@export var gravity: float = 800.0

const POOP_SCENE: PackedScene = preload("res://scenes/enemies/Bird_Poop.tscn")
## Safety cleanup for birds killed above pits with no floor.
const DEATH_TIMEOUT: float = 10.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier
@onready var _cleanup_notifier: VisibleOnScreenNotifier2D = $CleanupNotifier
@onready var _poop_spawn: Marker2D = $PoopSpawn
@onready var _sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var _sfx_death_explode: AudioStreamPlayer2D = $SFX_DeathExplode
@onready var _sfx_flap: AudioStreamPlayer2D = $SFX_Flap

var state: State = State.DORMANT
var dead: bool = false
var hitstop_frames: int = 0
var _poop_cooldown: float = 0.0
var _death_time: float = 0.0
var _has_been_visible: bool = false


func _ready() -> void:
	direction = -1 if direction < 0 else 1
	_poop_cooldown = poop_interval
	_apply_facing()
	_setup_screen_activation()
	_screen_notifier.screen_entered.connect(_activate)
	_screen_notifier.screen_exited.connect(_on_activation_screen_exited)
	_cleanup_notifier.screen_entered.connect(_on_cleanup_screen_entered)
	_cleanup_notifier.screen_exited.connect(_on_cleanup_screen_exited)
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_sprite.play(&"fly")
	if not require_screen_activation:
		_activate()
	# Cover birds already visible when the level starts.
	await get_tree().process_frame
	if _cleanup_notifier.is_on_screen():
		_has_been_visible = true
	if _screen_notifier.is_on_screen():
		_activate()


func _setup_screen_activation() -> void:
	var body_rect := _body_shape.shape as RectangleShape2D
	var half := body_rect.size * 0.5 + Vector2.ONE * activation_lead_px
	_screen_notifier.rect = Rect2(_body_shape.position - half, half * 2.0)


func _activate() -> void:
	if state == State.DORMANT:
		state = State.FLYING


func _physics_process(delta: float) -> void:
	if dead:
		_death_time += delta
		if _death_time >= DEATH_TIMEOUT:
			queue_free()
			return
	if hitstop_frames > 0:
		hitstop_frames -= 1
		_sprite.pause()
		return
	if state in [State.HURT, State.FLYING] and not _sprite.is_playing():
		_sprite.play()
	match state:
		State.DORMANT, State.HURT, State.EXPLODING:
			velocity = Vector2.ZERO
		State.FLYING:
			velocity = Vector2(move_speed * float(direction), 0.0)
			move_and_slide()
			_poop_cooldown -= delta
			if _poop_cooldown <= 0.0:
				_poop_cooldown += maxf(poop_interval, 0.01)
				_spawn_poop()
		State.FALLING:
			velocity.x = 0.0
			velocity.y += gravity * delta
			move_and_slide()
			if is_on_floor():
				state = State.EXPLODING
				velocity = Vector2.ZERO
				collision_mask = 0
				_body_shape.set_deferred("disabled", true)
				_sprite.play(&"death_explode")
				_play_death_sound(_sfx_death_explode)


func _apply_facing() -> void:
	_sprite.flip_h = direction < 0
	_poop_spawn.position.x = -absf(_poop_spawn.position.x) * float(direction)


func _spawn_poop() -> void:
	var poop: Node2D = POOP_SCENE.instantiate()
	get_parent().add_child(poop)
	poop.global_position = _poop_spawn.global_position


func apply_hitstop(hitstop_count: int = 2) -> void:
	if state not in [State.FALLING, State.EXPLODING]:
		hitstop_frames = maxi(hitstop_frames, maxi(0, hitstop_count))


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack"):
		return
	if area.name == &"KickHitbox":
		var kick_pivot := area.get_parent()
		var kick_owner: Node = kick_pivot.get_parent() if kick_pivot else null
		if kick_owner != null and kick_owner.has_method("register_kick_damage_target"):
			if not kick_owner.register_kick_damage_target(self):
				return
	_take_damage(1)


func _take_damage(amount: int) -> void:
	if dead or amount <= 0:
		return
	dead = true
	state = State.HURT
	_sfx_flap.stop()
	velocity = Vector2.ZERO
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	# Bodies share the terrain layer in this project. Keep the falling corpse
	# from landing on or pushing the player and other characters.
	for body in get_tree().root.find_children("*", "CharacterBody2D", true, false):
		if body != self:
			add_collision_exception_with(body)
	_sprite.play(&"hurt")
	_play_death_sound(_sfx_hurt)
	_sprite.frame = 0
	# Hold frame zero until the next physics tick so kick/apple feedback can
	# supply hitstop regardless of the order of the two overlap callbacks.
	_sprite.pause()


func _on_sprite_frame_changed() -> void:
	# Frame indices start at zero: frame 1 is the second flight frame.
	if state == State.FLYING and _sprite.animation == &"fly" and _sprite.frame == 1:
		_sfx_flap.pitch_scale = randf_range(0.96, 1.04)
		_sfx_flap.play()


func _play_death_sound(sound: AudioStreamPlayer2D) -> void:
	# Let the sound finish even if animation completion or offscreen cleanup
	# removes the bird. Reparenting preserves its world position and volume.
	sound.reparent(get_parent())
	sound.finished.connect(sound.queue_free, CONNECT_ONE_SHOT)
	sound.play()


func _on_animation_finished() -> void:
	if state == State.HURT and _sprite.animation == &"hurt":
		state = State.FALLING
		collision_mask = 1
		_sprite.play(&"death_fall")
	elif state == State.EXPLODING and _sprite.animation == &"death_explode":
		queue_free()


func _on_cleanup_screen_entered() -> void:
	_has_been_visible = true


func _on_cleanup_screen_exited() -> void:
	if _has_been_visible:
		queue_free()


func _on_activation_screen_exited() -> void:
	# Also clean up an approaching bird if the camera retreats before seeing it.
	if state != State.DORMANT and not _has_been_visible:
		queue_free()
