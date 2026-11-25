extends RefCounted
## Builds a validated progression snapshot without touching GameState.
## Results are {"ok": true, "data": snapshot} or {"ok": false, "error": message}.
## Snapshot keys: upgrades, hp, chests, rewards, stamina_cursed, gas_transmuted.

const CHEST_SCRIPT := preload("res://scripts/objects/treasure_chest.gd")
const UPGRADE_PICKUP_SCRIPT := preload("res://scripts/pickups/pickup_upgrade.gd")
const PIZZA_HEART_SCRIPT := preload("res://scripts/pickups/pickup_pizza_heart.gd")


static func resolve_automatic(catalog: CampaignCatalog, scene_path: String) -> Dictionary:
	var catalog_error := validate_catalog(catalog)
	if not catalog_error.is_empty():
		return _fail(catalog_error)
	var index := catalog.find_index(scene_path)
	if index < 0:
		return _fail("%s is not in the campaign catalog." % scene_path)
	var snapshot := _empty_snapshot()
	for i in index:
		var entry: CampaignLevel = catalog.levels[i]
		var level_error := _collect_level_chests(entry.scene_path, snapshot)
		if not level_error.is_empty():
			return _fail(level_error)
		if entry.completes_stamina_curse:
			snapshot.stamina_cursed = true
		if entry.completes_gas_transmutation:
			if not snapshot.stamina_cursed:
				return _fail("%s completes gas transmutation without the stamina curse." % entry.scene_path)
			snapshot.gas_transmuted = true
		for upgrade_id in entry.completion_upgrade_ids:
			if upgrade_id not in snapshot.upgrades:
				snapshot.upgrades.append(upgrade_id)
	for upgrade_id in catalog.levels[index].playtest_starting_upgrade_ids:
		if upgrade_id not in snapshot.upgrades:
			snapshot.upgrades.append(upgrade_id)
	return _finish(snapshot)


static func resolve_custom(settings: PlaytestSettings) -> Dictionary:
	var snapshot := _empty_snapshot()
	snapshot.upgrades = settings.get_custom_upgrade_ids()
	snapshot.hp = settings.extra_max_hp
	snapshot.stamina_cursed = settings.resource_stage != PlaytestSettings.ResourceStage.NONE
	snapshot.gas_transmuted = settings.resource_stage == PlaytestSettings.ResourceStage.GAS
	return _finish(snapshot)


static func validate_catalog(catalog: CampaignCatalog) -> String:
	if catalog == null or catalog.levels.is_empty():
		return "The campaign catalog is missing or empty."
	var seen: Array[String] = []
	for i in catalog.levels.size():
		var entry: CampaignLevel = catalog.levels[i]
		if entry == null or entry.scene_path.is_empty():
			return "Campaign catalog entry %d has no scene." % i
		if entry.scene_path in seen:
			return "Campaign catalog lists %s twice." % entry.scene_path
		if not ResourceLoader.exists(entry.scene_path, "PackedScene"):
			return "Campaign catalog scene does not exist: %s" % entry.scene_path
		for upgrade_id in entry.completion_upgrade_ids:
			if upgrade_id not in PlaytestSettings.ABILITY_IDS:
				return "%s completion event has unknown upgrade ID '%s'." % [entry.scene_path, upgrade_id]
		for upgrade_id in entry.playtest_starting_upgrade_ids:
			if upgrade_id not in PlaytestSettings.ABILITY_IDS:
				return "%s playtest start has unknown upgrade ID '%s'." % [entry.scene_path, upgrade_id]
		seen.append(entry.scene_path)
	return ""


static func _collect_level_chests(scene_path: String, snapshot: Dictionary) -> String:
	var packed := load(scene_path) as PackedScene
	if packed == null or not packed.can_instantiate():
		return "Cannot load campaign level %s." % scene_path
	# Inspected off-tree: no _ready, sounds, or collection callbacks run.
	var level := packed.instantiate()
	var chests: Array[Node] = []
	_find_chests(level, chests)
	var error := ""
	for chest in chests:
		if not chest.required_for_progression:
			continue
		error = _collect_chest(chest, scene_path, snapshot)
		if not error.is_empty():
			break
	level.free()
	return error


static func _find_chests(node: Node, out: Array[Node]) -> void:
	if node.get_script() == CHEST_SCRIPT:
		out.append(node)
	for child in node.get_children():
		_find_chests(child, out)


static func _collect_chest(chest: Node, scene_path: String, snapshot: Dictionary) -> String:
	var chest_id: String = chest.chest_id.strip_edges()
	var where := "%s chest '%s'" % [scene_path, chest.name]
	if chest_id.is_empty():
		return where + " has no chest_id."
	var reward_id: String = chest.persistence_id()
	if reward_id in snapshot.rewards:
		return where + " duplicates reward identity '%s'." % reward_id
	if chest.reward_scene == null:
		return where + " has no reward_scene."
	var reward: Node = chest.reward_scene.instantiate()
	var error := ""
	if reward.get_script() == PIZZA_HEART_SCRIPT:
		snapshot.hp += 1
	elif reward.get_script() == UPGRADE_PICKUP_SCRIPT:
		if reward.transmutes_stamina or reward.requires_stamina_curse:
			error = where + " has an unsupported staged reward."
		elif reward.upgrade_id not in PlaytestSettings.ABILITY_IDS:
			error = where + " has unknown upgrade ID '%s'." % reward.upgrade_id
		elif reward.upgrade_id in snapshot.upgrades:
			push_warning(where + " grants '%s' again." % reward.upgrade_id)
		else:
			snapshot.upgrades.append(reward.upgrade_id)
	else:
		error = where + " has an unsupported reward: %s." % chest.reward_scene.resource_path
	reward.free()
	if error.is_empty():
		snapshot.chests.append(chest_id)
		snapshot.rewards.append(reward_id)
	return error


static func _finish(snapshot: Dictionary) -> Dictionary:
	for upgrade_id in snapshot.upgrades:
		if upgrade_id not in PlaytestSettings.ABILITY_IDS:
			return _fail("Unknown upgrade ID '%s'." % upgrade_id)
	if snapshot.gas_transmuted and not snapshot.stamina_cursed:
		return _fail("Gas transmutation requires the stamina curse.")
	if snapshot.hp < 0:
		return _fail("Additional max HP cannot be negative (%d)." % snapshot.hp)
	return {"ok": true, "data": snapshot}


static func _empty_snapshot() -> Dictionary:
	return {"upgrades": [] as Array[String], "hp": 0, "chests": [] as Array[String],
		"rewards": [] as Array[String], "stamina_cursed": false, "gas_transmuted": false}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
