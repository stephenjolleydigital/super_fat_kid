extends Node
## Replace this scene with the future cutscene. Call finish_cutscene at its end.
@export_file("*.tscn") var next_level_path: String = "res://scenes/levels/Level_2_1.tscn"
var _continuing := false

func _ready() -> void:
	SceneTransition.reveal_completed.connect(_on_revealed)
	if not SceneTransition.busy:
		call_deferred("_continue_placeholder")

func _on_revealed(scene: Node, _is_restart: bool) -> void:
	if scene == self:
		_continue_placeholder()

func _continue_placeholder() -> void:
	if _continuing:
		return
	_continuing = true
	await get_tree().create_timer(0.5).timeout
	finish_cutscene()

func finish_cutscene() -> void:
	var destination: String = SceneTransition.get_meta(&"world_exit_destination", next_level_path)
	SceneTransition.change_scene(destination)
