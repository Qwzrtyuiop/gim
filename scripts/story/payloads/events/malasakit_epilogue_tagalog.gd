extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "malasakit_epilogue",
		"chapter_title": "Malasakit — Epilogue",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "Isang araw, habang ako ay nagpapahinga sa biyahe.",
			},
			# 1
			{
				"speaker": "Passenger",
				"text": "Kamusta na kayo kuya?",
			},
			# 2
			{
				"text": "Lumapit saakin ang isang pamilyar na pasahero.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Kamusta. Naiwan mo ulit wallet mo?",
			},
			# 4
			{
				"text": "Sinabi ko nang pabiro.",
			},
			# 5
			{
				"speaker": "Passenger",
				"text": "Hahaha, hindi ngayon kuya.",
			},
			# 6
			{
				"text": "Naglabas ng pera ang pasahero.",
			},
			# 7
			{
				"speaker": "Passenger",
				"text": "Eto, yung bayad para sa nakaraan.",
			},
			# 8
			{
				"text": "Tinanggap ko ang kanyang bayad.",
			},
			# 9
			{
				"text": "Nagpasalamat muli ang pasahero bago siya umalis.",
				"actions": [
					{
						"type": "repay_malasakit_fare",
					},
				],
			},
		],
	})
