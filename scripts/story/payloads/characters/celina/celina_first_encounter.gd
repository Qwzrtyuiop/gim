extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const STORY_END := 1


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "celina_first_encounter",
		"chapter_title": "Celina: First Event",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 - Placeholder; replace with the authored scene later.
			{
				"speaker": "Celina",
				"text": "...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
