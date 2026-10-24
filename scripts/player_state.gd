extends Node

const PlayerSpecialStageState := preload("res://scripts/state/player_special_stage_state.gd")

const GameTuning := preload("res://scripts/config/game_tuning.gd")

# Central run-state authority.
# If a feature needs to survive scene changes or be saved, it usually belongs here.

# Shared services
const AchievementService := preload("res://scripts/achievement_service.gd")
const PlayerStateSaveCodec := preload("res://scripts/save/player_state_save_codec.gd")
const PlayerCharacterProgressState := preload("res://scripts/state/player_character_progress_state.gd")
const PlayerCrashRepairState := preload("res://scripts/state/player_crash_repair_state.gd")
const PlayerDayPhaseTracker := preload("res://scripts/state/player_day_phase_tracker.gd")
const PlayerDebtState := preload("res://scripts/state/player_debt_state.gd")
const PlayerPendingState := preload("res://scripts/state/player_pending_state.gd")
const PlayerResourceState := preload("res://scripts/state/player_resource_state.gd")
const PlayerRunState := preload("res://scripts/state/player_run_state.gd")
const PlayerStageState := preload("res://scripts/state/player_stage_state.gd")
const PlayerStoryState := preload("res://scripts/state/player_story_state.gd")
const PlayerUpgradeState := preload("res://scripts/state/player_upgrade_state.gd")
const PlayerWeatherState := preload("res://scripts/state/player_weather_state.gd")
const SeededRiderRuntime := preload("res://scripts/seeded_rider_runtime.gd")
const StoryCatalog := preload("res://scripts/story/story_catalog.gd")

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
const WEEKLY_DEBT_GOALS := GameTuning.WEEKLY_DEBT_GOALS
const DEFAULT_STARTING_ENERGY := GameTuning.DEFAULT_STARTING_ENERGY
const DEFAULT_MAX_ENERGY := GameTuning.DEFAULT_MAX_ENERGY
const DEFAULT_STARTING_GAS_PERCENT := GameTuning.DEFAULT_STARTING_GAS_PERCENT
const DEFAULT_MAX_GAS_PERCENT := GameTuning.DEFAULT_MAX_GAS_PERCENT
const GAS_CAN_PERCENT := GameTuning.GAS_CAN_PERCENT
const GAS_DRAIN_PERCENT_PER_1000_UNITS := GameTuning.GAS_DRAIN_PERCENT_PER_1000_UNITS
const FUEL_EFFICIENCY_UPGRADE_ID := "fuel_efficiency"
const LEGACY_TIRE_GRIP_UPGRADE_ID := "tire_grip"
const FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL := GameTuning.FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL
const FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL := GameTuning.FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL
const LOW_GAS_PERCENT_THRESHOLD := GameTuning.LOW_GAS_PERCENT_THRESHOLD
const DEFAULT_GAS_PRICE := GameTuning.DEFAULT_GAS_PRICE
const DAILY_GAS_PRICE_MAX_PERCENT_CHANGE := GameTuning.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE
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
const SAVE_VERSION := 4
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
var current_phase := "morning"
var stage_round := 0
var pending_stage_energy_cost := false
var pending_trip_selection: Dictionary = {}
var pending_story: Dictionary = {}
var active_event_special_stage: Dictionary = {}
var pending_sleep_transition_state: Dictionary = {}
var pending_crash_repair: Dictionary = {}
var pending_gameplay_entry_fade_duration := 0.0
var pending_result_music: Dictionary = {}
var pending_skip_night_phase := false
var current_mock_character_id := ""
var seen_mock_characters: Dictionary = {}
var unique_character_progress: Dictionary = {}
var character_completed_rides: Dictionary = {}
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
var current_trip_had_crash := false
var current_trip_low_energy := false
var current_trip_low_gas := false
var low_resource_trip_count := 0
var low_both_resource_trip_count := 0
var debt_goal_index := 0
var last_debt_collection_day := 0
var remaining_debt := TOTAL_DEBT_GOAL
var debt_carryover := 0
var last_debt_collection: Dictionary = {}
var run_failed := false
var run_fail_reason := ""
var rng := RandomNumberGenerator.new()
var story_triggers: Array[Dictionary] = []
var consumed_story_triggers: Dictionary = {}
var last_seen_story_sections: Dictionary = {}
var last_seen_story_id := ""
var event_values: Dictionary = {}
var unlocked_gallery_images: Dictionary = {}
var gallery_image_unlocks_initialized: bool = true
var resume_scene_path := ""
var ride_select_tutorial_shown := false
var store_tutorial_shown := false
var home_tutorial_shown := false

