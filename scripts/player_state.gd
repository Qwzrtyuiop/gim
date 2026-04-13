extends Node

const Day02StationBillPayload := preload("res://scripts/story/payloads/day_02_station_bill.gd")
const GameSaveResource := preload("res://scripts/save/game_save_resource.gd")

signal money_changed(amount: int)
signal energy_changed(amount: int)
signal gas_changed(amount: int)
signal karma_changed(amount: int)
signal upgrade_changed(upgrade_id: String, level: int)
signal achievement_unlocked(achievement_id: String)

const FIRST_STAGE_TYPE := "short-morning-chill"
const STAGE_DIFFICULTIES := ["short", "medium", "long"]
const STAGE_TIMES := ["morning", "noon", "night"]
const STAGE_TRAFFIC_TYPES := ["chill", "normal", "traffic-jam", "busy", "speeders"]
const DEBT_COLLECTION_INTERVAL_DAYS := 7
const TOTAL_DEBT_GOAL := 50000
const WEEKLY_DEBT_GOALS := [1000]
const DEFAULT_STARTING_GAS := 10
const DEFAULT_GAS_PRICE := 70
const STORY_SCENE := "res://scenes/story_scene.tscn"
const TRANSITION_RIDE := "ride"
const TRANSITION_REST_TO_NIGHT := "rest_to_night"
const TRANSITION_REST_TO_NEXT_DAY := "rest_to_next_day"
const TRANSITION_SLEEP_TO_NEXT_DAY := "sleep_to_next_day"
const STORY_TRIGGER_DAY_END := "day_end"
const STORY_TRIGGER_SLEEP_MIDPOINT := "sleep_midpoint"
const STORY_TRIGGER_DAY_START := "day_start"
const STORY_TRIGGER_STAGE_COMPLETE := "stage_complete"
const END_OF_DAY_ENERGY_BONUS := 1
const NIGHT_SLEEP_ENERGY_BONUS := 1
const ESTIMATED_BONUS_TIME_RATIO := 0.35
const TRIP_GAS_COSTS := {
	"short": 1,
	"medium": 2,
	"long": 3,
}
const STAGE_DISTANCE_RANGES := {
	"short": Vector2(800.0, 1200.0),
	"medium": Vector2(1200.0, 1800.0),
	"long": Vector2(1800.0, 2800.0),
}
const ACHIEVEMENT_ORDER := [
	"mapagsamantala",
]
const ACHIEVEMENT_DEFINITIONS := {
	"mapagsamantala": {
		"title": "Mapagsamantala",
		"subtitle": "Opportunistic",
		"description": "Taking advantage when the opportunity presents itself\nespecially when it costs someone else more than it costs you.\n\nJohn saw the opening and took it.\nWhether it was right or not didn’t matter, he needed the money more than them.",
	},
}
const SAVE_PATH := "user://progress_save.tres"
const SAVE_VERSION := 1
const REST_ENERGY_BONUSES := {
	TRANSITION_RIDE: 0,
	TRANSITION_REST_TO_NIGHT: 1,
	TRANSITION_REST_TO_NEXT_DAY: 2,
	TRANSITION_SLEEP_TO_NEXT_DAY: 0,
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
var max_gas := DEFAULT_STARTING_GAS
var current_stage_type := FIRST_STAGE_TYPE
var current_day := 1
var stage_round := 0
var pending_stage_energy_cost := false
var pending_trip_selection: Dictionary = {}
var pending_story: Dictionary = {}
var pending_sleep_transition_state: Dictionary = {}
var pending_gameplay_entry_fade_duration := 0.0
var current_mock_character_id := ""
var seen_mock_characters: Dictionary = {}
var last_rest_day := 0
var debt_goal_index := 0
var last_debt_collection_day := 0
var remaining_debt := TOTAL_DEBT_GOAL
var run_failed := false
var run_fail_reason := ""
var rng := RandomNumberGenerator.new()
var story_triggers: Array[Dictionary] = []
var consumed_story_triggers: Dictionary = {}
var last_seen_story_sections: Dictionary = {}
var last_seen_story_id := ""
var resume_scene_path := ""
var _is_loading_save := false

var money := 0:
	set(value):
		money = max(0, value)
		money_changed.emit(money)
		save_progress()

var energy := 3:
	set(value):
		energy = clampi(value, 0, max_energy)
		energy_changed.emit(energy)
		save_progress()

var gas := DEFAULT_STARTING_GAS:
	set(value):
		gas = clampi(value, 0, max_gas)
		gas_changed.emit(gas)
		save_progress()

var gas_price := DEFAULT_GAS_PRICE

var karma := 0:
	set(value):
		karma = value
		karma_changed.emit(karma)
		save_progress()

var upgrades: Dictionary = {}
var achievements: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	_load_progress()


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var loaded_resource := ResourceLoader.load(SAVE_PATH)
	if not loaded_resource is GameSaveResource:
		return

	var save_resource := loaded_resource as GameSaveResource
	var save_data: Dictionary = save_resource.data.duplicate(true)
	if save_data.is_empty():
		return

	_is_loading_save = true
	money = int(save_data.get("money", money))
	max_energy = int(save_data.get("max_energy", max_energy))
	energy = int(save_data.get("energy", energy))
	max_gas = int(save_data.get("max_gas", max_gas))
	gas = int(save_data.get("gas", gas))
	gas_price = int(save_data.get("gas_price", gas_price))
	karma = int(save_data.get("karma", karma))
	current_stage_type = str(save_data.get("current_stage_type", current_stage_type))
	current_day = int(save_data.get("current_day", current_day))
	stage_round = int(save_data.get("stage_round", stage_round))
	pending_stage_energy_cost = bool(save_data.get("pending_stage_energy_cost", pending_stage_energy_cost))
	pending_trip_selection = Dictionary(save_data.get("pending_trip_selection", {})).duplicate(true)
	pending_story = Dictionary(save_data.get("pending_story", {})).duplicate(true)
	pending_sleep_transition_state = Dictionary(save_data.get("pending_sleep_transition_state", {})).duplicate(true)
	pending_gameplay_entry_fade_duration = float(save_data.get("pending_gameplay_entry_fade_duration", pending_gameplay_entry_fade_duration))
	current_mock_character_id = str(save_data.get("current_mock_character_id", current_mock_character_id))
	seen_mock_characters = Dictionary(save_data.get("seen_mock_characters", {})).duplicate(true)
	last_rest_day = int(save_data.get("last_rest_day", last_rest_day))
	debt_goal_index = int(save_data.get("debt_goal_index", debt_goal_index))
	last_debt_collection_day = int(save_data.get("last_debt_collection_day", last_debt_collection_day))
	remaining_debt = int(save_data.get("remaining_debt", remaining_debt))
	run_failed = bool(save_data.get("run_failed", run_failed))
	run_fail_reason = str(save_data.get("run_fail_reason", run_fail_reason))
	last_stage_result = Dictionary(save_data.get("last_stage_result", {})).duplicate(true)
	story_triggers.clear()
	var saved_story_triggers: Array = save_data.get("story_triggers", [])
	for trigger_data in saved_story_triggers:
		if trigger_data is Dictionary:
			story_triggers.append((trigger_data as Dictionary).duplicate(true))
	consumed_story_triggers = Dictionary(save_data.get("consumed_story_triggers", {})).duplicate(true)
	upgrades = Dictionary(save_data.get("upgrades", {})).duplicate(true)
	achievements = Dictionary(save_data.get("achievements", {})).duplicate(true)
	last_seen_story_sections = Dictionary(save_data.get("last_seen_story_sections", {})).duplicate(true)
	last_seen_story_id = str(save_data.get("last_seen_story_id", ""))
	resume_scene_path = str(save_data.get("resume_scene_path", ""))
	_is_loading_save = false


func save_progress() -> void:
	if _is_loading_save:
		return

	var save_resource := GameSaveResource.new()
	save_resource.version = SAVE_VERSION
	save_resource.data = {
		"money": money,
		"max_energy": max_energy,
		"energy": energy,
		"max_gas": max_gas,
		"gas": gas,
		"gas_price": gas_price,
		"karma": karma,
		"current_stage_type": current_stage_type,
		"current_day": current_day,
		"stage_round": stage_round,
		"pending_stage_energy_cost": pending_stage_energy_cost,
		"pending_trip_selection": pending_trip_selection.duplicate(true),
		"pending_story": pending_story.duplicate(true),
		"pending_sleep_transition_state": pending_sleep_transition_state.duplicate(true),
		"pending_gameplay_entry_fade_duration": pending_gameplay_entry_fade_duration,
		"current_mock_character_id": current_mock_character_id,
		"seen_mock_characters": seen_mock_characters.duplicate(true),
		"last_rest_day": last_rest_day,
		"debt_goal_index": debt_goal_index,
		"last_debt_collection_day": last_debt_collection_day,
		"remaining_debt": remaining_debt,
		"run_failed": run_failed,
		"run_fail_reason": run_fail_reason,
		"last_stage_result": last_stage_result.duplicate(true),
		"story_triggers": story_triggers.duplicate(true),
		"consumed_story_triggers": consumed_story_triggers.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"achievements": achievements.duplicate(true),
		"last_seen_story_sections": last_seen_story_sections.duplicate(true),
		"last_seen_story_id": last_seen_story_id,
		"resume_scene_path": resume_scene_path,
	}
	ResourceSaver.save(save_resource, SAVE_PATH)


func set_last_seen_story_section(story_id: String, section_index: int) -> void:
	var safe_story_id := str(story_id).strip_edges()
	if safe_story_id.is_empty():
		return
	last_seen_story_id = safe_story_id
	last_seen_story_sections[safe_story_id] = max(-1, section_index)
	save_progress()


func get_last_seen_story_section(story_id: String) -> int:
	var safe_story_id := str(story_id).strip_edges()
	if safe_story_id.is_empty():
		return -1
	return int(last_seen_story_sections.get(safe_story_id, -1))


func get_last_seen_story_id() -> String:
	return last_seen_story_id


func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func set_resume_scene(scene_path: String) -> void:
	var safe_scene_path := str(scene_path).strip_edges()
	if safe_scene_path.is_empty() or resume_scene_path == safe_scene_path:
		return
	resume_scene_path = safe_scene_path
	save_progress()


func get_resume_scene() -> String:
	return resume_scene_path


func begin_stage_sequence() -> void:
	stage_round = 0
	current_stage_type = FIRST_STAGE_TYPE
	current_day = 1
	pending_stage_energy_cost = false
	clear_pending_trip_selection()
	clear_pending_story()
	clear_pending_sleep_transition_state()
	clear_pending_gameplay_entry_fade()
	last_rest_day = 0
	debt_goal_index = 0
	last_debt_collection_day = 0
	remaining_debt = TOTAL_DEBT_GOAL
	run_failed = false
	run_fail_reason = ""
	_reset_story_triggers()
	save_progress()


func get_current_stage_type() -> String:
	if current_stage_type.is_empty():
		current_stage_type = FIRST_STAGE_TYPE
	return current_stage_type


func get_current_day() -> int:
	return max(1, current_day)


func get_current_debt_goal() -> int:
	return get_current_weekly_goal()


func get_total_debt_goal() -> int:
	return max(0, remaining_debt)


func get_current_weekly_goal() -> int:
	if remaining_debt <= 0:
		return 0
	if WEEKLY_DEBT_GOALS.is_empty():
		return 0

	var goal_index := clampi(debt_goal_index, 0, WEEKLY_DEBT_GOALS.size() - 1)
	return mini(int(WEEKLY_DEBT_GOALS[goal_index]), remaining_debt)


func get_days_until_debt_collection(day_number := -1) -> int:
	var effective_day: int = int(day_number) if int(day_number) > 0 else get_current_day()
	var cycle_day: int = ((effective_day - 1) % DEBT_COLLECTION_INTERVAL_DAYS) + 1
	return DEBT_COLLECTION_INTERVAL_DAYS - cycle_day + 1


func get_stage_distance_range(difficulty: String) -> Vector2:
	var safe_difficulty := difficulty if STAGE_DIFFICULTIES.has(difficulty) else "short"
	return STAGE_DISTANCE_RANGES.get(safe_difficulty, STAGE_DISTANCE_RANGES["short"])


func get_stage_distance_average(difficulty: String) -> float:
	var distance_range := get_stage_distance_range(difficulty)
	return (distance_range.x + distance_range.y) * 0.5


func roll_stage_target_distance(difficulty: String) -> float:
	var distance_range := get_stage_distance_range(difficulty)
	return rng.randf_range(distance_range.x, distance_range.y)


func get_debt_status_text(day_number := -1) -> String:
	return "WEEKLY GOAL: PhP %d\nDebt Remaining: PhP %d     %s" % [
		get_current_weekly_goal(),
		get_total_debt_goal(),
		get_debt_due_text(day_number),
	]


func get_debt_due_text(day_number := -1) -> String:
	var days_left := get_days_until_debt_collection(day_number)
	if days_left <= 0:
		return "Collection Day."
	var day_label := "day" if days_left == 1 else "days"
	return "Debt due in %d %s" % [
		days_left,
		day_label,
	]


func get_current_time_of_day() -> String:
	return _parse_stage_type(get_current_stage_type())["time"]


func normalize_transition_mode(transition_mode: String) -> String:
	match transition_mode:
		TRANSITION_REST_TO_NIGHT, TRANSITION_REST_TO_NEXT_DAY, TRANSITION_SLEEP_TO_NEXT_DAY:
			return transition_mode
	return TRANSITION_RIDE


func get_next_stage_time(transition_mode: String = TRANSITION_RIDE) -> String:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var current_time := get_current_time_of_day()

	if safe_transition_mode == TRANSITION_REST_TO_NIGHT and current_time == "morning":
		return "night"
	if safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY and current_time == "noon":
		return "morning"
	if safe_transition_mode == TRANSITION_SLEEP_TO_NEXT_DAY:
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


func get_transition_display_day(transition_mode: String = TRANSITION_RIDE) -> int:
	var display_day := get_current_day()
	if will_advance_day(transition_mode):
		display_day += 1
	return max(1, display_day)


func get_trip_gas_cost(stage_descriptor := "") -> int:
	var difficulty_key := _difficulty_from_stage_descriptor(str(stage_descriptor))
	return int(TRIP_GAS_COSTS.get(difficulty_key, TRIP_GAS_COSTS["short"]))


func get_gas_price() -> int:
	return max(0, gas_price)


func set_gas_price(price: int) -> void:
	gas_price = max(0, price)
	save_progress()


func add_gas(amount: int) -> void:
	gas += amount


func spend_gas(amount: int) -> bool:
	if amount < 0 or gas < amount:
		return false

	gas -= amount
	return true


func apply_night_rest_bonus() -> int:
	var applied_bonus := mini(NIGHT_SLEEP_ENERGY_BONUS, max_energy - energy)
	if applied_bonus > 0:
		add_energy(applied_bonus)
	return applied_bonus


func get_stage_start_error(stage_descriptor := "") -> String:
	if pending_stage_energy_cost:
		return ""
	if energy <= 0:
		return "Not enough energy to start this trip."

	var trip_gas_cost := get_trip_gas_cost(stage_descriptor)
	if gas < trip_gas_cost:
		return "Not enough gas for this trip."

	return ""


func prepare_stage_start(stage_descriptor := "") -> bool:
	if pending_stage_energy_cost:
		return true

	if not get_stage_start_error(stage_descriptor).is_empty():
		return false

	var trip_gas_cost := get_trip_gas_cost(stage_descriptor)

	spend_energy(1)
	spend_gas(trip_gas_cost)
	pending_stage_energy_cost = true
	save_progress()
	return true


func confirm_stage_started() -> void:
	pending_stage_energy_cost = false
	save_progress()


func will_advance_day(transition_mode: String = TRANSITION_RIDE) -> bool:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	if safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY or safe_transition_mode == TRANSITION_SLEEP_TO_NEXT_DAY:
		return true
	return safe_transition_mode == TRANSITION_RIDE and get_current_time_of_day() == "night"


func get_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	if safe_transition_mode == TRANSITION_SLEEP_TO_NEXT_DAY:
		return 0
	var energy_bonus := int(REST_ENERGY_BONUSES.get(safe_transition_mode, 0))
	if will_advance_day(safe_transition_mode):
		energy_bonus += END_OF_DAY_ENERGY_BONUS
	return energy_bonus


func apply_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	var applied_bonus := mini(get_transition_energy_bonus(transition_mode), max_energy - energy)
	if applied_bonus > 0:
		add_energy(applied_bonus)
	return applied_bonus


func advance_to_next_stage(transition_mode: String = TRANSITION_RIDE, selected_difficulty := "", forced_traffic := "") -> String:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
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
	save_progress()
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


func _difficulty_from_stage_descriptor(stage_descriptor: String) -> String:
	var descriptor := stage_descriptor
	if descriptor.is_empty():
		descriptor = get_current_stage_type()
	if descriptor == "easy":
		return "short"
	if STAGE_DIFFICULTIES.has(descriptor):
		return descriptor
	return str(_parse_stage_type(descriptor).get("difficulty", "short"))


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
	save_progress()


func get_last_stage_result() -> Dictionary:
	return last_stage_result.duplicate(true)


func claim_last_stage_total() -> int:
	if last_stage_result.is_empty() or bool(last_stage_result.get("paid_out", false)):
		return 0

	var total := int(last_stage_result.get("total", 0))
	add_money(total)
	last_stage_result["paid_out"] = true
	save_progress()
	return total


func is_run_failed() -> bool:
	return run_failed


func get_run_fail_reason() -> String:
	return run_fail_reason


func set_pending_trip_selection(return_scene: String, transition_mode: String = TRANSITION_RIDE, allow_back := true) -> void:
	var locked_characters: Array = pending_trip_selection.get("locked_characters", [])
	locked_characters = locked_characters.duplicate(true)
	var locked_character_pools := Dictionary(pending_trip_selection.get("locked_character_pools", {})).duplicate(true)
	var locked_distance := str(pending_trip_selection.get("selected_distance", ""))
	pending_trip_selection = {
		"return_scene": return_scene,
		"transition_mode": normalize_transition_mode(str(transition_mode)),
		"allow_back": bool(allow_back),
	}
	if not locked_character_pools.is_empty():
		pending_trip_selection["locked_character_pools"] = locked_character_pools
	if not locked_characters.is_empty():
		pending_trip_selection["locked_characters"] = locked_characters
	if STAGE_DIFFICULTIES.has(locked_distance):
		pending_trip_selection["selected_distance"] = locked_distance
	save_progress()


func get_pending_trip_selection() -> Dictionary:
	return pending_trip_selection.duplicate(true)


func has_locked_pending_trip_selection() -> bool:
	var locked_character_pools := Dictionary(pending_trip_selection.get("locked_character_pools", {}))
	for difficulty_variant in STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		var pool: Array = locked_character_pools.get(difficulty, [])
		if not pool.is_empty():
			return true
	var locked_characters: Array = pending_trip_selection.get("locked_characters", [])
	return not locked_characters.is_empty()


func get_locked_pending_trip_character_pools() -> Dictionary:
	var locked_character_pools := Dictionary(pending_trip_selection.get("locked_character_pools", {}))
	return locked_character_pools.duplicate(true)


func get_locked_pending_trip_characters() -> Array:
	var locked_character_pools := Dictionary(pending_trip_selection.get("locked_character_pools", {}))
	if not locked_character_pools.is_empty():
		var selected_distance := get_locked_pending_trip_distance()
		if selected_distance.is_empty():
			selected_distance = "short"
		var selected_pool: Array = locked_character_pools.get(selected_distance, [])
		return selected_pool.duplicate(true)
	var locked_characters: Array = pending_trip_selection.get("locked_characters", [])
	return locked_characters.duplicate(true)


func get_locked_pending_trip_distance() -> String:
	var locked_distance := str(pending_trip_selection.get("selected_distance", ""))
	return locked_distance if STAGE_DIFFICULTIES.has(locked_distance) else ""


func lock_pending_trip_selection(locked_character_data, selected_distance: String) -> void:
	pending_trip_selection.erase("locked_characters")
	pending_trip_selection.erase("locked_character_pools")
	if locked_character_data is Dictionary:
		pending_trip_selection["locked_character_pools"] = Dictionary(locked_character_data).duplicate(true)
	elif locked_character_data is Array:
		pending_trip_selection["locked_characters"] = Array(locked_character_data).duplicate(true)
	pending_trip_selection["selected_distance"] = selected_distance if STAGE_DIFFICULTIES.has(selected_distance) else "short"
	save_progress()


func clear_pending_trip_selection() -> void:
	pending_trip_selection.clear()
	save_progress()


func set_pending_story(story_payload: Dictionary) -> void:
	pending_story = story_payload.duplicate(true)
	save_progress()


func get_pending_story() -> Dictionary:
	return pending_story.duplicate(true)


func clear_pending_story() -> void:
	pending_story.clear()
	save_progress()


func set_pending_sleep_transition_state(state: Dictionary) -> void:
	pending_sleep_transition_state = state.duplicate(true)
	save_progress()


func get_pending_sleep_transition_state() -> Dictionary:
	return pending_sleep_transition_state.duplicate(true)


func clear_pending_sleep_transition_state() -> void:
	pending_sleep_transition_state.clear()
	save_progress()


func set_pending_gameplay_entry_fade(duration: float) -> void:
	pending_gameplay_entry_fade_duration = maxf(0.0, duration)
	save_progress()


func consume_pending_gameplay_entry_fade() -> float:
	var duration := pending_gameplay_entry_fade_duration
	pending_gameplay_entry_fade_duration = 0.0
	save_progress()
	return maxf(0.0, duration)


func clear_pending_gameplay_entry_fade() -> void:
	pending_gameplay_entry_fade_duration = 0.0
	save_progress()


func set_sleep_transition_resume_step(resume_step: String) -> void:
	pending_sleep_transition_state["resume_step"] = resume_step
	save_progress()


func get_sleep_transition_resume_step() -> String:
	return str(pending_sleep_transition_state.get("resume_step", ""))


func add_story_trigger(trigger_data: Dictionary) -> void:
	if trigger_data.is_empty():
		return

	story_triggers.append(trigger_data.duplicate(true))
	save_progress()


func clear_story_triggers() -> void:
	story_triggers.clear()
	consumed_story_triggers.clear()
	save_progress()


func get_story_triggers() -> Array:
	return story_triggers.duplicate(true)


func normalize_story_trigger_phase(phase: String) -> String:
	match phase:
		STORY_TRIGGER_DAY_END, STORY_TRIGGER_SLEEP_MIDPOINT, STORY_TRIGGER_DAY_START, STORY_TRIGGER_STAGE_COMPLETE:
			return phase
	return ""


func find_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> Dictionary:
	var safe_phase := normalize_story_trigger_phase(str(phase))
	if safe_phase.is_empty():
		return {}

	var effective_day := int(day_number) if int(day_number) > 0 else get_current_day()
	for trigger_data in story_triggers:
		var trigger: Dictionary = trigger_data
		if _story_trigger_matches(trigger, safe_phase, effective_day, context):
			return trigger.duplicate(true)

	return {}


func has_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> bool:
	return not find_story_trigger_for_phase(phase, day_number, context).is_empty()


func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	if trigger_data.is_empty():
		return {}

	var payload_variant = trigger_data.get("payload", {})
	if payload_variant is Dictionary:
		return (payload_variant as Dictionary).duplicate(true)
	return {}


func consume_story_trigger(trigger_data: Dictionary) -> void:
	if trigger_data.is_empty() or bool(trigger_data.get("repeatable", false)):
		return

	var trigger_id := _story_trigger_id(trigger_data)
	if not trigger_id.is_empty():
		consumed_story_triggers[trigger_id] = true
	save_progress()


func get_mock_characters() -> Array:
	return MOCK_CHARACTERS.duplicate(true)


func get_random_stage_traffic_type() -> String:
	return str(STAGE_TRAFFIC_TYPES[rng.randi_range(0, STAGE_TRAFFIC_TYPES.size() - 1)])


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
	var difficulty_key := str(parts.get("difficulty", "short"))
	var difficulty_profile: Dictionary = ESTIMATED_STAGE_PROFILES[difficulty_key] if ESTIMATED_STAGE_PROFILES.has(difficulty_key) else ESTIMATED_STAGE_PROFILES["short"]
	var estimated_distance := get_stage_distance_average(difficulty_key)
	var base_fare := estimated_distance * float(difficulty_profile["fare_php_per_meter"])
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
	var goal_amount := get_current_weekly_goal()
	if goal_amount <= 0:
		return true
	if money < goal_amount:
		run_failed = true
		run_fail_reason = "Debt collector came for PhP %d on Day %d. Hold R to reset progress." % [
			goal_amount,
			day_number,
		]
		save_progress()
		return false

	spend_money(goal_amount)
	remaining_debt = maxi(0, remaining_debt - goal_amount)
	if debt_goal_index < WEEKLY_DEBT_GOALS.size() - 1:
		debt_goal_index += 1
	save_progress()
	return true


func set_current_mock_character(character_id: String) -> void:
	current_mock_character_id = character_id
	save_progress()


func get_current_mock_character_id() -> String:
	return current_mock_character_id


func mark_mock_character_seen(character_id: String) -> void:
	seen_mock_characters[character_id] = true
	save_progress()


func has_seen_mock_character(character_id: String) -> bool:
	return bool(seen_mock_characters.get(character_id, false))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var safe_level: int = max(0, level)
	upgrades[upgrade_id] = safe_level
	upgrade_changed.emit(upgrade_id, safe_level)
	save_progress()


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func unlock_achievement(achievement_id: String) -> void:
	var safe_id := str(achievement_id).strip_edges().to_lower()
	if not ACHIEVEMENT_DEFINITIONS.has(safe_id):
		return
	if achievements.get(safe_id, false):
		return

	achievements[safe_id] = true
	achievement_unlocked.emit(safe_id)
	save_progress()


func has_achievement(achievement_id: String) -> bool:
	return bool(achievements.get(str(achievement_id).strip_edges().to_lower(), false))


func get_achievement_data(achievement_id: String) -> Dictionary:
	var safe_id := str(achievement_id).strip_edges().to_lower()
	if not ACHIEVEMENT_DEFINITIONS.has(safe_id):
		return {}

	var achievement_data: Dictionary = ACHIEVEMENT_DEFINITIONS[safe_id]
	var result := achievement_data.duplicate(true)
	result["id"] = safe_id
	result["unlocked"] = has_achievement(safe_id)
	return result


func get_unlocked_achievement_ids() -> Array[String]:
	var unlocked_ids: Array[String] = []
	for achievement_id in ACHIEVEMENT_ORDER:
		var safe_id := str(achievement_id)
		if has_achievement(safe_id):
			unlocked_ids.append(safe_id)
	return unlocked_ids


func reset() -> void:
	_is_loading_save = true
	money = 0
	energy = 3
	max_energy = 5
	max_gas = DEFAULT_STARTING_GAS
	gas = DEFAULT_STARTING_GAS
	gas_price = DEFAULT_GAS_PRICE
	karma = 0
	begin_stage_sequence()
	last_stage_result.clear()
	clear_pending_trip_selection()
	clear_pending_story()
	clear_pending_sleep_transition_state()
	clear_pending_gameplay_entry_fade()
	current_mock_character_id = ""
	seen_mock_characters.clear()
	last_rest_day = 0
	debt_goal_index = 0
	last_debt_collection_day = 0
	remaining_debt = TOTAL_DEBT_GOAL
	run_failed = false
	run_fail_reason = ""
	upgrades.clear()
	achievements.clear()
	last_seen_story_sections.clear()
	last_seen_story_id = ""
	resume_scene_path = ""
	_reset_story_triggers()
	_is_loading_save = false
	_delete_save_file()


func _reset_story_triggers() -> void:
	story_triggers.clear()
	story_triggers.append({
		"id": "day_2_station_bill",
		"phase": STORY_TRIGGER_STAGE_COMPLETE,
		"day": 2,
		"time_of_day": "morning",
		"payload": Day02StationBillPayload.build(),
	})
	consumed_story_triggers.clear()
	save_progress()


func _delete_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _story_trigger_matches(trigger_data: Dictionary, phase: String, day_number: int, context: Dictionary = {}) -> bool:
	if trigger_data.is_empty():
		return false
	if normalize_story_trigger_phase(str(trigger_data.get("phase", ""))) != phase:
		return false
	if get_story_payload_for_trigger(trigger_data).is_empty():
		return false

	var trigger_id := _story_trigger_id(trigger_data)
	if not bool(trigger_data.get("repeatable", false)) and not trigger_id.is_empty() and bool(consumed_story_triggers.get(trigger_id, false)):
		return false

	if trigger_data.has("day") and int(trigger_data.get("day", 0)) != day_number:
		return false
	if trigger_data.has("min_day") and day_number < int(trigger_data.get("min_day", day_number)):
		return false
	if trigger_data.has("max_day") and day_number > int(trigger_data.get("max_day", day_number)):
		return false

	var days_variant = trigger_data.get("days", [])
	if days_variant is Array and not (days_variant as Array).is_empty():
		var valid_day := false
		for listed_day in days_variant:
			if int(listed_day) == day_number:
				valid_day = true
				break
		if not valid_day:
			return false

	if not _trigger_matches_context_value(trigger_data.get("stage_type", null), context.get("stage_type", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("stage_types", []), context.get("stage_type", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("time_of_day", null), context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("times", []), context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("difficulty", null), context.get("difficulty", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("difficulties", []), context.get("difficulty", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("traffic", null), context.get("traffic", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("traffic_types", []), context.get("traffic", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("character_id", null), context.get("character_id", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("character_ids", []), context.get("character_id", null)):
		return false

	return true


func _trigger_matches_context_value(expected_value, actual_value) -> bool:
	if expected_value == null:
		return true
	var expected_text := str(expected_value).strip_edges()
	if expected_text.is_empty():
		return true
	return expected_text == str(actual_value).strip_edges()


func _trigger_matches_context_array(expected_values, actual_value) -> bool:
	if not expected_values is Array:
		return true
	var expected_array := expected_values as Array
	if expected_array.is_empty():
		return true
	var actual_text := str(actual_value).strip_edges()
	for value in expected_array:
		if str(value).strip_edges() == actual_text:
			return true
	return false


func _story_trigger_id(trigger_data: Dictionary) -> String:
	var explicit_id := str(trigger_data.get("id", ""))
	if not explicit_id.is_empty():
		return explicit_id

	var payload := get_story_payload_for_trigger(trigger_data)
	return "%s:%s:%s" % [
		str(trigger_data.get("phase", "")),
		str(trigger_data.get("day", "")),
		str(payload.get("chapter_title", "")),
	]
