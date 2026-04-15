extends RefCounted

const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"


static func player_upgrade_modifiers() -> Dictionary:
	var engine_level := PlayerState.get_upgrade_level("engine_tune")
	var brakes_level := PlayerState.get_upgrade_level("brake_kit")
	var tires_level := PlayerState.get_upgrade_level("tire_grip")
	return {
		"player_acceleration_x": 1.0 + engine_level * 0.2,
		"player_max_speed": 1.0 + engine_level * 0.75,
		"player_brake_x": 1.0 + brakes_level * 0.10,
		"player_lane_lerp_x": 1.0 + tires_level * 0.08,
	}


static func store_stage_result(
	stage_type: String,
	stage_difficulty: String,
	stage_time_of_day: String,
	stage_traffic: String,
	distance: float,
	target_distance: float,
	fare_php_per_meter: float,
	overtime_seconds: float,
	overtime_fare_penalty_php_per_second: float,
	time_left: float,
	time_bonus_php_per_second: float
) -> void:
	var completed_distance: int = floori(minf(distance, target_distance))
	var base_fare: int = roundi(completed_distance * fare_php_per_meter)
	var fare_penalty: int = roundi(overtime_seconds * overtime_fare_penalty_php_per_second)
	var raw_fare: int = maxi(0, base_fare - fare_penalty)
	var raw_bonus: int = roundi(maxf(0.0, time_left) * time_bonus_php_per_second)
	var earnings_adjustment: Dictionary = PlayerState.apply_stage_earnings_modifiers(raw_fare, raw_bonus, stage_time_of_day, stage_traffic)
	var fare: int = int(earnings_adjustment.get("fare", raw_fare))
	var bonus: int = int(earnings_adjustment.get("bonus", raw_bonus))
	var total: int = fare + bonus

	PlayerState.set_last_stage_result({
		"day": PlayerState.get_current_day(),
		"stage_type": stage_type,
		"difficulty": stage_difficulty,
		"time_of_day": stage_time_of_day,
		"traffic": stage_traffic,
		"distance": completed_distance,
		"base_fare": base_fare,
		"fare_penalty": fare_penalty,
		"raw_fare": raw_fare,
		"raw_bonus": raw_bonus,
		"fare": fare,
		"bonus": bonus,
		"total": total,
		"earnings_multiplier": float(earnings_adjustment.get("multiplier", 1.0)),
		"time_left": time_left,
		"overtime": overtime_seconds,
	})
	PlayerState.record_stage_completion()


static func stage_complete_story_payload(stage_type: String, stage_difficulty: String, stage_time_of_day: String, stage_traffic: String) -> Dictionary:
	var stage_story_trigger := PlayerState.find_story_trigger_for_phase(
		PlayerState.STORY_TRIGGER_STAGE_COMPLETE,
		PlayerState.get_current_day(),
		{
			"stage_type": stage_type,
			"difficulty": stage_difficulty,
			"time_of_day": stage_time_of_day,
			"traffic": stage_traffic,
			"character_id": PlayerState.get_current_mock_character_id(),
		}
	)
	if stage_story_trigger.is_empty():
		return {}

	var story_payload := PlayerState.get_story_payload_for_trigger(stage_story_trigger)
	if story_payload.is_empty():
		return {}

	story_payload["return_scene"] = STAGE_RESULTS_SCENE
	story_payload["next_scene"] = STAGE_RESULTS_SCENE
	PlayerState.set_pending_story(story_payload)
	PlayerState.consume_story_trigger(stage_story_trigger)
	return story_payload