# Save-flow guards
var _is_loading_save := false
var _suppress_auto_save := false
var _has_deferred_save := false
var _state_batch_depth := 0

# Gallery playback is transient; it must never replace the saved live story.
var pending_memory_replay: Dictionary = {}

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
	PlayerStoryState.set_last_seen_story_section(self, story_id, section_index)


func get_last_seen_story_section(story_id: String) -> int:
	return PlayerStoryState.get_last_seen_story_section(self, story_id)


func get_last_seen_story_id() -> String:
	return PlayerStoryState.get_last_seen_story_id(self)


func has_seen_story(story_id: String) -> bool:
	return PlayerStoryState.has_seen_story(self, story_id)


func get_seen_story_ids() -> Array[String]:
	return PlayerStoryState.get_seen_story_ids(self)


func unlock_gallery_image(image_path: String) -> bool:
	return PlayerStoryState.unlock_gallery_image(self, image_path)


func unlock_gallery_images(image_paths: Array) -> int:
	return PlayerStoryState.unlock_gallery_images(self, image_paths)


func get_unlocked_gallery_image_paths() -> Array[String]:
	return PlayerStoryState.get_unlocked_gallery_image_paths(self)


func set_event_value(event_id: String, value) -> void:
	PlayerStoryState.set_event_value(self, event_id, value)


func set_event_values(values: Dictionary) -> void:
	PlayerStoryState.set_event_values(self, values)


func get_event_value(event_id: String, default_value = null):
	return PlayerStoryState.get_event_value(self, event_id, default_value)


func has_event_value(event_id: String) -> bool:
	return PlayerStoryState.has_event_value(self, event_id)


func clear_event_value(event_id: String) -> void:
	PlayerStoryState.clear_event_value(self, event_id)


func get_event_values() -> Dictionary:
	return PlayerStoryState.get_event_values(self)


func clear_event_values() -> void:
	PlayerStoryState.clear_event_values(self)


func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func set_resume_scene(scene_path: String) -> void:
	PlayerStoryState.set_resume_scene(self, scene_path)


func get_resume_scene() -> String:
	return PlayerStoryState.get_resume_scene(self)


# Tutorial state
func has_ride_select_tutorial_shown() -> bool:
	return PlayerStoryState.has_ride_select_tutorial_shown(self)


func mark_ride_select_tutorial_shown() -> void:
	PlayerStoryState.mark_ride_select_tutorial_shown(self)


func has_store_tutorial_shown() -> bool:
	return PlayerStoryState.has_store_tutorial_shown(self)


func mark_store_tutorial_shown() -> void:
	PlayerStoryState.mark_store_tutorial_shown(self)


func has_home_tutorial_shown() -> bool:
	return PlayerStoryState.has_home_tutorial_shown(self)


func mark_home_tutorial_shown() -> void:
	PlayerStoryState.mark_home_tutorial_shown(self)


# Run setup and progression
func begin_stage_sequence() -> void:
	PlayerRunState.begin_stage_sequence(self)


func get_current_stage_type() -> String:
	if not active_event_special_stage.is_empty():
		return str(active_event_special_stage["definition"]["stage_type"])
	return PlayerRunState.current_stage_type(self)


func begin_event_special_stage(stage_id: String, continuation: String) -> bool:
	return PlayerSpecialStageState.begin(self, stage_id, continuation)


