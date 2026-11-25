extends Node2D

## Shared script for normal levels. Owns level-wide concerns only: background
## music, the kill plane, and the hand-off from this level's FinishFlag to the
## completion UI. The flag itself has no knowledge of levels or scene paths.

const FINISH_FLAG_GROUP: StringName = &"finish_flag"
const UI_GROUP: StringName = &"ui"
const PLAYER_NODE_NAME: StringName = &"Player"

@export var level_complete_text: String = ""
@export_file("*.tscn") var next_level_path: String = ""
@export_file("*.ogg") var music_path: String = ""
@export_group("Level Introduction")
@export var level_intro_enabled: bool = false
@export_range(1, 99, 1) var world_number: int = 1
@export_range(1, 99, 1) var level_number: int = 1

var _level_intro: Control


func _ready() -> void:
	if not music_path.is_empty():
		MusicManager.play_music(music_path)
	_connect_finish_flags()
	if level_intro_enabled:
		_level_intro = get_node_or_null("UI/LevelIntro") as Control
		if _level_intro:
			_level_intro.configure(world_number, level_number)
			SceneTransition.reveal_completed.connect(_on_entry_revealed)


func _on_entry_revealed(scene: Node, is_restart: bool) -> void:
	if scene == self and not is_restart and is_instance_valid(_level_intro):
		_level_intro.play_intro()


func _connect_finish_flags() -> void:
	var flag_count: int = 0
	for flag in get_tree().get_nodes_in_group(FINISH_FLAG_GROUP):
		# Group lookup is tree-wide, so keep only the flags belonging to this level.
		if not is_ancestor_of(flag) or not flag.has_signal(&"activated"):
			continue
		flag_count += 1
		flag.activated.connect(_on_finish_flag_activated, CONNECT_ONE_SHOT)
	if flag_count == 0:
		push_warning("%s has no FinishFlag, so the level cannot be completed." % name)


func _on_kill_plane_body_entered(body: Node2D) -> void:
	if body.name == PLAYER_NODE_NAME:
		body._die()


func _on_finish_flag_activated() -> void:
	var ui := get_tree().get_first_node_in_group(UI_GROUP)
	if ui and ui.has_method("show_level_complete"):
		ui.show_level_complete(next_level_path, level_complete_text)
