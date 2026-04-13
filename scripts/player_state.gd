extends Node

signal money_changed(amount: int)
signal energy_changed(amount: int)
signal karma_changed(amount: int)
signal upgrade_changed(upgrade_id: String, level: int)
signal achievement_unlocked(achievement_id: String)

const FIRST_STAGE_TYPE := "short-morning-chill"
const STAGE_DIFFICULTIES := ["short", "medium", "long"]
const STAGE_TIMES := ["morning", "noon", "night"]
const STAGE_TRAFFIC_TYPES := ["chill", "normal", "traffic-jam", "busy", "speeders"]
const DEBT_COLLECTION_INTERVAL_DAYS := 7
const DEBT_GOALS := [1000]
const TRANSITION_RIDE := "ride"
const TRANSITION_REST_TO_NIGHT := "rest_to_night"
const TRANSITION_REST_TO_NEXT_DAY := "rest_to_next_day"
const END_OF_DAY_ENERGY_BONUS := 1
const ESTIMATED_BONUS_TIME_RATIO := 0.35
const REST_ENERGY_BONUSES := {
	TRANSITION_RIDE: 0,
	TRANSITION_REST_TO_NIGHT: 1,
	TRANSITION_REST_TO_NEXT_DAY: 2,
}
const ESTIMATED_STAGE_PROFILES := {
	"short": {
		"target_distance": 1000.0,
		"time_limit": 45.0,
		"fare_php_per_meter": 0.08,
		"time_bonus_php_per_second": 2.0,
	},
	"medium": {
		"target_distance": 1500.0,
		"time_limit": 58.0,
		"fare_php_per_meter": 0.10,
		"time_bonus_php_per_second": 2.0,
	},
	"long": {
		"target_distance": 2300.0,
		"time_limit": 82.0,
		"fare_php_per_meter": 0.12,
		"time_bonus_php_per_second": 2.0,
	},
}
const TIME_EARNINGS_MULTIPLIERS := {
	"morning": 1.0,
	"noon": 1.08,
	"night": 1.22,
}
const TRAFFIC_EARNINGS_MULTIPLIERS := {
	"chill": 0.92,
	"normal": 1.0,
	"traffic-jam": 1.12,
	"busy": 1.24,
	"speeders": 1.34,
}
const MOCK_CHARACTERS := [
	{
		"id": "alma",
		"name": "Alma D.",
		"blurb": "Market regular with a sharp tongue.",
		"first_distance": "short",
		"first_appearance_chance": 0.85,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "benny",
		"name": "Benny R.",
		"blurb": "Former class clown turned fixer.",
		"first_distance": "medium",
		"first_appearance_chance": 0.70,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "cel",
		"name": "Cel V.",
		"blurb": "Clinic aide who notices everything.",
		"first_distance": "short",
		"first_appearance_chance": 0.55,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "dante",
		"name": "Dante K.",
		"blurb": "Night shift mechanic with secrets.",
		"first_distance": "long",
		"first_appearance_chance": 0.65,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "ely",
		"name": "Ely S.",
		"blurb": "Teacher who knew your father well.",
		"first_distance": "short",
		"first_appearance_chance": 0.45,
		"eligible_distances": ["short", "long"],
	},
	{
		"id": "faye",
		"name": "Faye M.",
		"blurb": "Salon owner with city gossip.",
		"first_distance": "medium",
		"first_appearance_chance": 0.80,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "gardo",
		"name": "Gardo T.",
		"blurb": "Debt collector's runner, all smiles.",
		"first_distance": "long",
		"first_appearance_chance": 0.40,
		"eligible_distances": ["long"],
	},
	{
		"id": "hana",
		"name": "Hana P.",
		"blurb": "Student journalist chasing rumors.",
		"first_distance": "medium",
		"first_appearance_chance": 0.60,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "ito",
		"name": "Ito L.",
		"blurb": "Barangay aide with missing files.",
		"first_distance": "long",
		"first_appearance_chance": 0.35,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "jessa",
		"name": "Jessa N.",
		"blurb": "Quiet vendor who keeps showing up.",
		"first_distance": "short",
		"first_appearance_chance": 0.75,
		"eligible_distances": ["short", "medium"],
	},
]

var last_stage_result: Dictionary = {}
var max_energy := 5
var current_stage_type := FIRST_STAGE_TYPE
var current_day := 1
var stage_round := 0
var pending_stage_energy_cost := false
var pending_trip_selection: Dictionary = {}
var current_mock_character_id := ""
var seen_mock_characters: Dictionary = {}
var last_rest_day := 0
var debt_goal_index := 0
var last_debt_collection_day := 0
var run_failed := false
var run_fail_reason := ""
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
	last_rest_day = 0
	debt_goal_index = 0
	last_debt_collection_day = 0
	run_failed = false
	run_fail_reason = ""


