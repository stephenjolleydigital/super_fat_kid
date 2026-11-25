extends Node
## Seeds progression for direct debug launches of campaign levels.
## Must be the last autoload: Godot adds the launched scene before any _ready
## runs, so this _ready sees current_scene before the scene's nodes are ready.
## Only the first application scene counts; later scene changes never apply.

const SETTINGS_PATH := "res://resources/debug/playtest_settings.tres"
const Resolver := preload("res://scripts/progression/progression_resolver.gd")

var _launch_consumed: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		return
	var scene := get_tree().current_scene
	if scene != null:
		_consume_launch(scene)
	else:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Autoloads and helper nodes on root are not the application scene.
	if node != get_tree().current_scene:
		return
	get_tree().node_added.disconnect(_on_node_added)
	_consume_launch(node)


func _consume_launch(scene: Node) -> void:
	if _launch_consumed:
		return
	_launch_consumed = true
	var settings := load(SETTINGS_PATH) as PlaytestSettings
	if settings == null:
		push_error("PLAYTEST: missing settings resource " + SETTINGS_PATH)
		return
	if settings.mode == PlaytestSettings.Mode.OFF:
		return
	var path := scene.scene_file_path
	if settings.campaign == null or settings.campaign.find_index(path) < 0:
		print("PLAYTEST: %s is not a campaign level; launch left unchanged." % path)
		return
	var result: Dictionary
	if settings.mode == PlaytestSettings.Mode.CUSTOM:
		result = Resolver.resolve_custom(settings)
	else:
		result = Resolver.resolve_automatic(settings.campaign, path)
	if not result.ok:
		push_error("PLAYTEST: %s Starting with ordinary progression." % result.error)
		return
	_apply(result.data)
	print("PLAYTEST: %s start for %s: upgrades=%s, bonus_max_hp=%d, stamina_cursed=%s, gas=%s, chests=%s" % [
		PlaytestSettings.Mode.keys()[settings.mode], path.get_file(), result.data.upgrades,
		result.data.hp, result.data.stamina_cursed, result.data.gas_transmuted, result.data.chests])


func _apply(snapshot: Dictionary) -> void:
	var session := GameState.capture_session()
	session.upgrades = snapshot.upgrades
	session.hp = snapshot.hp
	session.chests = snapshot.chests
	session.rewards = snapshot.rewards
	session.stamina_cursed = snapshot.stamina_cursed
	session.gas_transmuted = snapshot.gas_transmuted
	session.curse_pending = false
	session.gas_pending = false
	GameState.restore_session(session)
