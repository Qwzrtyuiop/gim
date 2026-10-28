extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Keep section 1 as the completion target for saved placeholder encounters.
const INTRODUCTION := 2
const NOT_VISITED_BAR := 28
const VISITED_BAR := 31
const COMMON := 36
const STORY_END := 57


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "alma_first_encounter",
		"chapter_title": "Small World",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 - Entry; skip the legacy completion section.
			{
				"text": "to be translated",
				"next_index": INTRODUCTION,
			},
			# 1 - Legacy completion for saved placeholder encounters.
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_first_encounter_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "alma_name_revealed",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 - INTRODUCTION
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 5
			{
				"text": "to be translated",
			},
			# 6
			{
				"text": "to be translated",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 10
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 12
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 14
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 19
			{
				"text": "to be translated",
			},
			# 20
			{
				"text": "to be translated",
			},
			# 21
			{
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 23
			{
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 26
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 27
			{
				"text": "to be translated",
				"next_index": NOT_VISITED_BAR,
			},
			# 28 - NOT_VISITED_BAR
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
				"conditions": {
					"forbidden_event_values": {
						"bar_visited": true,
					},
				},
				"skip_index": VISITED_BAR,
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 30
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
				"next_index": COMMON,
			},
			# 31 - VISITED_BAR
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
				"conditions": {
					"required_event_values": {
						"bar_visited": true,
					},
				},
				"skip_index": COMMON,
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 33
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 34
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 35
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 36 - COMMON
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 37
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_name_revealed",
						"value": true,
					},
				],
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 39
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 40
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 41
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 42
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 43
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 44
			{
				"text": "to be translated",
			},
			# 45
			{
				"text": "to be translated",
			},
			# 46
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 47
			{
				"text": "to be translated",
			},
			# 48
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 49
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 50
			{
				"text": "to be translated",
			},
			# 51
			{
				"text": "to be translated",
			},
			# 52
			{
				"text": "to be translated",
			},
			# 53
			{
				"text": "to be translated",
			},
			# 54
			{
				"text": "to be translated",
			},
			# 55
			{
				"text": "to be translated",
			},
			# 56
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_first_encounter_seen",
						"value": true,
					},
				],
			},
		],
	})