func get_current_stage_type() -> String:
	if current_stage_type.is_empty():
		current_stage_type = FIRST_STAGE_TYPE
	return current_stage_type


func get_current_day() -> int:
	return max(1, current_day)


func get_current_debt_goal() -> int:
	if DEBT_GOALS.is_empty():
		return 0

	var goal_index := clampi(debt_goal_index, 0, DEBT_GOALS.size() - 1)
	return int(DEBT_GOALS[goal_index])


func get_days_until_debt_collection(day_number := -1) -> int:
	var effective_day: int = int(day_number) if int(day_number) > 0 else get_current_day()
	var cycle_day: int = ((effective_day - 1) % DEBT_COLLECTION_INTERVAL_DAYS) + 1
	return DEBT_COLLECTION_INTERVAL_DAYS - cycle_day + 1


func get_debt_status_text(day_number := -1) -> String:
	var days_left := get_days_until_debt_collection(day_number)
	var day_label := "day" if days_left == 1 else "days"
	return "Debt Goal: PhP %d     Collector in %d %s" % [
		get_current_debt_goal(),
		days_left,
		day_label,
	]


func get_current_time_of_day() -> String:
	return _parse_stage_type(get_current_stage_type())["time"]


func normalize_transition_mode(transition_mode: String) -> String:
	match transition_mode:
		TRANSITION_REST_TO_NIGHT, TRANSITION_REST_TO_NEXT_DAY:
			return transition_mode
	return TRANSITION_RIDE


func get_next_stage_time(transition_mode: String = TRANSITION_RIDE) -> String:
	var safe_transition_mode := normalize_transition_mode(String(transition_mode))
	var current_time := get_current_time_of_day()

	if safe_transition_mode == TRANSITION_REST_TO_NIGHT and current_time == "morning":
		return "night"
	if safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY and current_time == "noon":
		return "morning"

	match current_time:
		"morning":
			return "noon"
		"noon":
			return "night"
	return "morning"


func can_rest_after_stage() -> bool:
	var current_time := get_current_time_of_day()
	return (current_time == "morning" or current_time == "noon") and last_rest_day != get_current_day()


func has_rested_today() -> bool:
	return last_rest_day == get_current_day()


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


func will_advance_day(transition_mode: String = TRANSITION_RIDE) -> bool:
	var safe_transition_mode := normalize_transition_mode(String(transition_mode))
	if safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY:
		return true
	return safe_transition_mode == TRANSITION_RIDE and get_current_time_of_day() == "night"


func get_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	var safe_transition_mode := normalize_transition_mode(String(transition_mode))
	var energy_bonus := int(REST_ENERGY_BONUSES.get(safe_transition_mode, 0))
	if will_advance_day(safe_transition_mode):
		energy_bonus += END_OF_DAY_ENERGY_BONUS
	return energy_bonus


func advance_to_next_stage(transition_mode: String = TRANSITION_RIDE, selected_difficulty := "", forced_traffic := "") -> String:
	var safe_transition_mode := normalize_transition_mode(String(transition_mode))
	var next_time := get_next_stage_time(safe_transition_mode)
	var next_day := get_current_day()

	if safe_transition_mode != TRANSITION_RIDE:
		last_rest_day = get_current_day()

	if will_advance_day(safe_transition_mode):
		next_day += 1

	var next_stage := _random_stage_type_for_time(next_time, selected_difficulty, forced_traffic)
	stage_round += 1
	current_day = next_day
	current_stage_type = next_stage
	if will_advance_day(safe_transition_mode):
		_resolve_debt_collection_for_day(current_day)
	return current_stage_type


func _random_stage_type_for_time(day_time: String, selected_difficulty := "", forced_traffic := "") -> String:
	var difficulty: String = selected_difficulty
	if difficulty == "easy":
		difficulty = "short"
	if not STAGE_DIFFICULTIES.has(difficulty):
		difficulty = STAGE_DIFFICULTIES[rng.randi_range(0, STAGE_DIFFICULTIES.size() - 1)]
	var traffic_type := forced_traffic if STAGE_TRAFFIC_TYPES.has(forced_traffic) else get_random_stage_traffic_type()
	return build_stage_type(difficulty, day_time, traffic_type)


func _parse_stage_type(type_name: String) -> Dictionary:
	var parts := type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "short",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name := ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if parts[0] == "easy":
		parts[0] = "short"
	if not STAGE_DIFFICULTIES.has(parts[0]):
		parts[0] = "short"
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