func finish_event_special_stage() -> String:
	return PlayerSpecialStageState.finish(self)


func normalize_stage_special_type(stage_special_type: String) -> String:
	return PlayerStageState.normalize_stage_special_type(self, stage_special_type)


func normalize_special_stage_id(special_stage_id: String) -> String:
	return PlayerStageState.normalize_special_stage_id(self, special_stage_id)


func set_current_stage_special_type(stage_special_type: String) -> void:
	PlayerStageState.set_current_stage_special_type(self, stage_special_type)


func get_current_stage_special_type() -> String:
	if not active_event_special_stage.is_empty():
		return STAGE_SPECIAL_TYPE_SPECIAL
	return PlayerStageState.get_current_stage_special_type(self)


func set_current_special_stage_id(special_stage_id: String) -> void:
	PlayerStageState.set_current_special_stage_id(self, special_stage_id)


func get_current_special_stage_id() -> String:
	if not active_event_special_stage.is_empty():
		return str(active_event_special_stage["id"])
	return PlayerStageState.get_current_special_stage_id(self)


func get_stage_special_display_name(stage_special_type: String) -> String:
	return PlayerStageState.stage_special_display_name(self, stage_special_type)


func get_current_day() -> int:
	return PlayerDayPhaseTracker.get_current_day(self)


func get_current_debt_goal() -> int:
	return get_current_weekly_goal()


func get_total_debt_goal() -> int:
	return max(0, remaining_debt)


func get_current_weekly_goal() -> int:
	return PlayerDebtState.current_weekly_goal(self)


func get_days_until_debt_collection(day_number := -1) -> int:
	return PlayerDebtState.days_until_debt_collection(self, day_number)


func get_week_number(day_number := -1) -> int:
	return PlayerDebtState.week_number(self, day_number)


func get_stage_distance_range(difficulty: String) -> Vector2:
	return PlayerStageState.stage_distance_range(self, difficulty)


func get_stage_distance_average(difficulty: String) -> float:
	return PlayerStageState.stage_distance_average(self, difficulty)


func roll_stage_target_distance(difficulty: String) -> float:
	return PlayerStageState.roll_stage_target_distance(self, difficulty)


func get_debt_status_text(day_number := -1) -> String:
	return PlayerDebtState.debt_status_text(self, day_number)


func get_debt_due_text(day_number := -1) -> String:
	return PlayerDebtState.debt_due_text(self, day_number)


func get_current_time_of_day() -> String:
	return PlayerDayPhaseTracker.get_current_phase(self)


func normalize_transition_mode(transition_mode: String) -> String:
	return PlayerRunState.normalize_transition_mode(self, transition_mode)


func get_next_stage_time(transition_mode: String = TRANSITION_RIDE) -> String:
	return PlayerDayPhaseTracker.next_phase(self, transition_mode)


func can_rest_after_stage() -> bool:
	return PlayerRunState.can_rest_after_stage(self)


func can_rest_after_stage_result(stage_time_of_day: String, stage_day := -1) -> bool:
	return PlayerRunState.can_rest_after_stage_result(self, stage_time_of_day, stage_day)


func has_rested_today() -> bool:
	return PlayerRunState.has_rested_today(self)


func get_transition_display_day(transition_mode: String = TRANSITION_RIDE) -> int:
	return PlayerDayPhaseTracker.transition_display_day(self, transition_mode)


func get_home_ride_transition_mode() -> String:
	return PlayerDayPhaseTracker.home_ride_transition_mode(self)


# Economy and resource helpers
func get_distance_gas_cost(distance_units: float) -> float:
	return PlayerResourceState.distance_gas_cost(self, distance_units)


func estimate_stage_gas_usage(stage_type: String) -> float:
	return PlayerResourceState.estimate_stage_gas_usage(self, stage_type)


func get_distance_gas_consumption_multiplier() -> float:
	return PlayerResourceState.distance_gas_consumption_multiplier(self)


func get_boost_gas_consumption_multiplier() -> float:
	return PlayerResourceState.boost_gas_consumption_multiplier(self)


