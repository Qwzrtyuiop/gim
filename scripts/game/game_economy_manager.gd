extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const RandomRideEventService := preload("res://scripts/story/random_ride_event_service.gd")
const JessaFareEvent := preload("res://scripts/story/jessa_fare_event.gd")

const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"


static func player_upgrade_modifiers() -> Dictionary:
	var engine_level := PlayerState.get_upgrade_level("engine_tune")
	var brakes_level := PlayerState.get_upgrade_level("brake_kit")
	return {
		"player_acceleration_x": 1.0 + engine_level * GameTuning.ENGINE_ACCELERATION_BONUS_PER_LEVEL,
		"player_max_speed": 1.0 + engine_level * GameTuning.ENGINE_SPEED_BONUS_PER_LEVEL,
		"player_brake_x": 1.0 + brakes_level * GameTuning.BRAKE_POWER_BONUS_PER_LEVEL,
		"player_lane_lerp_x": 1.0,
	}


static func store_stage_result(
	stage_type: String,
	stage_difficulty: String,
	stage_time_of_day: String,
	stage_traffic: String,
	stage_special_type: String,
	special_stage_id: String,
	distance: float,
	target_distance: float,
	fare_php_per_meter: float,
	overtime_seconds: float,
	overtime_fare_penalty_php_per_second: float,
	time_left: float,
	time_bonus_php_per_second: float,
	passenger_rule_violation_count: int,
	driving_stats: Dictionary = {}
) -> void:
	var completed_distance: int = floori(minf(distance, target_distance))
	var base_fare: int = roundi(completed_distance * fare_php_per_meter)
	var fare_penalty: int = roundi(overtime_seconds * overtime_fare_penalty_php_per_second)
	var raw_fare: int = maxi(0, base_fare - fare_penalty)
	var raw_bonus: int = roundi(maxf(0.0, time_left) * time_bonus_php_per_second)
	var earnings_adjustment: Dictionary = PlayerState.apply_stage_earnings_modifiers(raw_fare, raw_bonus, stage_time_of_day, stage_traffic)
	var fare: int = int(earnings_adjustment.get("fare", raw_fare))
	var bonus: int = int(earnings_adjustment.get("bonus", raw_bonus))
	var rider_penalty_steps: int = maxi(0, floori(float(passenger_rule_violation_count) / 3.0))
	var rider_penalty: int = rider_penalty_steps * 10
	var total: int = maxi(0, fare + bonus - rider_penalty)
	var detail_lines: Array[String] = [
		"Distance: %dm" % completed_distance,
		"Fare: PhP %d" % fare,
		"Bonus: PhP %d" % bonus,
	]
	if passenger_rule_violation_count > 0:
		if rider_penalty > 0:
			detail_lines.append("Passenger Penalty: -PhP %d (%d warnings)" % [rider_penalty, passenger_rule_violation_count])
		else:
			detail_lines.append("Passenger Warnings: %d/3" % passenger_rule_violation_count)
	detail_lines.append("Total: PhP %d" % total)

	PlayerState._begin_state_batch()
	PlayerState.set_last_stage_result({
		"character_id": PlayerState.get_current_mock_character_id(),
		"day": PlayerState.get_current_day(),
		"stage_type": stage_type,
		"difficulty": stage_difficulty,
		"time_of_day": stage_time_of_day,
		"traffic": stage_traffic,
		"stage_special_type": PlayerState.normalize_stage_special_type(stage_special_type),
		"special_stage_id": PlayerState.normalize_special_stage_id(special_stage_id),
		"distance": completed_distance,
		"target_distance": maxf(0.0, target_distance),
		"base_fare": base_fare,
		"fare_penalty": fare_penalty,
		"raw_fare": raw_fare,
		"raw_bonus": raw_bonus,
		"fare": fare,
		"bonus": bonus,
		"passenger_rule_violation_count": maxi(0, int(passenger_rule_violation_count)),
		"peak_speed_kmh": maxf(0.0, float(driving_stats.get("peak_speed_kmh", 0.0))),
		"vehicle_collision_count": maxi(0, int(driving_stats.get("vehicle_collision_count", 0))),
		"had_crash": bool(PlayerState.current_trip_had_crash),
		"passenger_penalty": rider_penalty,
		"detail_lines": detail_lines,
		"total": total,
		"earnings_multiplier": float(earnings_adjustment.get("multiplier", 1.0)),
		"time_left": time_left,
		"overtime": overtime_seconds,
		"completed": true,
	})
	PlayerState.advance_phase_after_stage_result(stage_time_of_day)
	if not PlayerState.active_event_special_stage.is_empty():
		PlayerState.active_event_special_stage["completed"] = true
	PlayerState.record_stage_completion()
	PlayerState.save_progress()
	PlayerState._end_state_batch()


static func store_failed_stage_result(
	stage_type: String,
	stage_difficulty: String,
	stage_time_of_day: String,
	stage_traffic: String,
	stage_special_type: String,
	special_stage_id: String,
	distance: float,
	target_distance: float,
	failure_reason: String
) -> void:
	var completed_distance: int = floori(minf(distance, target_distance))
	var detail_lines: Array[String] = [
		"Progress: %dm / %dm" % [completed_distance, int(target_distance)],
		"Reason: %s" % failure_reason,
		"Total: PhP 0",
	]

	PlayerState.set_last_stage_result({
		"character_id": PlayerState.get_current_mock_character_id(),
		"day": PlayerState.get_current_day(),
		"stage_type": stage_type,
		"difficulty": stage_difficulty,
		"time_of_day": stage_time_of_day,
		"traffic": stage_traffic,
		"stage_special_type": PlayerState.normalize_stage_special_type(stage_special_type),
		"special_stage_id": PlayerState.normalize_special_stage_id(special_stage_id),
		"distance": completed_distance,
		"base_fare": 0,
		"fare_penalty": 0,
		"raw_fare": 0,
		"raw_bonus": 0,
		"fare": 0,
		"bonus": 0,
		"passenger_rule_violation_count": 0,
		"passenger_penalty": 0,
		"detail_lines": detail_lines,
		"total": 0,
		"earnings_multiplier": 1.0,
		"time_left": 0.0,
		"overtime": 0.0,
		"completed": false,
		"failure_reason": failure_reason,
	})
	PlayerState.advance_phase_after_stage_result(stage_time_of_day)


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
		return RandomRideEventService.prepare(PlayerState)

	var story_payload := PlayerState.get_story_payload_for_trigger(stage_story_trigger)
	if story_payload.is_empty():
		return {}

	story_payload["return_scene"] = STAGE_RESULTS_SCENE
	story_payload["next_scene"] = STAGE_RESULTS_SCENE
	PlayerState._begin_state_batch()
	JessaFareEvent.prepare(PlayerState, story_payload)
	PlayerState.set_pending_story(story_payload)
	PlayerState.consume_story_trigger(stage_story_trigger)
	PlayerState._end_state_batch()
	return story_payload
