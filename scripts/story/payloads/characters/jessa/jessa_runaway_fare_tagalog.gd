extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const CHASE := 17
const LET_GO := 25
const STORY_END := 31


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "jessa_runaway_fare",
		"chapter_title": "Runaway Fare",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "Itinigil ko ang tricycle sa destinasyon ng aking pasahero.",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "Nandito na tayo.",
			},
			# 2
			{
				"speaker": "Jessa",
				"text": "Ah, okay. Salamat po.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Yung bayad mo.",
			},
			# 4
			{
				"speaker": "Jessa",
				"text": "Sige po, sandali lang...",
			},
			# 5
			{
				"text": "Dinukot ng babae ang maliit niyang pitaka mula sa bulsa.",
			},
			# 6
			{
				"speaker": "Jessa",
				"text": "Tingnan ko lang...",
			},
			# 7
			{
				"speaker": "Jessa",
				"text": "Ay...",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Hm?",
			},
			# 9
			{
				"speaker": "Jessa",
				"text": "...",
			},
			# 10
			{
				"speaker": "Jessa",
				"text": "KUYA! SA LIKOD MO! ANO 'YON?!",
			},
			# 11
			{
				"text": "Bigla niyang itinuro ang kung ano sa likuran ko.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Ha? Ano?",
			},
			# 13
			{
				"text": "Lumingon ako, pero wala naman akong nakita.",
			},
			# 14
			{
				"speaker": "John Toda",
				"text": "Ano—",
			},
			# 15
			{
				"text": "Nang ako'y lumingon pabalik, tumatakbo na papalayo ang babae.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY,
						"loop": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "HOY!",
				"choices": [
					{
						"text": "Habulin siya.",
						"next_index": CHASE,
					},
					{
						"text": "Hayaan na siya.",
						"next_index": LET_GO,
					},
				],
			},
			# 17 — CHASE
			{
				"speaker": "John Toda",
				"text": "HOY! BUMALIK KA DITO!",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_choice",
						"value": "chase",
					},
				],
			},
			# 18
			{
				"text": "Mabilis akong bumaba ng tricycle at hinabol siya.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"loop": false,
						"volume_db": -4.0,
					},
				],
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "HINDI KA PA NAGBABAYAD!",
			},
			# 20
			{
				"speaker": "Jessa",
				"text": "SORRY, KUYA!",
			},
			# 21
			{
				"text": "Lumiko ang babae sa isang makitid na eskinita. Pagdating ko roon, hindi ko na siya makita.",
				"background": StoryConstants.BACKGROUND_ALLEY,
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "Hah... Hah...",
				"actions": [
					{
						"type": "stop_sfx",
					},
				],
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Anak ng...",
			},
			# 24
			{
				"text": "Matapos mawala ang aking hingal, naglakad ako pabalik sa tricycle. Nakakaramdam ako na hindi pa ito ang huli naming pagkikita.",
				"background": StoryConstants.BACKGROUND_STATION,
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 25 — LET_GO
			{
				"text": "Pinanood ko na lang siyang tumakbo hanggang sa mawala siya sa kanto.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_choice",
						"value": "let_go",
					},
				],
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "Haaah...",
			},
			# 28
			{
				"text": "Napabuntong-hininga ako bago bumalik sa tricycle.",
				"background": StoryConstants.BACKGROUND_STATION,
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Sayang ang pamasahe...",
			},
			# 30
			{
				"text": "Sumakay ulit ako at nagpatuloy sa biyahe. Nakakaramdam ako na hindi pa ito ang huli naming pagkikita.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
