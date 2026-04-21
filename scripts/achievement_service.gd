extends RefCounted
class_name AchievementService

const ORDER := [
	"mapagsamantala",
	"tapat",
	"sinungaling",
	"tropa",
	"maninigarilyo",
	"tamad",
	"matipid",
	"masipag",
	"maparaan",
	"matiyaga",
	"maingat",
]

const DEFINITIONS := {
	"mapagsamantala": {
		"title": "Mapagsamantala",
		"subtitle": "Opportunistic",
		"description": "Taking advantage when the opportunity presents itself\nespecially when it costs someone else more than it costs you.\n\nJohn saw the opening and took it.\nWhether it was right or not didn't matter, he needed the money more than them.",
	},
	"tapat": {
		"title": "Tapat",
		"subtitle": "Honesty",
		"description": "Tapat is the Filipino virtue of staying honest even when hardship makes the wrong choice feel easier.\n\nJohn gave the money back, even when he badly needed it himself.",
	},
	"sinungaling": {
		"title": "Sinungaling",
		"subtitle": "Liar",
		"description": "Sometimes a lie is less about fooling someone else and more about hiding from what you became.\n\nJohn smiled, made something up, and let Benny believe it.",
	},
	"tropa": {
		"title": "Tropa",
		"subtitle": "Crew",
		"description": "Years can change work, debt, and where life leaves you, but some friendships still feel like they were only waiting for you to return.\n\nFor one night, John got to be with his people again.",
	},
	"maninigarilyo": {
		"title": "Maninigarilyo",
		"subtitle": "Smoker",
		"description": "In the Philippines, approximately 18.5% to 19.5% of Filipino adults are current tobacco users.\n\nToday John became one.",
	},
	"tamad": {
		"title": "Tamad",
		"subtitle": "Lazy",
		"description": "In Filipino culture, pagiging tamad is often criticized because it burdens the family and community.\n\nJohn chose to rest when the road still called.",
	},
	"matipid": {
		"title": "Matipid",
		"subtitle": "Frugal",
		"description": "Pagiging matipid is a valued Filipino virtue, stretching limited resources to keep the household afloat.\n\nJohn reached the first collection day without spending on anything except gas.",
	},
	"masipag": {
		"title": "Masipag",
		"subtitle": "Diligent",
		"description": "Masipag is the admired Filipino work ethic of showing up and pushing through hardship for the family.\n\nJohn stayed on the road and finished three long rides in a single day.",
	},
	"maparaan": {
		"title": "Maparaan",
		"subtitle": "Resourceful",
		"description": "Maparaan is the Filipino knack for finding a way to survive when resources run thin.\n\nJohn completed five rides while at 5 energy or less and 20% gas or less.",
	},
	"matiyaga": {
		"title": "Matiyaga",
		"subtitle": "Persevering",
		"description": "Matiyaga reflects the Filipino value of patience and steady endurance through long struggles.\n\nJohn completed five rides while running low on either energy (5 or less) or gas (20% or less).",
	},
	"maingat": {
		"title": "Maingat",
		"subtitle": "Careful",
		"description": "Being maingat means acting with care for safety, a practical virtue on Filipino roads.\n\nFive stages in a row, no crashes. John kept the tricycle steady.",
	},
}

const SMOKER_YOSI_GOAL := 10
const SMOKER_MAX_ENERGY_PENALTY := 2
const SMOKER_DANGER_YOSI_TOTAL := 50
const TAMAD_REQUIRED_REST_TIMES := ["morning", "noon", "night"]
const LOW_ENERGY_THRESHOLD := 5
const LOW_RESOURCE_STREAK_TARGET := 5


static func get_yosi_energy_restore(player_state) -> int:
	return 3 if has_achievement(player_state, "maninigarilyo") else 2


static func record_yosi_purchase(player_state, amount := 1) -> int:
	var purchase_amount := maxi(0, int(amount))
	if purchase_amount <= 0:
		return player_state.yosi_bought_total

	if player_state.yosi_bought_day != player_state.get_current_day():
		player_state._reset_daily_consumable_counters(player_state.get_current_day())

	player_state.yosi_bought_day = player_state.get_current_day()
	player_state.yosi_bought_today += purchase_amount
	player_state.yosi_bought_total += purchase_amount
	if player_state.yosi_bought_today >= SMOKER_YOSI_GOAL:
		unlock_achievement(player_state, "maninigarilyo")
	if player_state.yosi_bought_total >= SMOKER_DANGER_YOSI_TOTAL:
		player_state.fail_run("John finally had to be taken to the hospital.\n\nThe cigarettes caught up with him long before the debt ever did, and the treatment only left him buried under even more bills.")
	player_state.save_progress()
	return player_state.yosi_bought_total


static func record_rest(player_state, amount := 1, time_of_day := "") -> int:
	var rest_amount := maxi(0, int(amount))
	if rest_amount <= 0:
		return player_state.rests_taken_today

	if player_state.rests_taken_day != player_state.get_current_day():
		player_state._reset_daily_consumable_counters(player_state.get_current_day())

	player_state.rests_taken_day = player_state.get_current_day()
	player_state.rests_taken_today += rest_amount
	_record_tamad_rest_time(player_state, str(time_of_day))
	player_state.save_progress()
	return player_state.rests_taken_today


