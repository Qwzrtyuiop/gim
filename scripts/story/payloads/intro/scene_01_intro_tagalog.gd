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
				"text": "Nagsisimula nanaman ang panibagong araw.",
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
				"text": "Pumasok ang liwanag ng umaga mula sa bukas na bintana.",
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
				"text": "Hinila ko pataas ang aking kumot para iwasan ang malamig na hangin.",
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
				"text": "Anak nang-",
			},
			# 7
			{
				"text": "Napatalon ako mula sa aking sopa dahil sa tunog ng sarili kong alarm.",
			},
			# 8
			{
				"text": "Hindi ko na binasa ang nakasulat sa aking cellphone. Dinampot ko ito sa aking tabi at tumakbo ako palabas sa pinto.",
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
				"text": "Bakit nga ba ako nagmamadali?",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Nagmamadali ako dahil-",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Ngayon ang aking unang araw ng trabaho bilang isang Tricycle Driver.",
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