func get_fuel_efficiency_level() -> int:
	return PlayerUpgradeState.fuel_efficiency_level(self)


func get_gas_price() -> int:
	return PlayerWeatherState.gas_price(self)


func get_gas_price_text() -> String:
	return PlayerWeatherState.gas_price_text(self)


func get_gas_price_change_text() -> String:
	return PlayerWeatherState.gas_price_change_text(self)


func get_gas_price_yesterday_percent_text() -> String:
	return PlayerWeatherState.gas_price_yesterday_percent_text(self)


func set_gas_price(price: int) -> void:
	PlayerWeatherState.set_gas_price(self, price)


func get_current_weather() -> String:
	return PlayerWeatherState.current_weather(self)


func get_current_weather_text() -> String:
	return PlayerWeatherState.current_weather_text(self)


func get_today_weather_forecast() -> String:
	return PlayerWeatherState.today_weather_forecast(self)


func get_tomorrow_weather_forecast() -> String:
	return PlayerWeatherState.tomorrow_weather_forecast(self)


func get_weather_forecast_for_day(day_number: int) -> String:
	return PlayerWeatherState.weather_forecast_for_day(self, day_number)


func get_stage_weather(day_time := "") -> String:
	return PlayerWeatherState.stage_weather(self, day_time)


func weather_text(weather_value: String) -> String:
	return PlayerWeatherState.weather_text(self, weather_value)


func get_daily_news_text() -> String:
	return PlayerWeatherState.daily_news_text(self)


func ensure_daily_conditions_for_current_day() -> void:
	PlayerWeatherState.ensure_daily_conditions_for_current_day(self)


func add_gas(amount: float) -> void:
	PlayerResourceState.add_gas(self, amount)


func spend_gas(amount: float, save_immediately := true) -> bool:
	return PlayerResourceState.spend_gas(self, amount, save_immediately)


func drain_gas(amount: float, save_immediately := true) -> float:
	return PlayerResourceState.drain_gas(self, amount, save_immediately)


func gas_text() -> String:
	return PlayerResourceState.gas_text(self)


func gas_capacity_text() -> String:
	return PlayerResourceState.gas_capacity_text(self)


func gas_ratio() -> float:
	return PlayerResourceState.gas_ratio(self)


func is_low_gas() -> bool:
	return PlayerResourceState.is_low_gas(self)


func get_energy_vehicle_modifiers() -> Dictionary:
	return PlayerResourceState.energy_vehicle_modifiers(self)


func boost_gas_is_available() -> bool:
	return PlayerResourceState.boost_gas_is_available(self)


func apply_night_rest_bonus() -> int:
	return PlayerResourceState.apply_night_rest_bonus(self)


func get_stage_start_error(stage_descriptor := "") -> String:
	return PlayerResourceState.stage_start_error(self, stage_descriptor)


func get_stage_start_error_after_transition(stage_descriptor := "", transition_mode: String = TRANSITION_RIDE) -> String:
	return PlayerResourceState.stage_start_error_after_transition(self, stage_descriptor, transition_mode)


func prepare_stage_start(stage_descriptor := "") -> bool:
	return PlayerResourceState.prepare_stage_start(self, stage_descriptor)


func prepare_stage_start_after_transition(stage_descriptor := "", transition_mode: String = TRANSITION_RIDE) -> bool:
	return PlayerResourceState.prepare_stage_start_after_transition(self, stage_descriptor, transition_mode)


func confirm_stage_started() -> void:
	PlayerResourceState.confirm_stage_started(self)


func will_advance_day(transition_mode: String = TRANSITION_RIDE) -> bool:
	return PlayerDayPhaseTracker.will_advance_day(self, transition_mode)


func get_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	return PlayerDayPhaseTracker.transition_energy_bonus(self, transition_mode)


func apply_transition_energy_bonus(transition_mode: String = TRANSITION_RIDE) -> int:
	return PlayerResourceState.apply_transition_energy_bonus(self, transition_mode)


