class_name PlaytestSettings
extends Resource
## Starting progression for direct debug launches of campaign levels.
## Release builds ignore this resource.

enum Mode { AUTOMATIC, CUSTOM, OFF }
enum ResourceStage { NONE, STAMINA, GAS }

## Must match the IDs handled by Player.add_upgrade().
const ABILITY_IDS: Array[String] = [
	"shorts_kick_upgrade",
	"belt_crouch_upgrade",
	"double_jump_upgrade",
	"wall_jump_upgrade",
	"higher_jump_upgrade",
	"run_upgrade",
	"blaster_upgrade",
	"max_gas_upgrade",
]

## Automatic: required chest rewards and completion events from earlier levels.
## Custom: the loadout below, without any chest history.
## Off: ordinary progression.
@export var mode: Mode = Mode.AUTOMATIC
@export var campaign: CampaignCatalog

## Applied at the next fresh launch. Chests stay collectible on top of it.
@export_group("Custom Loadout")
@export var shorts_kick: bool = false
@export var belt_crouch: bool = false
@export var double_jump: bool = false
@export var wall_jump: bool = false
@export var higher_jump: bool = false
@export var run: bool = false
@export var blaster: bool = false
@export var max_gas: bool = false
@export_range(0, 20, 1) var extra_max_hp: int = 0
@export var resource_stage: ResourceStage = ResourceStage.NONE


func get_custom_upgrade_ids() -> Array[String]:
	var toggles: Array[bool] = [shorts_kick, belt_crouch, double_jump, wall_jump,
		higher_jump, run, blaster, max_gas]
	var ids: Array[String] = []
	for i in ABILITY_IDS.size():
		if toggles[i]:
			ids.append(ABILITY_IDS[i])
	return ids
