extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const TELL_TRUTH := 14
const LIE := 27
const STORY_END := 39


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "elena_old_acquaintance",
		"chapter_title": "An Old Acquaintance",
		"speaker_portraits": true,
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.DRIVING_CHILL_MUSIC,
		"ambient_sfx": {
			"loop": true,
			"path": StoryConstants.SFX_ENGINE,
			"volume_db": -12.0,
		},
		"composition": [
			# 0
			{
				"text": "Habang bumibiyahe ako sa dati kong ruta, biglang nagsalita ang matandang babae na nakasakay sa tricycle ko.",
			},
			# 1
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Excuse me, iho.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Po?",
			},
			# 3
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Ikaw ba 'yan, John?",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Ha?",
			},
			# 5
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "John Toda, tama ba?",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "Ah... Opo. Magkakilala po ba tayo?",
			},
			# 7
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Ay, ikaw nga! Naku, ang laki mo na!",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Pasensya na po, pero...",
			},
			# 9
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Ay, oo nga pala. Ako si Elena. Dati akong guro rito.",
				"introduces_speaker": true,
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "Ah...",
			},
			# 11
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Kilala ko ang tatay mo, si Juan. Ang tagal na rin mula noong huli ko siyang nakita.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Gano'n po ba.",
			},
			# 13
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Kumusta na pala siya ngayon? Mabuti naman ba ang lagay niya?",
				"choices": [
					{
						"text": "Sabihin ang totoo",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Magsinungaling",
						"next_index": LIE,
					},
				],
			},
			# 14 — TELL_TRUTH
			{
				"speaker": "John Toda",
				"text": "Patay na po siya.",
				"actions": [
					{
						"type": "stop_music",
						"fade_out": 0.0,
					},
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_answer",
						"value": "truth",
					},
					{
						"type": "unlock_achievement",
						"id": "tapat",
					},
				],
			},
			# 15
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ay...",
			},
			# 16
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Hindi... Hindi ko alam. Pasensya ka na, iho.",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "Ayos lang po.",
			},
			# 18
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Kung pwede ko lang itanong, kailan pa siya...",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "Matagal na rin po.",
			},
			# 20
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Gano'n ba...",
			},
			# 21
			{
				"text": "Tahimik na lumipas ang natitirang biyahe.",
			},
			# 22
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ay, dito na pala ako.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Sige po.",
			},
			# 24
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Salamat sa paghatid, John.",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "Walang anuman po.",
			},
			# 26
			{
				"text": "Nagbayad siya ng pamasahe at bumaba ng tricycle.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 27 — LIE
			{
				"speaker": "John Toda",
				"text": "Hindi ko po alam.",
				"actions": [
					StoryConstants.DRIVING_CHILL_MUSIC,
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_answer",
						"value": "lie",
					},
					{
						"type": "unlock_achievement",
						"id": "sinungaling",
					},
				],
			},
			# 28
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ay, bakit naman?",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Matagal ko na rin po kasi siyang hindi nakikita.",
			},
			# 30
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ah, gano'n ba...",
			},
			# 31
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Sana naman ay nasa mabuti siyang kalagayan.",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Opo.",
			},
			# 33
			{
				"text": "Doon na natapos ang usapan namin at nagpatuloy ako sa pagmamaneho.",
			},
			# 34
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ay, dito na pala ako.",
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "Sige po.",
			},
			# 36
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Salamat sa paghatid, John.",
			},
			# 37
			{
				"speaker": "John Toda",
				"text": "Walang anuman po.",
			},
			# 38
			{
				"text": "Nagbayad siya ng pamasahe at bumaba ng tricycle.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
