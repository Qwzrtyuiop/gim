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
var stage_round := 0
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


func get_current_stage_type() -> String:
	if current_stage_type.is_empty():
		current_stage_type = FIRST_STAGE_TYPE
	return current_stage_type


func advance_to_random_stage() -> String:
	var previous_stage := get_current_stage_type()
	var next_stage := previous_stage
	for _attempt in range(8):
		next_stage = _random_stage_type()
		if next_stage != previous_stage:
			break

	stage_round += 1
	current_stage_type = next_stage
	return current_stage_type


func _random_stage_type() -> String:
	var difficulty: String = STAGE_DIFFICULTIES[rng.randi_range(0, STAGE_DIFFICULTIES.size() - 1)]
	var day_time: String = STAGE_TIMES[rng.randi_range(0, STAGE_TIMES.size() - 1)]
	var traffic_type: String = STAGE_TRAFFIC_TYPES[rng.randi_range(0, STAGE_TRAFFIC_TYPES.size() - 1)]
	return "%s-%s-%s" % [difficulty, day_time, traffic_type]


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
