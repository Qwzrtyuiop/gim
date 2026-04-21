extends RefCounted
class_name StoryTriggerRuntime

const StoryTriggerService := preload("res://scripts/story/story_trigger_service.gd")


static func find_story_trigger_for_phase(player_state, phase: String, day_number := -1, context: Dictionary = {}) -> Dictionary:
	var safe_phase: String = StoryTriggerService.normalize_story_trigger_phase(str(phase))
	if safe_phase.is_empty():
		return {}

	var effective_day: int = resolve_day_number(player_state, day_number)
	var trigger_context: Dictionary = build_context(player_state, effective_day, context)
	return StoryTriggerService.find_story_trigger_for_phase(
		player_state.story_triggers,
		player_state.consumed_story_triggers,
		player_state.event_values,
		safe_phase,
		effective_day,
		player_state.rng,
		trigger_context
	)


static func resolve_day_number(player_state, day_number := -1) -> int:
	return int(day_number) if int(day_number) > 0 else player_state.get_current_day()


static func build_context(player_state, effective_day: int, context: Dictionary = {}) -> Dictionary:
	var current_time_of_day: String = player_state.get_current_time_of_day()
	var merged_context: Dictionary = {
		"day": effective_day,
		"current_day": effective_day,
		"week": player_state.get_week_number(effective_day),
		"money": player_state.money,
		"energy": player_state.energy,
		"gas": player_state.gas,
		"gas_price": player_state.get_gas_price(),
		"karma": player_state.karma,
		"time_of_day": current_time_of_day,
		"current_time_of_day": current_time_of_day,
		"current_stage_type": player_state.get_current_stage_type(),
		"days_until_collection": player_state.get_days_until_debt_collection(effective_day),
		"weekly_goal": player_state.get_current_weekly_goal(),
		"remaining_debt": player_state.get_total_debt_goal(),
		"current_character_id": player_state.get_current_mock_character_id(),
	}
	merged_context.merge(context, true)

	var effective_character_id: String = str(merged_context.get("character_id", merged_context.get("current_character_id", ""))).strip_edges().to_lower()
	if not effective_character_id.is_empty():
		merged_context["character_id"] = effective_character_id
		merged_context["character_progress"] = player_state.get_unique_character_progress(effective_character_id)
		merged_context["current_character_progress"] = int(merged_context.get("character_progress", 0))
		var story_state: Dictionary = player_state.get_unique_character_story_state(effective_character_id, merged_context)
		if not story_state.is_empty():
			merged_context["story_stage_id"] = str(story_state.get("stage_id", ""))
			merged_context["story_stage_title"] = str(story_state.get("stage_title", ""))
			merged_context["story_arc_id"] = str(story_state.get("arc_id", ""))
			merged_context["story_arc_title"] = str(story_state.get("arc_title", ""))
	return merged_context
