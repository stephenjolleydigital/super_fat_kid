class_name CampaignCatalog
extends Resource
## Authoritative campaign order. Never inferred from filenames or level links.

@export var levels: Array[CampaignLevel] = []


func find_index(scene_path: String) -> int:
	for i in levels.size():
		if levels[i] != null and levels[i].scene_path == scene_path:
			return i
	return -1
