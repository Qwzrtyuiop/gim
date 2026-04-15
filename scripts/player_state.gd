extends Node

const AchievementService := preload("res://scripts/achievement_service.gd")
const PlayerStateSaveCodec := preload("res://scripts/save/player_state_save_codec.gd")
const StoryCatalog := preload("res://scripts/story/story_catalog.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const StoryTriggerService := preload("res://scripts/story/story_trigger_service.gd")

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
const TRANSITION_CURRENT_STAGE := "current_stage"
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
var unique_character_progress: Dictionary = {}
var seeded_rider_rules: Array[Dictionary] = []
var consumed_seeded_rider_rules: Dictionary = {}
var last_rest_day := 0
var yosi_bought_today := 0
var yosi_bought_day := 1
var yosi_bought_total := 0
var rests_taken_today := 0
var rests_taken_day := 1
var tamad_rest_times_today: Array[String] = []
var tamad_rest_day := 1
var rides_completed_today := 0
var rides_completed_day := 1
var non_gas_store_purchases_this_week := 0
var clean_stage_streak := 0
var current_trip_low_energy := false
var current_trip_low_gas := false
var low_resource_trip_count := 0
var low_both_resource_trip_count := 0
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
var event_values: Dictionary = {}
var resume_scene_path := ""
var ride_select_tutorial_shown := false
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
	PlayerStateSaveCodec.load_from_path(self, SAVE_PATH)


func save_progress() -> void:
	PlayerStateSaveCodec.save_to_path(self, SAVE_PATH, SAVE_VERSION)


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


func set_event_value(event_id: String, value) -> void:
	if not StoryEventHandler.set_event_value(event_values, event_id, value):
		return
	save_progress()


func set_event_values(values: Dictionary) -> void:
	if not StoryEventHandler.set_event_values(event_values, values):
		return
	save_progress()


func get_event_value(event_id: String, default_value = null):
	return StoryEventHandler.get_event_value(event_values, event_id, default_value)


func has_event_value(event_id: String) -> bool:
	return StoryEventHandler.has_event_value(event_values, event_id)


func clear_event_value(event_id: String) -> void:
	if not StoryEventHandler.clear_event_value(event_values, event_id):
		return
	save_progress()


func get_event_values() -> Dictionary:
	return StoryEventHandler.get_event_values(event_values)


func clear_event_values() -> void:
	if not StoryEventHandler.clear_event_values(event_values):
		return
	save_progress()


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


func has_ride_select_tutorial_shown() -> bool:
	return ride_select_tutorial_shown


func mark_ride_select_tutorial_shown() -> void:
	if ride_select_tutorial_shown:
		return
	ride_select_tutorial_shown = true
	save_progress()


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
	yosi_bought_today = 0
	yosi_bought_day = 1
	yosi_bought_total = 0
	rests_taken_today = 0
	rests_taken_day = 1
	tamad_rest_day = 1
	tamad_rest_times_today.clear()
	rides_completed_today = 0
	rides_completed_day = 1
	non_gas_store_purchases_this_week = 0
	clean_stage_streak = 0
	current_trip_low_energy = false
	current_trip_low_gas = false
	low_resource_trip_count = 0
	low_both_resource_trip_count = 0
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
		TRANSITION_CURRENT_STAGE, TRANSITION_REST_TO_NIGHT, TRANSITION_REST_TO_NEXT_DAY, TRANSITION_SLEEP_TO_NEXT_DAY:
			return transition_mode
	return TRANSITION_RIDE


func get_next_stage_time(transition_mode: String = TRANSITION_RIDE) -> String:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var current_time := get_current_time_of_day()

	if safe_transition_mode == TRANSITION_CURRENT_STAGE:
		return current_time
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
	record_rest()
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
	current_trip_low_energy = energy <= AchievementService.LOW_ENERGY_THRESHOLD
	current_trip_low_gas = gas <= AchievementService.LOW_GAS_THRESHOLD
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
	record_rest()
	if applied_bonus > 0:
		add_energy(applied_bonus)
	return applied_bonus


func advance_to_next_stage(transition_mode: String = TRANSITION_RIDE, selected_difficulty := "", forced_traffic := "") -> String:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var next_time := get_next_stage_time(safe_transition_mode)
	var current_day_before_advance := get_current_day()
	var next_day := current_day_before_advance

	if safe_transition_mode == TRANSITION_REST_TO_NIGHT or safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY:
		last_rest_day = get_current_day()

	if will_advance_day(safe_transition_mode):
		next_day += 1

	var next_stage := _random_stage_type_for_time(next_time, selected_difficulty, forced_traffic)
	stage_round += 1
	current_day = next_day
	current_stage_type = next_stage
	if current_day != current_day_before_advance:
		_reset_daily_consumable_counters(current_day)
	if will_advance_day(safe_transition_mode):
		_resolve_debt_collection_for_day(current_day)
	save_progress()
	return current_stage_type


func prepare_day_start(target_day: int) -> void:
	var safe_target_day: int = maxi(1, target_day)
	if get_current_day() == safe_target_day and get_current_time_of_day() == "morning":
		return

	current_day = safe_target_day
	current_stage_type = build_stage_type("short", "morning", "chill")
	pending_stage_energy_cost = false
	_reset_daily_consumable_counters(current_day)
	_resolve_debt_collection_for_day(current_day)
	save_progress()


func set_current_stage_time(day_time: String) -> void:
	var safe_time := day_time if STAGE_TIMES.has(day_time) else "morning"
	var stage_parts := _parse_stage_type(get_current_stage_type())
	current_stage_type = build_stage_type(
		str(stage_parts.get("difficulty", "short")),
		safe_time,
		str(stage_parts.get("traffic", "chill"))
	)
	save_progress()


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


func add_seeded_rider_rule(rule_data: Dictionary) -> void:
	if rule_data.is_empty():
		return

	var normalized_rule := _normalize_seeded_rider_rule(rule_data)
	if normalized_rule.is_empty():
		return

	seeded_rider_rules.append(normalized_rule)
	save_progress()


func seed_rider_for_stage(character_id: String, day: int, time_of_day := "", distance := "", slot := -1, forced_traffic := "", repeatable := false) -> void:
	var rule_data: Dictionary = {
		"character_id": character_id,
		"day": max(1, day),
		"repeatable": bool(repeatable),
	}
	if not str(time_of_day).strip_edges().is_empty():
		rule_data["time_of_day"] = time_of_day
	if not str(distance).strip_edges().is_empty():
		rule_data["distance"] = distance
	if int(slot) >= 0:
		rule_data["slot"] = int(slot)
	if not str(forced_traffic).strip_edges().is_empty():
		rule_data["forced_traffic"] = forced_traffic
	add_seeded_rider_rule(rule_data)


func clear_seeded_rider_rules() -> void:
	seeded_rider_rules.clear()
	consumed_seeded_rider_rules.clear()
	save_progress()


func get_seeded_rider_rules() -> Array:
	return seeded_rider_rules.duplicate(true)


func consume_seeded_rider_rules(rule_ids: Array) -> void:
	var consumed_any := false
	for rule_id_variant in rule_ids:
		var rule_id := str(rule_id_variant).strip_edges()
		if rule_id.is_empty():
			continue
		if bool(consumed_seeded_rider_rules.get(rule_id, false)):
			continue
		consumed_seeded_rider_rules[rule_id] = true
		consumed_any = true
	if consumed_any:
		save_progress()


func get_seeded_rider_pool_setup(selection_context: Dictionary) -> Dictionary:
	var context := selection_context.duplicate(true)
	var distance_slots := {
		"short": [],
		"medium": [],
		"long": [],
	}
	var consumed_character_ids: Dictionary = {}
	var used_rule_ids: Array[String] = []

	for rule_data in seeded_rider_rules:
		var rule: Dictionary = rule_data
		if not _seeded_rider_rule_matches(rule, context):
			continue

		var rule_id := _seeded_rider_rule_id(rule)
		if not bool(rule.get("repeatable", false)) and not rule_id.is_empty() and bool(consumed_seeded_rider_rules.get(rule_id, false)):
			continue

		var character_id := str(rule.get("character_id", rule.get("passenger_id", ""))).strip_edges().to_lower()
		if character_id.is_empty() or consumed_character_ids.has(character_id):
			continue

		var character := get_character_by_id(character_id)
		if character.is_empty():
			continue

		var target_distances := _get_seeded_rule_target_distances(rule, character)
		if target_distances.is_empty():
			continue

		var assigned := false
		for distance_variant in target_distances:
			var distance := str(distance_variant)
			if not STAGE_DIFFICULTIES.has(distance):
				continue

			var slot_index := _resolve_seeded_rider_slot_index(rule, distance_slots[distance])
			if slot_index < 0:
				continue

			var assignment := {
				"character": character.duplicate(true),
				"slot": slot_index,
				"forced_traffic": str(rule.get("forced_traffic", rule.get("traffic", ""))).strip_edges(),
				"forced_distance": distance,
				"rule_id": rule_id,
			}
			var existing_assignments: Array = distance_slots[distance]
			existing_assignments.append(assignment)
			distance_slots[distance] = existing_assignments
			consumed_character_ids[character_id] = true
			if not rule_id.is_empty():
				used_rule_ids.append(rule_id)
			assigned = true
			break

		if assigned:
			continue

	return {
		"distance_slots": distance_slots,
		"rule_ids": used_rule_ids,
	}


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
	return StoryTriggerService.normalize_story_trigger_phase(phase)


func find_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> Dictionary:
	var safe_phase := normalize_story_trigger_phase(str(phase))
	if safe_phase.is_empty():
		return {}

	var effective_day := int(day_number) if int(day_number) > 0 else get_current_day()
	return StoryTriggerService.find_story_trigger_for_phase(
		story_triggers,
		consumed_story_triggers,
		event_values,
		safe_phase,
		effective_day,
		context
	)


func has_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> bool:
	return not find_story_trigger_for_phase(phase, day_number, context).is_empty()


func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	return StoryTriggerService.get_story_payload_for_trigger(trigger_data)


func consume_story_trigger(trigger_data: Dictionary) -> void:
	if not StoryTriggerService.consume_story_trigger(consumed_story_triggers, trigger_data):
		return
	save_progress()


func get_mock_characters() -> Array:
	return StoryCatalog.get_mock_characters(self)


func get_character_by_id(character_id: String) -> Dictionary:
	return StoryCatalog.get_character_by_id(self, character_id)


func get_generic_passengers() -> Array:
	return StoryCatalog.get_generic_passengers()


func get_unique_passengers() -> Array:
	return StoryCatalog.get_unique_passengers(self)


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
	if debt_goal_index == 0 and non_gas_store_purchases_this_week == 0:
		unlock_achievement("matipid")
	remaining_debt = maxi(0, remaining_debt - goal_amount)
	non_gas_store_purchases_this_week = 0
	if debt_goal_index < WEEKLY_DEBT_GOALS.size() - 1:
		debt_goal_index += 1
	save_progress()
	return true


func set_current_mock_character(character_id: String) -> void:
	current_mock_character_id = character_id
	if is_unique_character(character_id):
		increment_unique_character_progress(character_id)
	save_progress()


func get_current_mock_character_id() -> String:
	return current_mock_character_id


func mark_mock_character_seen(character_id: String) -> void:
	seen_mock_characters[character_id] = true
	save_progress()


func has_seen_mock_character(character_id: String) -> bool:
	return bool(seen_mock_characters.get(character_id, false))


func get_unique_character_progress(character_id: String) -> int:
	var safe_id := str(character_id).strip_edges().to_lower()
	if safe_id.is_empty():
		return 0
	return int(unique_character_progress.get(safe_id, 0))


func increment_unique_character_progress(character_id: String, amount := 1) -> int:
	var safe_id := str(character_id).strip_edges().to_lower()
	var safe_amount: int = maxi(0, int(amount))
	if safe_id.is_empty() or safe_amount <= 0 or not is_unique_character(safe_id):
		return get_unique_character_progress(safe_id)
	unique_character_progress[safe_id] = get_unique_character_progress(safe_id) + safe_amount
	save_progress()
	return int(unique_character_progress[safe_id])


func is_unique_character(character_id: String) -> bool:
	return StoryCatalog.is_unique_character(character_id)


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var safe_level: int = max(0, level)
	upgrades[upgrade_id] = safe_level
	upgrade_changed.emit(upgrade_id, safe_level)
	save_progress()


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_yosi_energy_restore() -> int:
	return AchievementService.get_yosi_energy_restore(self)


func record_yosi_purchase(amount := 1) -> int:
	return AchievementService.record_yosi_purchase(self, amount)


func record_rest(amount := 1, time_of_day := "") -> int:
	return AchievementService.record_rest(self, amount, time_of_day)


func record_store_purchase(item_type: String) -> void:
	var safe_item_type := str(item_type).strip_edges().to_lower()
	if safe_item_type.is_empty() or safe_item_type == "gas":
		return
	non_gas_store_purchases_this_week += 1
	save_progress()


func record_stage_completion() -> void:
	AchievementService.record_stage_completion(self)


func record_stage_failure() -> void:
	AchievementService.record_stage_failure(self)


func unlock_achievement(achievement_id: String) -> void:
	AchievementService.unlock_achievement(self, achievement_id)


func fail_run(reason: String) -> void:
	var safe_reason := str(reason).strip_edges()
	run_failed = true
	run_fail_reason = safe_reason if not safe_reason.is_empty() else "John's run came to an end."
	save_progress()


func has_achievement(achievement_id: String) -> bool:
	return AchievementService.has_achievement(self, achievement_id)


func get_achievement_data(achievement_id: String) -> Dictionary:
	return AchievementService.get_achievement_data(self, achievement_id)


func get_unlocked_achievement_ids() -> Array[String]:
	return AchievementService.get_unlocked_achievement_ids(self)


func _apply_achievement_effects(achievement_id: String) -> void:
	AchievementService.apply_achievement_effects(self, achievement_id)


func _reset_daily_consumable_counters(day_number: int) -> void:
	AchievementService.reset_daily_consumable_counters(self, day_number)


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
	unique_character_progress.clear()
	seeded_rider_rules.clear()
	consumed_seeded_rider_rules.clear()
	last_rest_day = 0
	yosi_bought_today = 0
	yosi_bought_day = 1
	yosi_bought_total = 0
	rests_taken_today = 0
	rests_taken_day = 1
	tamad_rest_day = 1
	tamad_rest_times_today.clear()
	rides_completed_today = 0
	rides_completed_day = 1
	non_gas_store_purchases_this_week = 0
	clean_stage_streak = 0
	current_trip_low_energy = false
	current_trip_low_gas = false
	low_resource_trip_count = 0
	low_both_resource_trip_count = 0
	debt_goal_index = 0
	last_debt_collection_day = 0
	remaining_debt = TOTAL_DEBT_GOAL
	run_failed = false
	run_fail_reason = ""
	upgrades.clear()
	achievements.clear()
	last_seen_story_sections.clear()
	last_seen_story_id = ""
	event_values.clear()
	resume_scene_path = ""
	ride_select_tutorial_shown = false
	_reset_story_triggers()
	_is_loading_save = false
	_delete_save_file()


func _normalize_seeded_rider_rule(rule_data: Dictionary) -> Dictionary:
	var explicit_rule_id := str(rule_data.get("id", "")).strip_edges()
	var character_id := str(rule_data.get("character_id", rule_data.get("passenger_id", ""))).strip_edges().to_lower()
	if character_id.is_empty():
		return {}
	if get_character_by_id(character_id).is_empty():
		return {}

	var normalized_rule: Dictionary = rule_data.duplicate(true)
	normalized_rule["character_id"] = character_id
	normalized_rule.erase("passenger_id")
	if explicit_rule_id.is_empty():
		normalized_rule.erase("id")
	else:
		normalized_rule["id"] = explicit_rule_id
	normalized_rule["id"] = _seeded_rider_rule_id(normalized_rule)
	if normalized_rule.has("distance"):
		normalized_rule["distance"] = _normalize_seeded_distance(str(normalized_rule.get("distance", "")))
	if normalized_rule.has("distances") and normalized_rule.get("distances", null) is Array:
		var normalized_distances: Array[String] = []
		for distance_variant in normalized_rule.get("distances", []):
			var normalized_distance := _normalize_seeded_distance(str(distance_variant))
			if normalized_distance.is_empty() or normalized_distances.has(normalized_distance):
				continue
			normalized_distances.append(normalized_distance)
		normalized_rule["distances"] = normalized_distances
	if normalized_rule.has("time_of_day"):
		normalized_rule["time_of_day"] = _normalize_seeded_time(str(normalized_rule.get("time_of_day", "")))
	if normalized_rule.has("times") and normalized_rule.get("times", null) is Array:
		var normalized_times: Array[String] = []
		for time_variant in normalized_rule.get("times", []):
			var normalized_time := _normalize_seeded_time(str(time_variant))
			if normalized_time.is_empty() or normalized_times.has(normalized_time):
				continue
			normalized_times.append(normalized_time)
		normalized_rule["times"] = normalized_times
	if normalized_rule.has("current_time_of_day"):
		normalized_rule["current_time_of_day"] = _normalize_seeded_time(str(normalized_rule.get("current_time_of_day", "")))
	if normalized_rule.has("current_times") and normalized_rule.get("current_times", null) is Array:
		var normalized_current_times: Array[String] = []
		for time_variant in normalized_rule.get("current_times", []):
			var normalized_current_time := _normalize_seeded_time(str(time_variant))
			if normalized_current_time.is_empty() or normalized_current_times.has(normalized_current_time):
				continue
			normalized_current_times.append(normalized_current_time)
		normalized_rule["current_times"] = normalized_current_times
	if normalized_rule.has("forced_traffic"):
		normalized_rule["forced_traffic"] = _normalize_seeded_traffic(str(normalized_rule.get("forced_traffic", "")))
	if normalized_rule.has("traffic"):
		normalized_rule["traffic"] = _normalize_seeded_traffic(str(normalized_rule.get("traffic", "")))
	return normalized_rule


func _normalize_tamad_rest_time(time_of_day: String) -> String:
	return AchievementService.normalize_tamad_rest_time(time_of_day)


func _seeded_rider_rule_matches(rule_data: Dictionary, selection_context: Dictionary) -> bool:
	if rule_data.is_empty():
		return false

	var upcoming_day := int(selection_context.get("day", get_transition_display_day()))
	var current_day_value := int(selection_context.get("current_day", get_current_day()))
	if rule_data.has("day") and int(rule_data.get("day", 0)) != upcoming_day:
		return false
	if rule_data.has("min_day") and upcoming_day < int(rule_data.get("min_day", upcoming_day)):
		return false
	if rule_data.has("max_day") and upcoming_day > int(rule_data.get("max_day", upcoming_day)):
		return false
	if not _trigger_matches_context_array(rule_data.get("days", []), upcoming_day):
		return false

	if rule_data.has("current_day") and int(rule_data.get("current_day", 0)) != current_day_value:
		return false
	if not _trigger_matches_context_array(rule_data.get("current_days", []), current_day_value):
		return false

	if not _trigger_matches_context_value(rule_data.get("time_of_day", null), selection_context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_array(rule_data.get("times", []), selection_context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_value(rule_data.get("current_time_of_day", null), selection_context.get("current_time_of_day", null)):
		return false
	if not _trigger_matches_context_array(rule_data.get("current_times", []), selection_context.get("current_time_of_day", null)):
		return false
	if not _trigger_matches_context_value(rule_data.get("current_stage_type", null), selection_context.get("current_stage_type", null)):
		return false
	if not _trigger_matches_context_array(rule_data.get("current_stage_types", []), selection_context.get("current_stage_type", null)):
		return false

	return true


func _get_seeded_rule_target_distances(rule_data: Dictionary, character: Dictionary) -> Array[String]:
	var target_distances: Array[String] = []
	if rule_data.has("distance"):
		var normalized_distance := _normalize_seeded_distance(str(rule_data.get("distance", "")))
		if not normalized_distance.is_empty():
			target_distances.append(normalized_distance)
	elif rule_data.has("distances") and rule_data.get("distances", null) is Array:
		for distance_variant in rule_data.get("distances", []):
			var normalized_distance := _normalize_seeded_distance(str(distance_variant))
			if normalized_distance.is_empty() or target_distances.has(normalized_distance):
				continue
			target_distances.append(normalized_distance)
	else:
		for distance_variant in character.get("eligible_distances", []):
			var normalized_distance := _normalize_seeded_distance(str(distance_variant))
			if normalized_distance.is_empty() or target_distances.has(normalized_distance):
				continue
			target_distances.append(normalized_distance)

	if target_distances.is_empty():
		var fallback_distance := _normalize_seeded_distance(str(character.get("first_distance", "")))
		if not fallback_distance.is_empty():
			target_distances.append(fallback_distance)

	var filtered_distances: Array[String] = []
	for distance_variant in target_distances:
		var distance := str(distance_variant)
		var eligible_distances: Array = character.get("eligible_distances", [])
		if eligible_distances.is_empty() or eligible_distances.has(distance):
			filtered_distances.append(distance)
	return filtered_distances


func _resolve_seeded_rider_slot_index(rule_data: Dictionary, current_assignments: Array) -> int:
	var used_slots: Dictionary = {}
	for assignment_variant in current_assignments:
		if not assignment_variant is Dictionary:
			continue
		var assignment: Dictionary = assignment_variant
		used_slots[int(assignment.get("slot", -1))] = true

	if rule_data.has("slot"):
		var requested_slot := clampi(int(rule_data.get("slot", 0)), 0, 2)
		return -1 if used_slots.has(requested_slot) else requested_slot

	for slot_index in range(3):
		if not used_slots.has(slot_index):
			return slot_index
	return -1


func _seeded_rider_rule_id(rule_data: Dictionary) -> String:
	var explicit_id := str(rule_data.get("id", "")).strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	return "seeded:%s:%s:%s:%s" % [
		str(rule_data.get("character_id", "")).strip_edges().to_lower(),
		str(rule_data.get("day", "")).strip_edges(),
		str(rule_data.get("time_of_day", "")).strip_edges().to_lower(),
		str(rule_data.get("distance", "")).strip_edges().to_lower(),
	]


func _normalize_seeded_distance(distance: String) -> String:
	var safe_distance := str(distance).strip_edges().to_lower()
	if safe_distance == "easy":
		safe_distance = "short"
	return safe_distance if STAGE_DIFFICULTIES.has(safe_distance) else ""


func _normalize_seeded_time(time_of_day: String) -> String:
	var safe_time := str(time_of_day).strip_edges().to_lower()
	return safe_time if STAGE_TIMES.has(safe_time) else ""


func _normalize_seeded_traffic(traffic_type: String) -> String:
	var safe_traffic := str(traffic_type).strip_edges().to_lower()
	return safe_traffic if STAGE_TRAFFIC_TYPES.has(safe_traffic) else ""


func _reset_story_triggers() -> void:
	story_triggers = StoryTriggerService.build_default_story_triggers()
	consumed_story_triggers.clear()
	save_progress()


func _delete_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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
