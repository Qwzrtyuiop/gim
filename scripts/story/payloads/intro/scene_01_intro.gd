extends RefCounted

const RETURN_SCENE := "res://scenes/main_menu.tscn"
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build(next_scene: String, stage_descriptor: String) -> Dictionary:
	return {
		"story_id": "scene_01_intro",
		"chapter_title": "Prologue",
		"return_scene": RETURN_SCENE,
		"next_scene": next_scene,
		"prepare_stage_start": true,
		"stage_descriptor": stage_descriptor,
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"composition": [
			{
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"pause_before": 0.16,
				"background_fade": 0.26,
				"text": "I open my eyes.",
				"camera": {
					"zoom": 1.0,
					"focus": "left",
					"duration": 0.55,
				},
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_CITY_AMBIENCE,
						"loop": true,
						"fade_in": 0.55,
						"volume_db": -9.0,
					}
				],
			},
			{
				"text": "The morning light spills from the open window.",
			},
			{	"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_WIND_BREEZE_SFX,
						"volume_db": -7.0,
					}
				],},
			{
				"text": "I pull my blanket closer to shield myself from the cold air.",

			},
			{
				"text": "...",
			},
			{
				"text": "....",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_ALARM_SFX,
						"volume_db": -3.0,
					}
				],
			},
			{
				"text": "Ah!",

			},
			{
				"text": "I jump off the couch, startled by my own alarm.",
			},
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
					}
				],
			},
			{
				"text": "....",
			},
			{
				"speaker": "John Toda",
				"text": "Why am I in a rush?",
			},
			
			{
				"speaker": "John Toda",
				"text": "Well that's because.",
			},
			{
				"speaker": "John Toda",
				"pause_before": 0.16,
				"text": "My first day as a tricycle driver starts now.",
				"background": StoryConstants.BACKGROUND_GARAGE_NORMAL,
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
	}