# Stage flow and transitions
func advance_to_next_stage(transition_mode: String = TRANSITION_RIDE, selected_difficulty := "", forced_traffic := "") -> String:
	return PlayerRunState.advance_to_next_stage(self, transition_mode, selected_difficulty, forced_traffic)


func advance_phase_after_stage_result(stage_time_of_day: String) -> bool:
	return PlayerRunState.advance_phase_after_stage_result(self, stage_time_of_day)


func prepare_day_start(target_day: int) -> void:
	PlayerRunState.prepare_day_start(self, target_day)


func set_current_stage_time(day_time: String) -> void:
	PlayerRunState.set_current_stage_time(self, day_time)


func _random_stage_type_for_time(day_time: String, selected_difficulty := "", forced_traffic := "") -> String:
	return PlayerStageState.random_stage_type_for_time(self, day_time, selected_difficulty, forced_traffic)


func _parse_stage_type(type_name: String) -> Dictionary:
	return PlayerStageState.parse_stage_type(self, type_name)


func add_money(amount: int) -> void:
	PlayerResourceState.add_money(self, amount)


func spend_money(amount: int) -> bool:
	return PlayerResourceState.spend_money(self, amount)


func add_energy(amount: int) -> void:
	PlayerResourceState.add_energy(self, amount)


func add_max_energy(amount: int) -> void:
	PlayerResourceState.add_max_energy(self, amount)


func spend_energy(amount: int) -> bool:
	return PlayerResourceState.spend_energy(self, amount)


func add_karma(amount: int) -> void:
	PlayerResourceState.add_karma(self, amount)


func set_last_stage_result(result: Dictionary) -> void:
	PlayerStageState.set_last_stage_result(self, result)


func get_last_stage_result() -> Dictionary:
	return PlayerStageState.get_last_stage_result(self)


func claim_last_stage_total() -> int:
	return PlayerStageState.claim_last_stage_total(self)


func is_run_failed() -> bool:
	return run_failed


func get_run_fail_reason() -> String:
	return run_fail_reason


# Pending scene and transition state
func set_pending_trip_selection(return_scene: String, transition_mode: String = TRANSITION_RIDE, allow_back := true) -> void:
	PlayerPendingState.set_pending_trip_selection(self, return_scene, transition_mode, allow_back)


func get_pending_trip_selection() -> Dictionary:
	return PlayerPendingState.get_pending_trip_selection(self)


func has_locked_pending_trip_selection() -> bool:
	return PlayerPendingState.has_locked_pending_trip_selection(self)


func get_locked_pending_trip_character_pools() -> Dictionary:
	return PlayerPendingState.get_locked_pending_trip_character_pools(self)


func get_locked_pending_trip_characters() -> Array:
	return PlayerPendingState.get_locked_pending_trip_characters(self)


func get_locked_pending_trip_distance() -> String:
	return PlayerPendingState.get_locked_pending_trip_distance(self)


func lock_pending_trip_selection(locked_character_data, selected_distance: String) -> void:
	PlayerPendingState.lock_pending_trip_selection(self, locked_character_data, selected_distance)


func clear_pending_trip_selection() -> void:
	PlayerPendingState.clear_pending_trip_selection(self)


# Seeded rider runtime
func add_seeded_rider_rule(rule_data: Dictionary) -> void:
	SeededRiderRuntime.add_rule(self, rule_data)


func seed_rider_for_stage(character_id: String, day: int, time_of_day := "", distance := "", slot := -1, forced_traffic := "", repeatable := false) -> void:
	SeededRiderRuntime.seed_rider_for_stage(self, character_id, day, time_of_day, distance, slot, forced_traffic, repeatable)


func clear_seeded_rider_rules() -> void:
	SeededRiderRuntime.clear_rules(self)


func get_seeded_rider_rules() -> Array:
	return SeededRiderRuntime.get_rules(self)


func consume_seeded_rider_rules(rule_ids: Array) -> void:
	SeededRiderRuntime.consume_player_rules(self, rule_ids)


