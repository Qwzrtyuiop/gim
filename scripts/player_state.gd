extends Node

signal money_changed(amount: int)
signal energy_changed(amount: int)
signal karma_changed(amount: int)
signal upgrade_changed(upgrade_id: String, level: int)
signal achievement_unlocked(achievement_id: String)

const FIRST_STAGE_TYPE := "easy-morning-chill"
const STAGE_DIFFICULTIES := ["easy", "medium", "long"]
const STAGE_TIMES := ["morning", "noon", "night"]
const STAGE_TRAFFIC_TYPES := ["chill", "normal", "traffic-jam", "busy", "speeders"]

var last_stage_result: Dictionary = {}
var max_energy := 5
var current_stage_type := FIRST_STAGE_TYPE
var current_day := 1
var stage_round := 0
var pending_stage_energy_cost := false
var rng := RandomNumberGenerator.new()

var money := 0:
	set(value):
		money = max(0, value)
		money_changed.emit(money)

var energy := 3:
	set(value):
		energy = clampi(value, 0, max_energy)
		energy_changed.emit(energy)

var karma := 0:
	set(value):
		karma = value
		karma_changed.emit(karma)

var upgrades: Dictionary = {}
var achievements: Dictionary = {}


func _ready() -> void:
	rng.randomize()


func begin_stage_sequence() -> void:
	stage_round = 0
	current_stage_type = FIRST_STAGE_TYPE
	current_day = 1
	pending_stage_energy_cost = false


func get_current_stage_type() -> String:
	if current_stage_type.is_empty():
		current_stage_type = FIRST_STAGE_TYPE
	return current_stage_type


func get_current_day() -> int:
	return max(1, current_day)


func get_current_time_of_day() -> String:
	return _parse_stage_type(get_current_stage_type())["time"]


func can_rest_after_stage() -> bool:
	return get_current_time_of_day() == "morning"


func prepare_stage_start() -> bool:
	if pending_stage_energy_cost:
		return true
	if energy <= 0:
		return false

	spend_energy(1)
	pending_stage_energy_cost = true
	return true


func confirm_stage_started() -> void:
	pending_stage_energy_cost = false


func advance_to_next_stage(skip_to_night := false) -> String:
	var current_parts := _parse_stage_type(get_current_stage_type())
	var next_time := "morning"
	var next_day := get_current_day()

	match current_parts["time"]:
		"morning":
			next_time = "night" if skip_to_night else "noon"
		"noon":
			next_time = "night"
		"night":
			next_time = "morning"
			next_day += 1

	var next_stage := _random_stage_type_for_time(next_time)
	stage_round += 1
	current_day = next_day
	current_stage_type = next_stage
	return current_stage_type


func _random_stage_type_for_time(day_time: String) -> String:
	var difficulty: String = STAGE_DIFFICULTIES[rng.randi_range(0, STAGE_DIFFICULTIES.size() - 1)]
	var traffic_type: String = STAGE_TRAFFIC_TYPES[rng.randi_range(0, STAGE_TRAFFIC_TYPES.size() - 1)]
	return "%s-%s-%s" % [difficulty, day_time, traffic_type]


func _parse_stage_type(type_name: String) -> Dictionary:
	var parts := type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "easy",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name := ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if not STAGE_DIFFICULTIES.has(parts[0]):
		parts[0] = "easy"
	if not STAGE_TIMES.has(parts[1]):
		parts[1] = "morning"
	if not STAGE_TRAFFIC_TYPES.has(traffic_name):
		traffic_name = "chill"

	return {
		"difficulty": parts[0],
		"time": parts[1],
		"traffic": traffic_name,
	}


func add_money(amount: int) -> void:
	money += amount


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false

	money -= amount
	return true


func add_energy(amount: int) -> void:
	energy += amount


func spend_energy(amount: int) -> bool:
	if amount < 0 or energy < amount:
		return false

	energy -= amount
	return true


func add_karma(amount: int) -> void:
	karma += amount


func set_last_stage_result(result: Dictionary) -> void:
	last_stage_result = result.duplicate(true)
	last_stage_result["paid_out"] = false


func get_last_stage_result() -> Dictionary:
	return last_stage_result.duplicate(true)


func claim_last_stage_total() -> int:
	if last_stage_result.is_empty() or bool(last_stage_result.get("paid_out", false)):
		return 0

	var total := int(last_stage_result.get("total", 0))
	add_money(total)
	last_stage_result["paid_out"] = true
	return total


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var safe_level: int = max(0, level)
	upgrades[upgrade_id] = safe_level
	upgrade_changed.emit(upgrade_id, safe_level)


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func unlock_achievement(achievement_id: String) -> void:
	if achievements.get(achievement_id, false):
		return

	achievements[achievement_id] = true
	achievement_unlocked.emit(achievement_id)


func has_achievement(achievement_id: String) -> bool:
	return bool(achievements.get(achievement_id, false))


func reset() -> void:
	money = 0
	energy = 3
	karma = 0
	begin_stage_sequence()
	last_stage_result.clear()
	upgrades.clear()
	achievements.clear()