func is_run_failed() -> bool:
	return run_failed


func get_run_fail_reason() -> String:
	return run_fail_reason


func set_pending_trip_selection(return_scene: String, transition_mode: String = TRANSITION_RIDE) -> void:
	pending_trip_selection = {
		"return_scene": return_scene,
		"transition_mode": normalize_transition_mode(String(transition_mode)),
	}


func get_pending_trip_selection() -> Dictionary:
	return pending_trip_selection.duplicate(true)


func clear_pending_trip_selection() -> void:
	pending_trip_selection.clear()


func get_mock_characters() -> Array:
	return MOCK_CHARACTERS.duplicate(true)


func get_random_stage_traffic_type() -> String:
	return String(STAGE_TRAFFIC_TYPES[rng.randi_range(0, STAGE_TRAFFIC_TYPES.size() - 1)])


func build_stage_type(difficulty: String, day_time: String, traffic_type: String) -> String:
	var safe_difficulty := difficulty
	if safe_difficulty == "easy":
		safe_difficulty = "short"
	if not STAGE_DIFFICULTIES.has(safe_difficulty):
		safe_difficulty = "short"

	var safe_time := day_time if STAGE_TIMES.has(day_time) else "morning"
	var safe_traffic := traffic_type if STAGE_TRAFFIC_TYPES.has(traffic_type) else "chill"
	return "%s-%s-%s" % [safe_difficulty, safe_time, safe_traffic]


func get_stage_earnings_multiplier(day_time: String, traffic_type: String) -> float:
	var time_multiplier := float(TIME_EARNINGS_MULTIPLIERS.get(day_time, 1.0))
	var traffic_multiplier := float(TRAFFIC_EARNINGS_MULTIPLIERS.get(traffic_type, 1.0))
	return time_multiplier * traffic_multiplier


func apply_stage_earnings_modifiers(fare: int, bonus: int, day_time: String, traffic_type: String) -> Dictionary:
	var multiplier := get_stage_earnings_multiplier(day_time, traffic_type)
	return {
		"fare": roundi(fare * multiplier),
		"bonus": roundi(bonus * multiplier),
		"multiplier": multiplier,
	}


func estimate_stage_earnings(stage_type: String) -> int:
	var parts := _parse_stage_type(stage_type)
	var difficulty_key := String(parts.get("difficulty", "short"))
	var difficulty_profile: Dictionary = ESTIMATED_STAGE_PROFILES[difficulty_key] if ESTIMATED_STAGE_PROFILES.has(difficulty_key) else ESTIMATED_STAGE_PROFILES["short"]
	var base_fare := float(difficulty_profile["target_distance"]) * float(difficulty_profile["fare_php_per_meter"])
	var estimated_bonus_seconds := float(difficulty_profile["time_limit"]) * ESTIMATED_BONUS_TIME_RATIO
	var base_bonus := estimated_bonus_seconds * float(difficulty_profile["time_bonus_php_per_second"])
	var multiplier := get_stage_earnings_multiplier(parts["time"], parts["traffic"])
	return roundi((base_fare + base_bonus) * multiplier)


func _should_collect_debt_for_day(day_number: int) -> bool:
	return day_number > 1 and ((day_number - 1) % DEBT_COLLECTION_INTERVAL_DAYS) == 0


func _resolve_debt_collection_for_day(day_number: int) -> bool:
	if last_debt_collection_day == day_number:
		return not run_failed
	if not _should_collect_debt_for_day(day_number):
		return true

	last_debt_collection_day = day_number
	var goal_amount := get_current_debt_goal()
	if goal_amount <= 0:
		return true
	if money < goal_amount:
		run_failed = true
		run_fail_reason = "Debt collector came for PhP %d on Day %d. Hold R to reset progress." % [
			goal_amount,
			day_number,
		]
		return false

	spend_money(goal_amount)
	if debt_goal_index < DEBT_GOALS.size() - 1:
		debt_goal_index += 1
	return true


func set_current_mock_character(character_id: String) -> void:
	current_mock_character_id = character_id


func get_current_mock_character_id() -> String:
	return current_mock_character_id


func mark_mock_character_seen(character_id: String) -> void:
	seen_mock_characters[character_id] = true


func has_seen_mock_character(character_id: String) -> bool:
	return bool(seen_mock_characters.get(character_id, false))


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
	clear_pending_trip_selection()
	current_mock_character_id = ""
	seen_mock_characters.clear()
	last_rest_day = 0
	debt_goal_index = 0
	last_debt_collection_day = 0
	run_failed = false
	run_fail_reason = ""
	upgrades.clear()
	achievements.clear()