func get_seeded_rider_pool_setup(selection_context: Dictionary) -> Dictionary:
	return SeededRiderRuntime.get_pool_setup(self, selection_context)


# Pending story state
func set_pending_story(story_payload: Dictionary, save_immediately: bool = true) -> void:
	PlayerPendingState.set_pending_story(self, story_payload, save_immediately)


func get_pending_story() -> Dictionary:
	return PlayerPendingState.get_pending_story(self)


func clear_pending_story() -> void:
	PlayerPendingState.clear_pending_story(self)


func set_pending_memory_replay(story_payload: Dictionary) -> void:
	PlayerPendingState.set_pending_memory_replay(self, story_payload)


func get_pending_memory_replay() -> Dictionary:
	return PlayerPendingState.get_pending_memory_replay(self)


func clear_pending_memory_replay() -> void:
	PlayerPendingState.clear_pending_memory_replay(self)


func set_pending_sleep_transition_state(state: Dictionary) -> void:
	PlayerPendingState.set_pending_sleep_transition_state(self, state)


func begin_crash_repair() -> void:
	PlayerCrashRepairState.begin(self)


func get_pending_crash_repair() -> Dictionary:
	return pending_crash_repair.duplicate(true)


func start_crash_repair_transition() -> bool:
	return PlayerCrashRepairState.start_transition(self)


func prepare_crash_repair_day() -> void:
	PlayerCrashRepairState.prepare_recovery_day(self)


func finish_crash_repair() -> void:
	PlayerCrashRepairState.finish(self)


func get_pending_sleep_transition_state() -> Dictionary:
	return PlayerPendingState.get_pending_sleep_transition_state(self)


func clear_pending_sleep_transition_state() -> void:
	PlayerPendingState.clear_pending_sleep_transition_state(self)


func set_pending_gameplay_entry_fade(duration: float) -> void:
	PlayerPendingState.set_pending_gameplay_entry_fade(self, duration)


func consume_pending_gameplay_entry_fade() -> float:
	return PlayerPendingState.consume_pending_gameplay_entry_fade(self)


func clear_pending_gameplay_entry_fade() -> void:
	PlayerPendingState.clear_pending_gameplay_entry_fade(self)


func set_pending_result_music(music_state: Dictionary) -> void:
	PlayerPendingState.set_pending_result_music(self, music_state)


func has_pending_night_phase_skip() -> bool:
	return PlayerPendingState.has_pending_night_phase_skip(self)


func set_pending_night_phase_skip(enabled: bool) -> void:
	PlayerPendingState.set_pending_night_phase_skip(self, enabled)


func clear_pending_night_phase_skip() -> void:
	PlayerPendingState.clear_pending_night_phase_skip(self)


func consume_pending_result_music() -> Dictionary:
	return PlayerPendingState.consume_pending_result_music(self)


func clear_pending_result_music() -> void:
	PlayerPendingState.clear_pending_result_music(self)


func set_sleep_transition_resume_step(resume_step: String) -> void:
	PlayerPendingState.set_sleep_transition_resume_step(self, resume_step)


func get_sleep_transition_resume_step() -> String:
	return PlayerPendingState.get_sleep_transition_resume_step(self)


# Story trigger state
func add_story_trigger(trigger_data: Dictionary) -> void:
	PlayerStoryState.add_story_trigger(self, trigger_data)


func clear_story_triggers() -> void:
	PlayerStoryState.clear_story_triggers(self)


func get_story_triggers() -> Array:
	return PlayerStoryState.get_story_triggers(self)


func normalize_story_trigger_phase(phase: String) -> String:
	return PlayerStoryState.normalize_story_trigger_phase(phase)


func find_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> Dictionary:
	return PlayerStoryState.find_story_trigger_for_phase(self, phase, day_number, context)


func has_story_trigger_for_phase(phase: String, day_number := -1, context: Dictionary = {}) -> bool:
	return PlayerStoryState.has_story_trigger_for_phase(self, phase, day_number, context)


func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	return PlayerStoryState.get_story_payload_for_trigger(trigger_data)


