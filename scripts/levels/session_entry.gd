extends Node
## Explicit Continue destination, also used by the unscripted boss level.
@export_file("*.tscn") var world_start: String = ""

func _ready() -> void:
	if world_start.is_empty():
		GameState.continue_destination = get_parent().scene_file_path
		push_warning("Empty world_start: Continue restarts this development scene.")
	else:
		GameState.continue_destination = world_start
