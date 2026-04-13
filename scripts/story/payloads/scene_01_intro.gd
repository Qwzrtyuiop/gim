extends RefCounted

const RETURN_SCENE := "res://scenes/main_menu.tscn"
const INHOUSE_BACKGROUND := "res://assets/story/backgrounds/inhouse.png"
const GARAGE_BACKGROUND := "res://assets/story/backgrounds/garagenormal.png"


static func build(next_scene: String, stage_descriptor: String) -> Dictionary:
	return {
		"story_id": "scene_01_intro",
		"chapter_title": "Prologue",
		"return_scene": RETURN_SCENE,
		"next_scene": next_scene,
		"prepare_stage_start": true,
		"stage_descriptor": stage_descriptor,
		"background": INHOUSE_BACKGROUND,
		"composition": [
			{
				"background": INHOUSE_BACKGROUND,
				"pause_before": 0.16,
				"background_fade": 0.26,
				"text": "I open my eyes.",
				"camera": {
					"zoom": 1.0,
					"focus": "left",
					"duration": 0.55,
				},
			},
			{
				"text": "The morning light, accompanied by a cold wind enters through the open window.",
			},
			{
				"text": "...",
			},
			{
				"text": "....",
			},
			{
				"text": "Ah!",
				"actions": [
					{
						"type": "cue_phone_sound",
					}
				],
			},
			{
				"text": "I jump off the couch, startled by my own alarm.",
			},
			{
				"text": "Without reading the phone, I grabbed it and ran toward the door.",
				"actions": [
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
				"background": GARAGE_BACKGROUND,
				"camera": {
					"zoom": 1.0,
					"focus": "right",
					"duration": 0.45,
				},
				"actions": [
					{
						"type": "fade_from_black",
						"duration": 0.22,
					}
				],
			},
		],
	}