func consume_story_trigger(trigger_data: Dictionary) -> void:
	PlayerStoryState.consume_story_trigger(self, trigger_data)


# Character catalog and stage previews
func get_mock_characters() -> Array:
	return StoryCatalog.get_mock_characters(self)


func get_character_by_id(character_id: String) -> Dictionary:
	return StoryCatalog.get_character_by_id(self, character_id)


func get_character_display_name(character_id: String) -> String:
	return StoryCatalog.get_character_display_name(self, character_id)


func get_speaker_display_name(speaker: String) -> String:
	return StoryCatalog.get_speaker_display_name(self, speaker)


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
	return PlayerStageState.random_stage_traffic_type(self)


func build_stage_type(difficulty: String, day_time: String, traffic_type: String) -> String:
	return PlayerStageState.build_stage_type(self, difficulty, day_time, traffic_type)


func get_stage_earnings_multiplier(day_time: String, traffic_type: String) -> float:
	return PlayerStageState.stage_earnings_multiplier(self, day_time, traffic_type)


func apply_stage_earnings_modifiers(fare: int, bonus: int, day_time: String, traffic_type: String) -> Dictionary:
	return PlayerStageState.apply_stage_earnings_modifiers(self, fare, bonus, day_time, traffic_type)


func estimate_stage_earnings(stage_type: String, character_id := "") -> int:
	return PlayerStageState.estimate_stage_earnings(self, stage_type, character_id)


# Achievements and failure state
func _should_collect_debt_for_day(day_number: int) -> bool:
	return PlayerDebtState.should_collect_for_day(self, day_number)


func _resolve_debt_collection_for_day(day_number: int) -> bool:
	return PlayerDebtState.resolve_collection_for_day(self, day_number)


func set_current_mock_character(character_id: String) -> void:
	PlayerCharacterProgressState.set_current_mock_character(self, character_id)


func get_current_mock_character_id() -> String:
	return PlayerCharacterProgressState.get_current_mock_character_id(self)


func mark_mock_character_seen(character_id: String) -> void:
	PlayerCharacterProgressState.mark_mock_character_seen(self, character_id)


func has_seen_mock_character(character_id: String) -> bool:
	return PlayerCharacterProgressState.has_seen_mock_character(self, character_id)


func get_unique_character_progress(character_id: String) -> int:
	return PlayerCharacterProgressState.unique_character_progress(self, character_id)


func is_unique_character_story_locked(character_id: String) -> bool:
	return PlayerCharacterProgressState.is_unique_character_story_locked(self, character_id)


func set_unique_character_story_locked(character_id: String, locked := true) -> bool:
	return PlayerCharacterProgressState.set_unique_character_story_locked(self, character_id, locked)


func set_unique_character_progress(character_id: String, progress: int) -> int:
	return PlayerCharacterProgressState.set_unique_character_progress(self, character_id, progress)


func increment_unique_character_progress(character_id: String, amount := 1) -> int:
	return PlayerCharacterProgressState.increment_unique_character_progress(self, character_id, amount)


func has_consumed_unique_session_dialogue(entry_id: String) -> bool:
	return PlayerCharacterProgressState.has_consumed_unique_session_dialogue(self, entry_id)


func consume_unique_session_dialogue(entry_id: String) -> void:
	PlayerCharacterProgressState.consume_unique_session_dialogue(self, entry_id)


func is_unique_character(character_id: String) -> bool:
	return PlayerCharacterProgressState.is_unique_character(character_id)


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	PlayerUpgradeState.set_upgrade_level(self, upgrade_id, level)


func get_upgrade_level(upgrade_id: String) -> int:
	return PlayerUpgradeState.get_upgrade_level(self, upgrade_id)


func get_yosi_energy_restore() -> int:
	return AchievementService.get_yosi_energy_restore(self)


func record_yosi_purchase(amount := 1) -> int:
	return AchievementService.record_yosi_purchase(self, amount)


