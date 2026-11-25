class_name CampaignLevel
extends Resource
## One entry in the ordered campaign catalog.

@export_file("*.tscn") var scene_path: String = ""

## Non-chest progression the player has after finishing this level.
@export_group("Completion Events")
@export var completes_stamina_curse: bool = false
## Requires the stamina curse from this or an earlier level.
@export var completes_gas_transmutation: bool = false
@export var completion_upgrade_ids: Array[String] = []

## Additional abilities for direct debug launches of this level.
@export var playtest_starting_upgrade_ids: Array[String] = []
