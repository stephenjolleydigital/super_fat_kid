extends Node2D
## Level 1_6's finale. Assign the finished jingle and cutscene in the Inspector.
@export var world_clear_text: String = "World 2 Cleared"
@export var world_clear_jingle: AudioStream
@export_file("*.tscn") var cutscene_path: String = "res://scenes/levels/World2Entry.tscn"
@export_file("*.tscn") var next_level_path: String = "res://scenes/levels/Level_2_1.tscn"
@export var celebration_seconds: float = 3.2
@export var walk_speed: float = 65.0

@onready var player = $Player
@onready var flag = $FinishFlag
@onready var manhole: Node2D = $ExitManhole
var _started := false
var _walking := false
var _falling := false
var _changing := false

func _ready() -> void:
	flag.hide()
	flag.get_node("PlayerDetector").monitoring = false
	$GnomeBoss.tree_exited.connect(_reveal_flag, CONNECT_ONE_SHOT)
	flag.activated.connect(_start_exit, CONNECT_ONE_SHOT)
	SceneTransition.transition_failed.connect(_recover_transition)

func _reveal_flag() -> void:
	if not is_inside_tree():
		return
	flag.show()
	flag.get_node("PlayerDetector").set_deferred("monitoring", true)

func _start_exit() -> void:
	if _started or player.state == player.State.DEAD:
		return
	_started = true
	# Let any pending upgrade announcement finish before taking over movement.
	while player.curse_sequence_active:
		await get_tree().process_frame
	player.begin_world_exit()
	MusicManager.stop_music()
	$UI.show_world_complete(world_clear_text, world_clear_jingle)
	var jingle: AudioStream = $UI.sfx_level_complete_jingle.stream
	var hold := maxf(celebration_seconds, jingle.get_length() if jingle else 0.0)
	await get_tree().create_timer(hold).timeout
	$UI.level_complete_overlay.hide()
	_walking = true
	player.world_exit_speed = walk_speed

func _physics_process(_delta: float) -> void:
	if _walking and player.global_position.x >= manhole.global_position.x:
		_walking = false
		_falling = true
		player.global_position.x = manhole.global_position.x
		player.world_exit_speed = 0.0
		player.world_exit_falling = true
		player.collision_mask = 0
		manhole.open = true
		manhole.queue_redraw()
	if _falling and player.global_position.y > manhole.global_position.y + 65.0 and not _changing:
		player.hide()
		_changing = true
		# A replacement cutscene can read this and call SceneTransition.change_scene.
		SceneTransition.set_meta(&"world_exit_destination", next_level_path)
		var destination := cutscene_path if ResourceLoader.exists(cutscene_path, "PackedScene") else next_level_path
		if not SceneTransition.change_scene(destination, SceneTransition.Effect.CIRCLE):
			_recover_transition()

func _recover_transition() -> void:
	if not _started:
		return
	# Keep a failed/missing destination playable, with a usable pause/restart menu.
	_falling = false
	player.global_position = flag.global_position + Vector2(0, -28)
	player.velocity = Vector2.ZERO
	player.collision_mask = 1
	player.world_exit_active = false
	player.show()
	$UI.finish_world_complete()
