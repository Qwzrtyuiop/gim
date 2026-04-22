extends Node

# Central run-state authority.
# If a feature needs to survive scene changes or be saved, it usually belongs here.

# Shared services
const AchievementService := preload("res://scripts/achievement_service.gd")
const PlayerStateSaveCodec := preload("res://scripts/save/player_state_save_codec.gd")
const PlayerResourceState := preload("res://scripts/state/player_resource_state.gd")
const PlayerStageFlow := preload("res://scripts/state/player_stage_flow.gd")
const SeededRiderRuntime := preload("res://scripts/seeded_rider_runtime.gd")
const StoryCatalog := preload("res://scripts/story/story_catalog.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const StoryTriggerRuntime := preload("res://scripts/story/story_trigger_runtime.gd")
const StoryTriggerService := preload("res://scripts/story/story_trigger_service.gd")

# Signals
signal money_changed(amount: int)
signal energy_changed(amount: int)
signal gas_changed(amount: float)
signal karma_changed(amount: int)
signal upgrade_changed(upgrade_id: String, level: int)
signal achievement_unlocked(achievement_id: String)

# Run configuration
const FIRST_STAGE_TYPE := "short-morning-chill"
const STAGE_DIFFICULTIES := ["short", "medium", "long"]
const STAGE_TIMES := ["morning", "noon", "night"]
const STAGE_TRAFFIC_TYPES := ["chill", "normal", "traffic-jam", "busy", "speeders"]
const STAGE_SPECIAL_TYPE_NONE := ""
const STAGE_SPECIAL_TYPE_URGENT := "urgent"
const STAGE_SPECIAL_TYPE_CAREFUL := "careful"
const STAGE_SPECIAL_TYPE_SPECIAL := "special"
const STAGE_SPECIAL_TYPES := [
	STAGE_SPECIAL_TYPE_URGENT,
	STAGE_SPECIAL_TYPE_CAREFUL,
	STAGE_SPECIAL_TYPE_SPECIAL,
]
const DEBT_COLLECTION_INTERVAL_DAYS := 7
const TOTAL_DEBT_GOAL := 50000
const WEEKLY_DEBT_GOALS := [1000]
const DEFAULT_STARTING_ENERGY := 10
const DEFAULT_MAX_ENERGY := 10
const DEFAULT_STARTING_GAS_PERCENT := 100.0
const DEFAULT_MAX_GAS_PERCENT := 100.0
const GAS_CAN_PERCENT := 10.0
const GAS_DRAIN_PERCENT_PER_1000_UNITS := 5.0
const FUEL_EFFICIENCY_UPGRADE_ID := "fuel_efficiency"
const LEGACY_TIRE_GRIP_UPGRADE_ID := "tire_grip"
const FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL := 0.07
const FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL := 0.04
const LOW_GAS_PERCENT_THRESHOLD := 20.0
const DEFAULT_GAS_PRICE := 70
const DAILY_GAS_PRICE_MAX_PERCENT_CHANGE := 30.0
const DEFAULT_WEATHER := "clear"
const WEATHER_CLOUDY := "cloudy"
const WEATHER_RAIN := "rain"
const WEATHER_HEAVY_RAIN := "heavy rain"
const WEATHER_TYPES := [DEFAULT_WEATHER, WEATHER_CLOUDY, WEATHER_RAIN, WEATHER_HEAVY_RAIN]
const WEATHER_SYSTEM_START_DAY := 2
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
const END_OF_DAY_ENERGY_BONUS := 2
const NIGHT_SLEEP_ENERGY_BONUS := 3
const ESTIMATED_BONUS_TIME_RATIO := 0.35
const STAGE_DISTANCE_RANGES := {
	"short": Vector2(400.0, 650.0),
	"medium": Vector2(700.0, 1050.0),
	"long": Vector2(1150.0, 1650.0),
}
const SAVE_PATH := "user://progress_save.tres"
const SAVE_VERSION := 2
const REST_ENERGY_BONUSES := {
	TRANSITION_RIDE: 0,
	TRANSITION_REST_TO_NIGHT: 2,
	TRANSITION_REST_TO_NEXT_DAY: 3,
	TRANSITION_SLEEP_TO_NEXT_DAY: 0,
}
const ESTIMATED_STAGE_PROFILES := {
	"short": {
		"target_distance": 525.0,
		"time_limit": 58.0,
		"fare_php_per_meter": 0.15,
		"time_bonus_php_per_second": 2.0,
	},
	"medium": {
		"target_distance": 875.0,
		"time_limit": 86.0,
		"fare_php_per_meter": 0.17,
		"time_bonus_php_per_second": 2.0,
	},
	"long": {
		"target_distance": 1400.0,
		"time_limit": 128.0,
		"fare_php_per_meter": 0.20,
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
	"busy": 1.55,
	"speeders": 1.24,
}

# Persistent run state
var last_stage_result: Dictionary = {}
var max_energy := DEFAULT_MAX_ENERGY
var max_gas := DEFAULT_MAX_GAS_PERCENT
var current_stage_type := FIRST_STAGE_TYPE
var current_stage_special_type := STAGE_SPECIAL_TYPE_NONE
var current_special_stage_id := ""
var current_day := 1
var stage_round := 0
var pending_stage_energy_cost := false
var pending_trip_selection: Dictionary = {}
var pending_story: Dictionary = {}
var pending_sleep_transition_state: Dictionary = {}
var pending_gameplay_entry_fade_duration := 0.0
var pending_result_music: Dictionary = {}
var pending_skip_night_phase := false
var current_mock_character_id := ""
var seen_mock_characters: Dictionary = {}
var unique_character_progress: Dictionary = {}
var locked_unique_character_stories: Dictionary = {}
var consumed_unique_session_dialogue: Dictionary = {}
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
var store_tutorial_shown := false
var home_tutorial_shown := false

# Save-flow guards
var _is_loading_save := false
var _suppress_auto_save := false
var _has_deferred_save := false
var _state_batch_depth := 0

var money := 0:
	set(value):
		money = max(0, value)
		money_changed.emit(money)
		save_progress()

var energy := DEFAULT_STARTING_ENERGY:
	set(value):
		energy = clampi(value, 0, max_energy)
		energy_changed.emit(energy)
		save_progress()

var gas := DEFAULT_STARTING_GAS_PERCENT:
	set(value):
		gas = clampf(value, 0.0, max_gas)
		gas_changed.emit(gas)
		save_progress()

var gas_price := DEFAULT_GAS_PRICE
var gas_price_delta := 0
var previous_gas_price := DEFAULT_GAS_PRICE
var current_weather := DEFAULT_WEATHER
var weather_forecasts: Dictionary = {}
var weather_phase_cache: Dictionary = {}
var daily_conditions_day := 1

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


# Save flow
func save_progress() -> void:
	if _is_loading_save:
		return
	if _suppress_auto_save:
		_has_deferred_save = true
		return
	PlayerStateSaveCodec.save_to_path(self, SAVE_PATH, SAVE_VERSION)


func flush_deferred_save() -> void:
	if not _has_deferred_save:
		return
	_has_deferred_save = false
	save_progress()


func _mark_deferred_save() -> void:
	_has_deferred_save = true


func _begin_state_batch() -> void:
	_state_batch_depth += 1
	_suppress_auto_save = true


func _end_state_batch(save_after := true, discard_deferred := false) -> void:
	_state_batch_depth = maxi(0, _state_batch_depth - 1)
	if _state_batch_depth > 0:
		return
	_suppress_auto_save = false
	if discard_deferred:
		_has_deferred_save = false
		return
	if save_after and _has_deferred_save:
		flush_deferred_save()


# Story event and resume state
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


# Tutorial state
func has_ride_select_tutorial_shown() -> bool:
	return ride_select_tutorial_shown


func mark_ride_select_tutorial_shown() -> void:
	if ride_select_tutorial_shown:
		return
	ride_select_tutorial_shown = true
	save_progress()


func has_store_tutorial_shown() -> bool:
	return store_tutorial_shown


func mark_store_tutorial_shown() -> void:
	if store_tutorial_shown:
		return
	store_tutorial_shown = true
	save_progress()


func has_home_tutorial_shown() -> bool:
	return home_tutorial_shown


func mark_home_tutorial_shown() -> void:
	if home_tutorial_shown:
		return
	home_tutorial_shown = true
	save_progress()


# Run setup and progression
func begin_stage_sequence() -> void:
	_begin_state_batch()
	_apply_new_run_defaults()
	last_stage_result.clear()
	save_progress()
	_end_state_batch()


func get_current_stage_type() -> String:
	if current_stage_type.is_empty():
		current_stage_type = FIRST_STAGE_TYPE
	return current_stage_type


func normalize_stage_special_type(stage_special_type: String) -> String:
	var safe_special_type: String = str(stage_special_type).strip_edges().to_lower()
	return safe_special_type if STAGE_SPECIAL_TYPES.has(safe_special_type) else STAGE_SPECIAL_TYPE_NONE


func normalize_special_stage_id(special_stage_id: String) -> String:
	return str(special_stage_id).strip_edges().to_lower()


func set_current_stage_special_type(stage_special_type: String) -> void:
	current_stage_special_type = normalize_stage_special_type(stage_special_type)
	if current_stage_special_type != STAGE_SPECIAL_TYPE_SPECIAL:
		current_special_stage_id = ""
	save_progress()


func get_current_stage_special_type() -> String:
	return normalize_stage_special_type(current_stage_special_type)


func set_current_special_stage_id(special_stage_id: String) -> void:
	if get_current_stage_special_type() != STAGE_SPECIAL_TYPE_SPECIAL:
		current_special_stage_id = ""
	else:
		current_special_stage_id = normalize_special_stage_id(special_stage_id)
	save_progress()


func get_current_special_stage_id() -> String:
	if get_current_stage_special_type() != STAGE_SPECIAL_TYPE_SPECIAL:
		return ""
	return normalize_special_stage_id(current_special_stage_id)


func get_stage_special_display_name(stage_special_type: String) -> String:
	match normalize_stage_special_type(stage_special_type):
		STAGE_SPECIAL_TYPE_URGENT:
			return "URGENT"
		STAGE_SPECIAL_TYPE_CAREFUL:
			return "CAREFUL"
		STAGE_SPECIAL_TYPE_SPECIAL:
			return "SPECIAL"
	return ""


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


func get_week_number(day_number := -1) -> int:
	var effective_day: int = int(day_number) if int(day_number) > 0 else get_current_day()
	return maxi(1, int(floor(float(maxi(1, effective_day) - 1) / float(DEBT_COLLECTION_INTERVAL_DAYS))) + 1)


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
	return PlayerStageFlow.normalize_transition_mode(self, transition_mode)


func get_next_stage_time(transition_mode: String = TRANSITION_RIDE) -> String:
	return PlayerStageFlow.next_stage_time(self, transition_mode)


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


# Economy and resource helpers
func get_trip_gas_cost(_stage_descriptor := "") -> float:
	return 0.0


func get_distance_gas_cost(distance_units: float) -> float:
	return maxf(0.0, distance_units) / 1000.0 * GAS_DRAIN_PERCENT_PER_1000_UNITS * get_distance_gas_consumption_multiplier()


func estimate_stage_gas_usage(stage_type: String) -> float:
	var parts := _parse_stage_type(stage_type)
	var difficulty_key := str(parts.get("difficulty", "short"))
	return get_distance_gas_cost(get_stage_distance_average(difficulty_key))


func get_distance_gas_consumption_multiplier() -> float:
	return maxf(0.45, 1.0 - get_fuel_efficiency_level() * FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL)


func get_boost_gas_consumption_multiplier() -> float:
	return maxf(0.60, 1.0 - get_fuel_efficiency_level() * FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL)


func get_fuel_efficiency_level() -> int:
	return maxi(
		get_upgrade_level(FUEL_EFFICIENCY_UPGRADE_ID),
		get_upgrade_level(LEGACY_TIRE_GRIP_UPGRADE_ID)
	)


func get_gas_price() -> int:
	return max(0, gas_price)


func get_gas_price_text() -> String:
	return "PhP %d.00" % get_gas_price()


func get_gas_price_change_text() -> String:
	var absolute_delta: int = gas_price_delta
	if absolute_delta < 0:
		absolute_delta *= -1
	if gas_price_delta > 0:
		return "+PhP %d.00" % absolute_delta
	if gas_price_delta < 0:
		return "-PhP %d.00" % absolute_delta
	return "PhP 0.00"


func get_gas_price_yesterday_percent_text() -> String:
	var yesterday_price: float = maxf(1.0, float(previous_gas_price))
	var raw_percent_change: float = (float(get_gas_price()) - yesterday_price) / yesterday_price * 100.0
	var percent_change: float = clampf(raw_percent_change, -DAILY_GAS_PRICE_MAX_PERCENT_CHANGE, DAILY_GAS_PRICE_MAX_PERCENT_CHANGE)
	if percent_change > 0.0:
		return "+%.1f%%" % percent_change
	if percent_change < 0.0:
		return "%.1f%%" % percent_change
	return "0.0%"


func set_gas_price(price: int) -> void:
	gas_price = max(0, price)
	gas_price_delta = gas_price - previous_gas_price
	save_progress()


func get_current_weather() -> String:
	return get_stage_weather(get_current_time_of_day())


func get_current_weather_text() -> String:
	return weather_text(get_current_weather())


func get_today_weather_forecast() -> String:
	return get_weather_forecast_for_day(get_current_day())


func get_tomorrow_weather_forecast() -> String:
	return get_weather_forecast_for_day(get_current_day() + 1)


func get_weather_forecast_for_day(day_number: int) -> String:
	var safe_day: int = maxi(1, day_number)
	_ensure_weather_forecast_for_day(safe_day)
	return _normalize_weather(str(weather_forecasts.get(safe_day, DEFAULT_WEATHER)))


func get_stage_weather(day_time := "") -> String:
	var safe_day: int = get_current_day()
	if safe_day < WEATHER_SYSTEM_START_DAY:
		return DEFAULT_WEATHER

	_ensure_weather_forecast_for_day(safe_day)
	var safe_time: String = str(day_time).strip_edges().to_lower()
	if not STAGE_TIMES.has(safe_time):
		safe_time = get_current_time_of_day()
	var phase_key: String = _weather_phase_key(safe_day, safe_time)
	if not weather_phase_cache.has(phase_key):
		weather_phase_cache[phase_key] = _roll_weather_for_phase(get_weather_forecast_for_day(safe_day), safe_time)
		save_progress()

	current_weather = _normalize_weather(str(weather_phase_cache.get(phase_key, DEFAULT_WEATHER)))
	return current_weather


func weather_text(weather_value: String) -> String:
	var safe_weather: String = _normalize_weather(weather_value)
	match safe_weather:
		WEATHER_CLOUDY:
			return "Cloudy"
		WEATHER_RAIN:
			return "Rain"
		WEATHER_HEAVY_RAIN:
			return "Heavy Rain"
	return "Clear"


func get_daily_news_text() -> String:
	return "TODAY'S NEWS\nGas Price:   %s      %s\nChange:   %s\nToday:   %s\nTomorrow:   %s" % [
		get_gas_price_text(),
		get_gas_price_yesterday_percent_text(),
		get_gas_price_change_text(),
		weather_text(get_today_weather_forecast()),
		weather_text(get_tomorrow_weather_forecast()),
	]


func ensure_daily_conditions_for_current_day() -> void:
	var safe_day: int = get_current_day()
	var needs_save: bool = false
	if daily_conditions_day != safe_day:
		_roll_daily_conditions_for_day(safe_day)
		needs_save = true
	if _ensure_weather_forecast_for_day(safe_day):
		needs_save = true
	if _ensure_weather_forecast_for_day(safe_day + 1):
		needs_save = true
	if needs_save:
		save_progress()


func add_gas(amount: float) -> void:
	gas += amount


func spend_gas(amount: float, save_immediately := true) -> bool:
	if amount < 0.0 or gas + 0.001 < amount:
		return false

	_set_gas_with_save_mode(gas - amount, save_immediately)
	return true


func drain_gas(amount: float, save_immediately := true) -> float:
	var consumed_amount: float = minf(maxf(0.0, amount), gas)
	if consumed_amount <= 0.0:
		return 0.0

	_set_gas_with_save_mode(gas - consumed_amount, save_immediately)
	return consumed_amount


func _set_gas_with_save_mode(value: float, save_immediately: bool) -> void:
	if save_immediately:
		gas = value
		return

	var was_suppressing_auto_save := _suppress_auto_save
	_suppress_auto_save = true
	gas = value
	_suppress_auto_save = was_suppressing_auto_save
	_mark_deferred_save()


func gas_text() -> String:
	return "%.1f%%" % gas


func gas_capacity_text() -> String:
	return "%.1f%%" % max_gas


func gas_ratio() -> float:
	return PlayerResourceState.gas_ratio(self)


func is_low_gas() -> bool:
	return PlayerResourceState.is_low_gas(self)


func get_energy_vehicle_modifiers() -> Dictionary:
	return PlayerResourceState.energy_vehicle_modifiers(self)


func boost_gas_is_available() -> bool:
	return gas > 0.05


func apply_night_rest_bonus() -> int:
	var applied_bonus := mini(NIGHT_SLEEP_ENERGY_BONUS, max_energy - energy)
	record_rest()
	if applied_bonus > 0:
		add_energy(applied_bonus)
	return applied_bonus


func get_stage_start_error(stage_descriptor := "") -> String:
	return PlayerResourceState.stage_start_error(self, stage_descriptor)


func get_stage_start_error_after_transition(stage_descriptor := "", transition_mode: String = TRANSITION_RIDE) -> String:
	return PlayerResourceState.stage_start_error_after_transition(self, stage_descriptor, transition_mode)


func prepare_stage_start(stage_descriptor := "") -> bool:
	if pending_stage_energy_cost:
		return true

	if not get_stage_start_error(stage_descriptor).is_empty():
		return false

	spend_energy(1)
	current_trip_low_energy = energy <= AchievementService.LOW_ENERGY_THRESHOLD
	current_trip_low_gas = is_low_gas()
	pending_stage_energy_cost = true
	save_progress()
	return true


func prepare_stage_start_after_transition(stage_descriptor := "", transition_mode: String = TRANSITION_RIDE) -> bool:
	if pending_stage_energy_cost:
		return true

	if not get_stage_start_error_after_transition(stage_descriptor, transition_mode).is_empty():
		return false

	apply_transition_energy_bonus(transition_mode)
	return prepare_stage_start(stage_descriptor)


func confirm_stage_started() -> void:
	pending_stage_energy_cost = false
	save_progress()


func will_advance_day(transition_mode: String = TRANSITION_RIDE) -> bool:
	return PlayerStageFlow.will_advance_day(self, transition_mode)


func get_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	return PlayerStageFlow.transition_energy_bonus(self, transition_mode)


func apply_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var applied_bonus := mini(get_transition_energy_bonus(safe_transition_mode), max_energy - energy)
	if safe_transition_mode == TRANSITION_REST_TO_NIGHT or safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY or safe_transition_mode == TRANSITION_SLEEP_TO_NEXT_DAY:
		record_rest(1, get_current_time_of_day())
	if applied_bonus > 0:
		add_energy(applied_bonus)
	return applied_bonus


# Stage flow and transitions
func advance_to_next_stage(transition_mode: String = TRANSITION_RIDE, selected_difficulty := "", forced_traffic := "") -> String:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var current_time_before_advance := get_current_time_of_day()
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
		_roll_daily_conditions_for_day(current_day)
	if will_advance_day(safe_transition_mode):
		_resolve_debt_collection_for_day(current_day)
	if pending_skip_night_phase and current_time_before_advance != "night" and next_time == "morning" and current_day > current_day_before_advance:
		pending_skip_night_phase = false
	save_progress()
	return current_stage_type


func prepare_day_start(target_day: int) -> void:
	var safe_target_day: int = maxi(1, target_day)
	if get_current_day() == safe_target_day and get_current_time_of_day() == "morning":
		return

	current_day = safe_target_day
	current_stage_type = build_stage_type("short", "morning", "chill")
	current_stage_special_type = STAGE_SPECIAL_TYPE_NONE
	current_special_stage_id = ""
	pending_stage_energy_cost = false
	_reset_daily_consumable_counters(current_day)
	_roll_daily_conditions_for_day(current_day)
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
	current_stage_special_type = STAGE_SPECIAL_TYPE_NONE
	current_special_stage_id = ""
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


func add_max_energy(amount: int) -> void:
	var safe_amount: int = int(amount)
	if safe_amount == 0:
		return
	max_energy = maxi(1, max_energy + safe_amount)
	energy = mini(energy, max_energy)
	save_progress()


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


# Pending scene and transition state
func set_pending_trip_selection(return_scene: String, transition_mode: String = TRANSITION_RIDE, allow_back := true) -> void:
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var should_preserve_locked_selection: bool = (
		safe_transition_mode == TRANSITION_RIDE
		or safe_transition_mode == TRANSITION_CURRENT_STAGE
	)
	var locked_characters: Array = []
	var locked_character_pools: Dictionary = {}
	var locked_distance := ""
	if should_preserve_locked_selection:
		locked_characters = pending_trip_selection.get("locked_characters", [])
		locked_characters = locked_characters.duplicate(true)
		locked_character_pools = Dictionary(pending_trip_selection.get("locked_character_pools", {})).duplicate(true)
		locked_distance = str(pending_trip_selection.get("selected_distance", ""))
	pending_trip_selection = {
		"return_scene": return_scene,
		"transition_mode": safe_transition_mode,
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


# Seeded rider runtime
func add_seeded_rider_rule(rule_data: Dictionary) -> void:
	if rule_data.is_empty():
		return

	var normalized_rule := SeededRiderRuntime.normalize_rule(self, rule_data)
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
	_reset_seeded_rider_state()
	save_progress()


func get_seeded_rider_rules() -> Array:
	return seeded_rider_rules.duplicate(true)


func consume_seeded_rider_rules(rule_ids: Array) -> void:
	var consumed_any := SeededRiderRuntime.consume_rules(consumed_seeded_rider_rules, rule_ids)
	if consumed_any:
		save_progress()


func get_seeded_rider_pool_setup(selection_context: Dictionary) -> Dictionary:
	return SeededRiderRuntime.get_pool_setup(self, selection_context)


# Pending story state
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


func set_pending_result_music(music_state: Dictionary) -> void:
	pending_result_music = music_state.duplicate(true)


func has_pending_night_phase_skip() -> bool:
	return pending_skip_night_phase


func set_pending_night_phase_skip(enabled: bool) -> void:
	pending_skip_night_phase = bool(enabled)
	save_progress()


func clear_pending_night_phase_skip() -> void:
	if not pending_skip_night_phase:
		return
	pending_skip_night_phase = false
	save_progress()


func consume_pending_result_music() -> Dictionary:
	var music_state := pending_result_music.duplicate(true)
	pending_result_music.clear()
	return music_state


func clear_pending_result_music() -> void:
	pending_result_music.clear()


func set_sleep_transition_resume_step(resume_step: String) -> void:
	pending_sleep_transition_state["resume_step"] = resume_step
	save_progress()


func get_sleep_transition_resume_step() -> String:
	return str(pending_sleep_transition_state.get("resume_step", ""))


# Story trigger state
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
	return StoryTriggerRuntime.find_story_trigger_for_phase(self, phase, day_number, context)


func has_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> bool:
	return not find_story_trigger_for_phase(phase, day_number, context).is_empty()


func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	return StoryTriggerService.get_story_payload_for_trigger(trigger_data)


func consume_story_trigger(trigger_data: Dictionary) -> void:
	if not StoryTriggerService.consume_story_trigger(consumed_story_triggers, trigger_data):
		return
	save_progress()


# Character catalog and stage previews
func get_mock_characters() -> Array:
	return StoryCatalog.get_mock_characters(self)


func get_character_by_id(character_id: String) -> Dictionary:
	return StoryCatalog.get_character_by_id(self, character_id)


func get_generic_passengers() -> Array:
	return StoryCatalog.get_generic_passengers()


func get_unique_passengers() -> Array:
	return StoryCatalog.get_unique_passengers(self)


func get_unique_character_story_state(character_id: String, context: Dictionary = {}) -> Dictionary:
	return StoryCatalog.get_unique_character_story_state(self, character_id, context)


func get_current_mock_character_story_state(context: Dictionary = {}) -> Dictionary:
	return get_unique_character_story_state(current_mock_character_id, context)


func get_character_stage_modifiers(character_id: String, context: Dictionary = {}) -> Dictionary:
	return StoryCatalog.get_character_stage_modifiers(self, character_id, context)


func get_current_mock_character_stage_modifiers(context: Dictionary = {}) -> Dictionary:
	return get_character_stage_modifiers(current_mock_character_id, context)


func get_character_session_dialogue(character_id: String, context: Dictionary = {}) -> Dictionary:
	return StoryCatalog.get_character_session_dialogue(self, character_id, context)


func get_current_mock_character_session_dialogue(context: Dictionary = {}) -> Dictionary:
	return get_character_session_dialogue(current_mock_character_id, context)


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


func estimate_stage_earnings(stage_type: String, character_id := "") -> int:
	var parts: Dictionary = _parse_stage_type(stage_type)
	var difficulty_key := str(parts.get("difficulty", "short"))
	var difficulty_profile: Dictionary = ESTIMATED_STAGE_PROFILES[difficulty_key].duplicate(true) if ESTIMATED_STAGE_PROFILES.has(difficulty_key) else ESTIMATED_STAGE_PROFILES["short"].duplicate(true)
	var modifier_context := {
		"stage_type": stage_type,
		"difficulty": difficulty_key,
		"time_of_day": str(parts.get("time", "morning")),
		"traffic": str(parts.get("traffic", "chill")),
	}
	var effective_character_id: String = str(character_id).strip_edges().to_lower()
	if effective_character_id.is_empty():
		effective_character_id = current_mock_character_id
	_apply_estimated_stage_profile_modifiers(
		difficulty_profile,
		get_character_stage_modifiers(effective_character_id, modifier_context)
	)
	var estimated_distance := get_stage_distance_average(difficulty_key)
	var base_fare := estimated_distance * float(difficulty_profile["fare_php_per_meter"])
	var estimated_bonus_seconds := float(difficulty_profile["time_limit"]) * ESTIMATED_BONUS_TIME_RATIO
	var base_bonus := estimated_bonus_seconds * float(difficulty_profile["time_bonus_php_per_second"])
	var multiplier := get_stage_earnings_multiplier(parts["time"], parts["traffic"])
	return roundi((base_fare + base_bonus) * multiplier)


# Achievements and failure state
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
	var safe_character_id := str(character_id).strip_edges().to_lower()
	current_mock_character_id = safe_character_id
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


func is_unique_character_story_locked(character_id: String) -> bool:
	var safe_id := str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return false
	return bool(locked_unique_character_stories.get(safe_id, false))


func set_unique_character_story_locked(character_id: String, locked := true) -> bool:
	var safe_id := str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return false
	var should_lock: bool = bool(locked)
	if should_lock:
		locked_unique_character_stories[safe_id] = true
	else:
		locked_unique_character_stories.erase(safe_id)
	save_progress()
	return should_lock


func set_unique_character_progress(character_id: String, progress: int) -> int:
	var safe_id := str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return get_unique_character_progress(safe_id)
	unique_character_progress[safe_id] = maxi(0, int(progress))
	save_progress()
	return int(unique_character_progress[safe_id])


func increment_unique_character_progress(character_id: String, amount := 1) -> int:
	var safe_id := str(character_id).strip_edges().to_lower()
	var safe_amount: int = maxi(0, int(amount))
	if safe_id.is_empty() or safe_amount <= 0 or not is_unique_character(safe_id):
		return get_unique_character_progress(safe_id)
	if is_unique_character_story_locked(safe_id):
		return get_unique_character_progress(safe_id)
	unique_character_progress[safe_id] = get_unique_character_progress(safe_id) + safe_amount
	save_progress()
	return int(unique_character_progress[safe_id])


func has_consumed_unique_session_dialogue(entry_id: String) -> bool:
	var safe_entry_id: String = str(entry_id).strip_edges()
	if safe_entry_id.is_empty():
		return false
	return bool(consumed_unique_session_dialogue.get(safe_entry_id, false))


func consume_unique_session_dialogue(entry_id: String) -> void:
	var safe_entry_id: String = str(entry_id).strip_edges()
	if safe_entry_id.is_empty() or has_consumed_unique_session_dialogue(safe_entry_id):
		return
	consumed_unique_session_dialogue[safe_entry_id] = true
	save_progress()


func is_unique_character(character_id: String) -> bool:
	return StoryCatalog.is_unique_character(character_id)


func _apply_estimated_stage_profile_modifiers(profile: Dictionary, modifiers: Dictionary) -> void:
	if profile.is_empty() or modifiers.is_empty():
		return
	_apply_numeric_profile_modifier(profile, modifiers, "fare_php_per_meter")
	_apply_numeric_profile_modifier(profile, modifiers, "time_limit")
	_apply_numeric_profile_modifier(profile, modifiers, "time_bonus_php_per_second")


func _apply_numeric_profile_modifier(profile: Dictionary, modifiers: Dictionary, key: String) -> void:
	if not profile.has(key):
		return

	var resolved_value := float(profile.get(key, 0.0))
	if modifiers.has(key):
		resolved_value = float(modifiers[key])
	if modifiers.has("%s_multiplier" % key):
		resolved_value *= float(modifiers["%s_multiplier" % key])
	if modifiers.has("%s_delta" % key):
		resolved_value += float(modifiers["%s_delta" % key])
	if modifiers.has("%s_min" % key):
		resolved_value = maxf(resolved_value, float(modifiers["%s_min" % key]))
	if modifiers.has("%s_cap" % key):
		resolved_value = minf(resolved_value, float(modifiers["%s_cap" % key]))
	profile[key] = resolved_value


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var safe_level: int = max(0, level)
	upgrades[upgrade_id] = safe_level
	upgrade_changed.emit(upgrade_id, safe_level)
	save_progress()


func get_upgrade_level(upgrade_id: String) -> int:
	if upgrade_id == FUEL_EFFICIENCY_UPGRADE_ID:
		return maxi(
			int(upgrades.get(FUEL_EFFICIENCY_UPGRADE_ID, 0)),
			int(upgrades.get(LEGACY_TIRE_GRIP_UPGRADE_ID, 0))
		)
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
	if is_unique_character(current_mock_character_id):
		increment_unique_character_progress(current_mock_character_id)
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


# Weather and daily condition state
func _reset_daily_consumable_counters(day_number: int) -> void:
	AchievementService.reset_daily_consumable_counters(self, day_number)


func _roll_daily_conditions_for_day(day_number: int) -> void:
	var safe_day: int = maxi(1, day_number)
	previous_gas_price = gas_price
	daily_conditions_day = safe_day
	if safe_day > 1:
		var percent_delta: float = rng.randf_range(-DAILY_GAS_PRICE_MAX_PERCENT_CHANGE, DAILY_GAS_PRICE_MAX_PERCENT_CHANGE)
		var previous_price_float: float = maxf(1.0, float(previous_gas_price))
		var raw_price: int = roundi(previous_price_float * (1.0 + percent_delta / 100.0))
		var min_price: int = ceili(previous_price_float * (1.0 - DAILY_GAS_PRICE_MAX_PERCENT_CHANGE / 100.0))
		var max_price: int = floori(previous_price_float * (1.0 + DAILY_GAS_PRICE_MAX_PERCENT_CHANGE / 100.0))
		gas_price = clampi(raw_price, min_price, maxi(min_price, max_price))
	else:
		gas_price = DEFAULT_GAS_PRICE
	gas_price_delta = gas_price - previous_gas_price
	_ensure_weather_forecast_for_day(safe_day)
	_ensure_weather_forecast_for_day(safe_day + 1)
	current_weather = _normalize_weather(str(weather_forecasts.get(safe_day, DEFAULT_WEATHER)))


func _ensure_weather_forecast_for_day(day_number: int) -> bool:
	var safe_day: int = maxi(1, day_number)
	if weather_forecasts.has(safe_day):
		weather_forecasts[safe_day] = _normalize_weather(str(weather_forecasts.get(safe_day, DEFAULT_WEATHER)))
		return false

	if safe_day < WEATHER_SYSTEM_START_DAY:
		weather_forecasts[safe_day] = DEFAULT_WEATHER
	else:
		weather_forecasts[safe_day] = _roll_weather_forecast()
	return true


func _roll_weather_forecast() -> String:
	var roll: int = rng.randi_range(1, 100)
	if roll <= 45:
		return DEFAULT_WEATHER
	if roll <= 70:
		return WEATHER_CLOUDY
	if roll <= 93:
		return WEATHER_RAIN
	return WEATHER_HEAVY_RAIN


func _roll_weather_for_phase(day_forecast: String, day_time: String) -> String:
	var safe_forecast: String = _normalize_weather(day_forecast)
	var safe_time: String = day_time
	if not STAGE_TIMES.has(safe_time):
		safe_time = "morning"
	if safe_time == "night":
		return _roll_night_weather_for_forecast(safe_forecast)

	var roll: int = rng.randi_range(1, 100)
	match safe_forecast:
		WEATHER_CLOUDY:
			if roll <= 70:
				return WEATHER_CLOUDY
			return DEFAULT_WEATHER
		WEATHER_RAIN:
			if roll <= 68:
				return WEATHER_RAIN
			return WEATHER_CLOUDY
		WEATHER_HEAVY_RAIN:
			if roll <= 52:
				return WEATHER_HEAVY_RAIN
			if roll <= 87:
				return WEATHER_RAIN
			return WEATHER_CLOUDY
	if roll <= 82:
		return DEFAULT_WEATHER
	return WEATHER_CLOUDY


func _roll_night_weather_for_forecast(day_forecast: String) -> String:
	var safe_forecast: String = _normalize_weather(day_forecast)
	var roll: int = rng.randi_range(1, 100)
	match safe_forecast:
		WEATHER_CLOUDY:
			if roll <= 18:
				return WEATHER_RAIN
			return DEFAULT_WEATHER
		WEATHER_RAIN:
			if roll <= 82:
				return WEATHER_RAIN
			return WEATHER_HEAVY_RAIN
		WEATHER_HEAVY_RAIN:
			if roll <= 62:
				return WEATHER_HEAVY_RAIN
			return WEATHER_RAIN
	return DEFAULT_WEATHER


func _weather_phase_key(day_number: int, day_time: String) -> String:
	return "%d:%s" % [maxi(1, day_number), day_time]


func _normalize_weather(weather_value: String) -> String:
	var safe_weather: String = str(weather_value).strip_edges().to_lower()
	if safe_weather == "heavy-rain" or safe_weather == "heavy_rain":
		safe_weather = WEATHER_HEAVY_RAIN
	if WEATHER_TYPES.has(safe_weather):
		return safe_weather
	return DEFAULT_WEATHER


# Reset helpers
func reset() -> void:
	_is_loading_save = true
	_begin_state_batch()
	_reset_resource_state()
	_apply_new_run_defaults()
	last_stage_result.clear()
	_reset_character_progress_state()
	_reset_seeded_rider_state()
	upgrades.clear()
	achievements.clear()
	_reset_story_progress_state()
	resume_scene_path = ""
	_reset_tutorial_state()
	_end_state_batch(false, true)
	_is_loading_save = false
	_delete_save_file()


func _normalize_tamad_rest_time(time_of_day: String) -> String:
	return AchievementService.normalize_tamad_rest_time(time_of_day)


func _reset_story_triggers() -> void:
	story_triggers = StoryTriggerService.build_default_story_triggers()
	consumed_story_triggers.clear()


func _reset_resource_state() -> void:
	money = 0
	max_energy = DEFAULT_MAX_ENERGY
	energy = DEFAULT_STARTING_ENERGY
	max_gas = DEFAULT_MAX_GAS_PERCENT
	gas = DEFAULT_STARTING_GAS_PERCENT
	karma = 0


func _reset_weather_state() -> void:
	gas_price = DEFAULT_GAS_PRICE
	gas_price_delta = 0
	previous_gas_price = DEFAULT_GAS_PRICE
	current_weather = DEFAULT_WEATHER
	weather_forecasts.clear()
	weather_forecasts[1] = DEFAULT_WEATHER
	weather_phase_cache.clear()
	daily_conditions_day = 1


func _reset_pending_runtime_state() -> void:
	pending_stage_energy_cost = false
	pending_trip_selection.clear()
	pending_story.clear()
	pending_sleep_transition_state.clear()
	pending_gameplay_entry_fade_duration = 0.0
	pending_result_music.clear()
	pending_skip_night_phase = false


func _reset_daily_run_state() -> void:
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


func _reset_debt_and_failure_state() -> void:
	debt_goal_index = 0
	last_debt_collection_day = 0
	remaining_debt = TOTAL_DEBT_GOAL
	run_failed = false
	run_fail_reason = ""


func _reset_character_progress_state() -> void:
	current_mock_character_id = ""
	seen_mock_characters.clear()
	unique_character_progress.clear()
	locked_unique_character_stories.clear()
	consumed_unique_session_dialogue.clear()


func _reset_seeded_rider_state() -> void:
	seeded_rider_rules.clear()
	consumed_seeded_rider_rules.clear()


func _reset_story_progress_state() -> void:
	last_seen_story_sections.clear()
	last_seen_story_id = ""
	event_values.clear()
	_reset_story_triggers()


func _reset_tutorial_state() -> void:
	ride_select_tutorial_shown = false
	store_tutorial_shown = false
	home_tutorial_shown = false


func _apply_new_run_defaults() -> void:
	stage_round = 0
	current_stage_type = FIRST_STAGE_TYPE
	current_stage_special_type = STAGE_SPECIAL_TYPE_NONE
	current_special_stage_id = ""
	current_day = 1
	_reset_weather_state()
	_reset_pending_runtime_state()
	_reset_daily_run_state()
	_reset_debt_and_failure_state()
	_reset_story_triggers()


func _should_skip_night_phase_transition(transition_mode: String, current_time: String) -> bool:
	if not pending_skip_night_phase:
		return false
	var safe_transition_mode := normalize_transition_mode(str(transition_mode))
	var safe_current_time := str(current_time).strip_edges().to_lower()
	if safe_current_time == "night":
		return false
	if safe_transition_mode == TRANSITION_SLEEP_TO_NEXT_DAY or safe_transition_mode == TRANSITION_REST_TO_NEXT_DAY:
		return false
	if safe_current_time == "noon":
		return safe_transition_mode == TRANSITION_RIDE
	return safe_current_time == "morning" and safe_transition_mode == TRANSITION_REST_TO_NIGHT


func _delete_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