func record_rest(amount := 1, time_of_day := "") -> int:
	return AchievementService.record_rest(self, amount, time_of_day)


func record_store_purchase(item_type: String) -> void:
	var safe_item_type: String = str(item_type).strip_edges().to_lower()
	if safe_item_type.is_empty() or safe_item_type == "gas":
		return
	non_gas_store_purchases_this_week += 1
	save_progress()


func record_stage_completion() -> void:
	if is_unique_character(current_mock_character_id):
		character_completed_rides[current_mock_character_id] = maxi(0, int(character_completed_rides.get(current_mock_character_id, 0))) + 1
		increment_unique_character_progress(current_mock_character_id)
	AchievementService.record_stage_completion(self)


func record_stage_crash() -> void:
	AchievementService.record_stage_crash(self)


func record_stage_failure() -> void:
	AchievementService.record_stage_failure(self)


func unlock_achievement(achievement_id: String) -> void:
	AchievementService.unlock_achievement(self, achievement_id)


func fail_run(reason: String) -> void:
	var safe_reason: String = str(reason).strip_edges()
	run_failed = true
	run_fail_reason = safe_reason if not safe_reason.is_empty() else "John's run came to an end."
	save_progress()


func has_achievement(achievement_id: String) -> bool:
	return AchievementService.has_achievement(self, achievement_id)


func get_achievement_data(achievement_id: String) -> Dictionary:
	return AchievementService.get_achievement_data(self, achievement_id)


func get_unlocked_achievement_ids() -> Array[String]:
	return AchievementService.get_unlocked_achievement_ids(self)


# Weather and daily condition state
func _reset_daily_consumable_counters(day_number: int) -> void:
	AchievementService.reset_daily_consumable_counters(self, day_number)


func _roll_daily_conditions_for_day(day_number: int) -> void:
	PlayerWeatherState.roll_daily_conditions_for_day(self, day_number)


func _ensure_weather_forecast_for_day(day_number: int) -> bool:
	return PlayerWeatherState.ensure_weather_forecast_for_day(self, day_number)


func _roll_weather_forecast() -> String:
	return PlayerWeatherState.roll_weather_forecast(self)


func _roll_weather_for_phase(day_forecast: String, day_time: String) -> String:
	return PlayerWeatherState.roll_weather_for_phase(self, day_forecast, day_time)


func _roll_night_weather_for_forecast(day_forecast: String) -> String:
	return PlayerWeatherState.roll_night_weather_for_forecast(self, day_forecast)


func _weather_phase_key(day_number: int, day_time: String) -> String:
	return PlayerWeatherState.weather_phase_key(day_number, day_time)


func _normalize_weather(weather_value: String) -> String:
	return PlayerWeatherState.normalize_weather(self, weather_value)


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
	PlayerStoryState.reset_story_triggers(self)


func _reset_resource_state() -> void:
	PlayerResourceState.reset_resource_state(self)


func _reset_weather_state() -> void:
	PlayerWeatherState.reset_weather_state(self)


func _reset_pending_runtime_state() -> void:
	PlayerPendingState.reset_pending_runtime_state(self)


func _reset_daily_run_state() -> void:
	PlayerRunState.reset_daily_run_state(self)


func _reset_debt_and_failure_state() -> void:
	PlayerDebtState.reset_debt_and_failure_state(self)


func _reset_character_progress_state() -> void:
	PlayerCharacterProgressState.reset_character_progress_state(self)


func _reset_seeded_rider_state() -> void:
	seeded_rider_rules.clear()
	consumed_seeded_rider_rules.clear()


func _reset_story_progress_state() -> void:
	PlayerStoryState.reset_story_progress_state(self)


func _reset_tutorial_state() -> void:
	PlayerStoryState.reset_tutorial_state(self)


func _apply_new_run_defaults() -> void:
	PlayerRunState.apply_new_run_defaults(self)


func _should_skip_night_phase_transition(transition_mode: String, current_time: String) -> bool:
	return PlayerRunState.should_skip_night_phase_transition(self, transition_mode, current_time)


func _delete_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