static func record_stage_completion(player_state) -> void:
	if player_state.rides_completed_day != player_state.get_current_day():
		player_state._reset_daily_consumable_counters(player_state.get_current_day())

	player_state.rides_completed_day = player_state.get_current_day()
	if str(player_state.get_last_stage_result().get("difficulty", "")) == "long":
		player_state.rides_completed_today += 1
	if player_state.rides_completed_today >= 3:
		unlock_achievement(player_state, "masipag")

	player_state.clean_stage_streak += 1
	if player_state.clean_stage_streak >= 5:
		unlock_achievement(player_state, "maingat")

	var ended_low_energy: bool = player_state.current_trip_low_energy or player_state.energy <= LOW_ENERGY_THRESHOLD
	var ended_low_gas: bool = player_state.current_trip_low_gas or player_state.is_low_gas()
	if ended_low_energy or ended_low_gas:
		player_state.low_resource_trip_count += 1
		if player_state.low_resource_trip_count >= LOW_RESOURCE_STREAK_TARGET:
			unlock_achievement(player_state, "matiyaga")
	if ended_low_energy and ended_low_gas:
		player_state.low_both_resource_trip_count += 1
		if player_state.low_both_resource_trip_count >= LOW_RESOURCE_STREAK_TARGET:
			unlock_achievement(player_state, "maparaan")

	player_state.current_trip_low_energy = false
	player_state.current_trip_low_gas = false
	player_state.save_progress()


static func record_stage_failure(player_state) -> void:
	player_state.clean_stage_streak = 0
	player_state.current_trip_low_energy = false
	player_state.current_trip_low_gas = false
	player_state.save_progress()


static func unlock_achievement(player_state, achievement_id: String) -> void:
	var safe_id := str(achievement_id).strip_edges().to_lower()
	if not DEFINITIONS.has(safe_id):
		return
	if player_state.achievements.get(safe_id, false):
		return

	player_state.achievements[safe_id] = true
	_apply_achievement_effects(player_state, safe_id)
	player_state.achievement_unlocked.emit(safe_id)
	player_state.save_progress()


static func has_achievement(player_state, achievement_id: String) -> bool:
	return bool(player_state.achievements.get(str(achievement_id).strip_edges().to_lower(), false))


static func get_achievement_data(player_state, achievement_id: String) -> Dictionary:
	var safe_id := str(achievement_id).strip_edges().to_lower()
	if not DEFINITIONS.has(safe_id):
		return {}

	var achievement_data: Dictionary = DEFINITIONS[safe_id]
	var result := achievement_data.duplicate(true)
	result["id"] = safe_id
	result["unlocked"] = has_achievement(player_state, safe_id)
	return result


static func get_unlocked_achievement_ids(player_state) -> Array[String]:
	var unlocked_ids: Array[String] = []
	for achievement_id in ORDER:
		var safe_id := str(achievement_id)
		if has_achievement(player_state, safe_id):
			unlocked_ids.append(safe_id)
	return unlocked_ids


static func apply_achievement_effects(player_state, achievement_id: String) -> void:
	_apply_achievement_effects(player_state, achievement_id)


static func reset_daily_consumable_counters(player_state, day_number: int) -> void:
	player_state.yosi_bought_day = max(1, day_number)
	player_state.yosi_bought_today = 0
	player_state.rests_taken_day = max(1, day_number)
	player_state.rests_taken_today = 0
	player_state.tamad_rest_day = max(1, day_number)
	player_state.tamad_rest_times_today.clear()
	player_state.rides_completed_day = max(1, day_number)
	player_state.rides_completed_today = 0


static func normalize_tamad_rest_time(time_of_day: String) -> String:
	var safe_time := str(time_of_day).strip_edges().to_lower()
	return safe_time if TAMAD_REQUIRED_REST_TIMES.has(safe_time) else ""


static func _record_tamad_rest_time(player_state, time_of_day: String) -> void:
	var rest_time := normalize_tamad_rest_time(time_of_day)
	if rest_time.is_empty():
		rest_time = normalize_tamad_rest_time(player_state.get_current_time_of_day())
	if rest_time.is_empty():
		return

	if player_state.tamad_rest_day != player_state.get_current_day():
		player_state.tamad_rest_day = player_state.get_current_day()
		player_state.tamad_rest_times_today.clear()

	if not player_state.tamad_rest_times_today.has(rest_time):
		player_state.tamad_rest_times_today.append(rest_time)

	if _is_day_one_morning_rest(player_state, rest_time) or _has_all_tamad_rest_times(player_state):
		unlock_achievement(player_state, "tamad")


static func _is_day_one_morning_rest(player_state, rest_time: String) -> bool:
	return player_state.get_current_day() == 1 and rest_time == "morning"


static func _has_all_tamad_rest_times(player_state) -> bool:
	for rest_time in TAMAD_REQUIRED_REST_TIMES:
		if not player_state.tamad_rest_times_today.has(rest_time):
			return false
	return true


static func _apply_achievement_effects(player_state, achievement_id: String) -> void:
	match achievement_id:
		"maninigarilyo":
			player_state.max_energy = maxi(1, player_state.max_energy - SMOKER_MAX_ENERGY_PENALTY)
			player_state.energy = mini(player_state.energy, player_state.max_energy)
