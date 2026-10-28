extends RefCounted

const STORY_ID := "alma_special_delivery"
const SUCCESS_STORY_ID := "alma_special_delivery_success"
const RETURN_EVENT := "hub_story_return"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"


static func is_available() -> bool:
	return (
		PlayerState.get_unique_character_progress("alma") >= 2
		and bool(PlayerState.get_event_value("alma_first_encounter_seen", false))
		and not bool(PlayerState.get_event_value("alma_special_delivery_started", false))
		and not bool(PlayerState.get_event_value("alma_special_delivery_seen", false))
		and PlayerState.get_current_time_of_day() == "night"
		and not PlayerState.is_midnight()
		and not PlayerState.is_run_failed()
	)


static func entry_error() -> String:
	if not PlayerState.active_event_special_stage.is_empty() or not PlayerState.pending_story.is_empty():
		return ""
	return PlayerState.get_stage_start_error("long-night-busy", STORY_ID)


static func prepare_bar_return() -> void:
	PlayerState.set_event_value(RETURN_EVENT, {
		"location": "bar",
		"map_region": "town",
		"show_map": false,
		"inside_bar": true,
		"story_id": SUCCESS_STORY_ID,
	})
