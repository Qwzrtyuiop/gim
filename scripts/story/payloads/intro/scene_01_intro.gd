extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build(next_scene: String, stage_descriptor: String) -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "scene_01_intro",
		"chapter_title": "Prologue",
		"speaker_portraits": true,
		"return_scene": "res://scenes/main_menu.tscn",
		"next_scene": next_scene,
		"prepare_stage_start": true,
		"stage_descriptor": stage_descriptor,
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": {},
		"composition": [
			# 0
			{
				"text": "I open my eyes.",
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.26,
				"pause_before": 0.16,
				"camera": {
					"zoom": 1.0,
					"focus": "left",
					"duration": 0.55,
				},
				"actions": [StoryConstants.STATION_MUSIC],
			},
			# 1
			{
				"text": "The morning light spills from the open window.",
			},
			# 2
			{
				"text": "",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_WIND_BREEZE_SFX,
						"volume_db": -7.0,
					},
				],
			},
			# 3
			{
				"text": "I pull my blanket closer to shield myself from the cold air.",
			},
			# 4
			{
				"text": "...",
			},
			# 5
			{
				"text": "....",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_ALARM_SFX,
						"volume_db": -3.0,
					},
				],
			},
			# 6
			{
				"text": "Ah!",
			},
			# 7
			{
				"text": "I jump off the couch, startled by my own alarm.",
			},
			# 8
			{
				"text": "Without reading the phone, I grabbed it and ran toward the door.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"volume_db": -4.0,
					},
					{
						"type": "fade_to_black",
						"duration": 0.22,
					},
				],
			},
			# 9
			{
				"text": "....",
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "Why am I in a rush?",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Well that's because.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "My first day as a tricycle driver starts now.",
				"background": StoryConstants.BACKGROUND_GARAGE_NORMAL,
				"pause_before": 0.16,
				"camera": {
					"zoom": 1.0,
					"focus": "right",
					"duration": 0.45,
				},
				"actions": [
					{
						"type": "fade_from_black",
						"duration": 0.22,
					},
				],
			},
		],
	})
