extends Node

const BASE_MAX_HP := 2

# Runtime progression, following the same lifetime as permanent upgrades.
var stamina_cursed: bool = false
var stamina_curse_reveal_pending: bool = false
var gas_transmuted: bool = false
var gas_reveal_pending: bool = false

var collected_upgrade_ids: Array[String] = []

# Runtime-persistent max HP bonuses.
# Stored separately from collected_upgrade_ids because
# max HP upgrades can stack multiple times.
var bonus_max_hp: int = 0


func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in collected_upgrade_ids


func collect_upgrade(upgrade_id: String) -> void:
	if upgrade_id.is_empty() or has_upgrade(upgrade_id):
		return
	collected_upgrade_ids.append(upgrade_id)


func get_collected_upgrades() -> Array[String]:
	return collected_upgrade_ids.duplicate()


func add_bonus_max_hp(amount: int = 1) -> void:
	bonus_max_hp = maxi(0, bonus_max_hp + amount)


func get_bonus_max_hp() -> int:
	return bonus_max_hp


func get_max_hp() -> int:
	return BASE_MAX_HP + bonus_max_hp


# Runtime-persistent money for the current playthrough (quarters collected).
signal quarters_changed
signal arcade_run_finished(game_id: StringName, result: Dictionary)

var quarters: int = 0:
	set(value):
		quarters = maxi(0, value)
		quarters_changed.emit()


func report_arcade_run_finished(game_id: StringName, result: Dictionary) -> void:
	arcade_run_finished.emit(game_id, result.duplicate(true))


func try_spend_quarter() -> bool:
	if quarters == 0:
		return false
	quarters -= 1
	return true


func add_quarters(amount: int = 1) -> void:
	quarters = maxi(0, quarters + amount)


func get_quarters() -> int:
	return quarters


signal lives_changed(value: int)
const STARTING_LIVES := 3
var lives: int = STARTING_LIVES
var continue_destination: String = ""
var opened_chest_ids: Array[String] = []
var collected_reward_ids: Array[String] = []

func get_lives() -> int:
	return lives

func set_lives(value: int) -> void:
	lives = maxi(0, value)
	lives_changed.emit(lives)

func add_lives(amount: int = 1) -> void:
	if amount > 0:
		set_lives(lives + amount)

func consume_life() -> int:
	set_lives(lives - 1)
	return lives

func has_reward(id: String) -> bool:
	return id in collected_reward_ids

func collect_reward(id: String) -> void:
	if not id.is_empty() and not has_reward(id):
		collected_reward_ids.append(id)

func reset_playthrough() -> void:
	stamina_cursed = false
	stamina_curse_reveal_pending = false
	gas_transmuted = false
	gas_reveal_pending = false
	collected_upgrade_ids.clear()
	bonus_max_hp = 0
	quarters = 0
	opened_chest_ids.clear()
	collected_reward_ids.clear()
	continue_destination = ""
	set_lives(STARTING_LIVES)

# Transaction rollback state; not a disk save format.
func capture_session() -> Dictionary:
	return {"upgrades": collected_upgrade_ids.duplicate(), "hp": bonus_max_hp,
		"gas_transmuted": gas_transmuted, "gas_pending": gas_reveal_pending,
		"stamina_cursed": stamina_cursed, "curse_pending": stamina_curse_reveal_pending,
		"quarters": quarters, "lives": lives, "destination": continue_destination,
		"chests": opened_chest_ids.duplicate(), "rewards": collected_reward_ids.duplicate()}

func restore_session(data: Dictionary) -> void:
	gas_transmuted = data.get("gas_transmuted", false)
	gas_reveal_pending = data.get("gas_pending", false)
	stamina_cursed = data.get("stamina_cursed", false)
	stamina_curse_reveal_pending = data.get("curse_pending", false)
	collected_upgrade_ids.assign(data.upgrades)
	bonus_max_hp = data.hp
	quarters = data.quarters
	continue_destination = data.destination
	opened_chest_ids.assign(data.chests)
	collected_reward_ids.assign(data.rewards)
	set_lives(data.lives)
