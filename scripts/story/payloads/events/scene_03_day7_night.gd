extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const FIRST_PAYMENT := GameTuning.WEEKLY_DEBT_GOALS[0]
const INTEREST_PAYMENT := 500
const COLLECTION_DAY := 8

# Zero-based section targets. Keep these aligned with the composition below.
const PAYMENT_AVAILABLE := 20
const INTEREST_AVAILABLE := 35
const INTEREST_UNPAID := 38
const PAYMENT_SHORT := 43
const PAID_DEPARTURE := 51
const VIOLENT_DEPARTURE := 54
const WEEK_END := 61


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "scene_03_day7_night",
		"chapter_title": "Scene 3",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
		"music": {},
		"composition": [
			# 0
			{
				"text": "The television plays on the background.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.28,
				"pause_before": 0.18,
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.45,
				},
				"actions": [
					{
						"type": "stop_music",
						"fade_out": 0.2,
					},
				],
			},
			# 1
			{
				"text": "I open my phone and check the time.",
			},
			# 2
			{
				"text": "Then someone knocks.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_MIND,
						"loop": true,
						"fade_in": 0.0,
						"volume_db": -9.0,
					},
					{
						"type": "play_sfx",
						"path": StoryConstants.SFX_KNOCK,
						"volume_db": -2.0,
					},
					{
						"type": "wait",
						"duration": 0.35,
					},
				],
			},
			# 3
			{
				"speaker": "Man Outside",
				"text": "Northside Lending. Open up.",
			},
			# 4
			{
				"text": "My hand reaches the lock, then stops there.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Just... just a second.",
			},
			# 6
			{
				"text": "The door opens with a silent creak.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.SFX_DOOR_OPEN,
						"volume_db": -3.0,
					},
				],
			},
			# 7
			{
				"text": "Two men stand outside.",
			},
			# 8
			{
				"text": "The one in front looks like he came straight from an office: clean shirt, polished shoes, smile with no warmth behind it.",
			},
			# 9
			{
				"text": "The man behind him fills the doorway and says nothing.",
			},
			# 10
			{
				"speaker": "Collector",
				"text": "Johnny boy.",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Good evening, sir.",
			},
			# 12
			{
				"speaker": "Collector",
				"text": "Nice place. Easy to find, too.",
			},
			# 13
			{
				"text": "He glances past my shoulder, looking around the room like he already owns a part of it.",
			},
			# 14
			{
				"speaker": "Collector",
				"text": "Parents' house?",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "I'll get the money.",
			},
			# 16
			{
				"speaker": "Collector",
				"text": "Good. Don't keep me waiting.",
			},
			# 17
			{
				"text": "I leave them at the door and go back inside.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.22,
			},
			# 18
			{
				"text": "My wallet waits on the table.",
			},
			# 19
			{
				"text": "The bills do not reach the number they want.",
				"max_money": FIRST_PAYMENT - 1,
				"next_index": PAYMENT_SHORT,
				"skip_index": PAYMENT_AVAILABLE,
			},
			# 20 — PAYMENT_AVAILABLE
			{
				"text": "There is enough for the first payment.",
				"min_money": FIRST_PAYMENT,
			},
			# 21
			{
				"text": "I count the bills once, then again, pressing each one flat with my thumb.",
			},
			# 22
			{
				"text": "I think about every passenger who told me to hurry, every meter of gas, every peso that left faster than it came in.",
			},
			# 23
			{
				"text": "I remember yhe bill I returned on my second day.",
				"required_achievements": ["tapat"],
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "I guess even doing the right thing still has a cost.",
				"required_achievements": ["tapat"],
			},
			# 25
			{
				"text": "I recognize the bill I kept on my second day.",
				"required_achievements": ["mapagsamantala"],
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "This is Karma, I guess.",
				"required_achievements": ["mapagsamantala"],
			},
			# 27
			{
				"text": "I put the payment in his hand. Bills first, then the coins.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.22,
				"actions": [
					{
						"type": "collect_debt",
						"day": COLLECTION_DAY,
					},
				],
			},
			# 28
			{
				"text": "He counts without looking down for long, his smile barely moving.",
			},
			# 29
			{
				"text": "Then he pauses.",
			},
			# 30
			{
				"speaker": "Collector",
				"text": "And the interest?",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "Interest?",
			},
			# 32
			{
				"speaker": "Collector",
				"text": "You didn't know?",
			},
			# 33
			{
				"text": "He takes my wallet from my hands.",
			},
			# 34
			{
				"text": "There is nothing left inside.",
				"max_money": INTEREST_PAYMENT - 1,
				"next_index": INTEREST_UNPAID,
				"skip_index": INTEREST_AVAILABLE,
			},
			# 35 — INTEREST_AVAILABLE
			{
				"text": "There is still one five-hundred-peso bill tucked inside.",
				"min_money": INTEREST_PAYMENT,
			},
			# 36
			{
				"text": "He slips it out and folds it into his own pocket.",
				"actions": [
					{
						"type": "collect_first_week_interest",
						"amount": INTEREST_PAYMENT,
					},
				],
			},
			# 37
			{
				"speaker": "Collector",
				"text": "Good. You're learning.",
				"next_index": PAID_DEPARTURE,
			},
			# 38 — INTEREST_UNPAID
			{
				"speaker": "Collector",
				"text": "Tsk.",
			},
			# 39
			{
				"text": "He lifts two fingers without turning around.",
			},
			# 40
			{
				"text": "I step forward when he keeps my wallet.",
			},
			# 41
			{
				"text": "The quiet man moves faster than he looks.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.SFX_HIT,
						"volume_db": -1.5,
					},
				],
			},
			# 42
			{
				"text": "I fall to the floor with a painful thud.",
				"background": StoryConstants.BACKGROUND_LOWANGLE_HOUSE,
				"background_fade": 0.18,
				"next_index": VIOLENT_DEPARTURE,
			},
			# 43 — PAYMENT_SHORT
			{
				"text": "I count them again anyway as if the amount would increase.",
			},
			# 44
			{
				"speaker": "John Toda",
				"text": "This is what I have right now. I can get the rest tomorrow.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.22,
			},
			# 45
			{
				"text": "The collector takes the wallet instead of the money.",
			},
			# 46
			{
				"speaker": "Collector",
				"text": "You made us come all the way here for this?",
			},
			# 47
			{
				"speaker": "Collector",
				"text": "Tsk.",
			},
			# 48
			{
				"text": "He lifts two fingers without turning around.",
			},
			# 49
			{
				"text": "I step forward, but the man behind him is already there.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.SFX_HIT,
						"volume_db": -1.5,
					},
					{
						"type": "collect_debt",
						"day": COLLECTION_DAY,
					},
				],
			},
			# 50
			{
				"text": "I fall to the floor with a painful thud.",
				"background": StoryConstants.BACKGROUND_LOWANGLE_HOUSE,
				"background_fade": 0.18,
				"next_index": VIOLENT_DEPARTURE,
			},
			# 51 — PAID_DEPARTURE
			{
				"text": "He tosses the wallet back against my chest.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.2,
			},
			# 52
			{
				"speaker": "Collector",
				"text": "Next week's payment will be higher, so work hard, Johnny boy.",
			},
			# 53
			{
				"text": "The large man watches me for one more second, then follows him into the dark.",
				"next_index": WEEK_END,
			},
			# 54 — VIOLENT_DEPARTURE
			{
				"speaker": "Collector",
				"text": "Next week's payment will be higher, so work hard, Johnny boy.",
			},
			# 55
			{
				"text": "Their footsteps leave first. Their shadows take longer.",
			},
			# 56
			{
				"text": "I stay on the floor until the doorframe stops tilting.",
			},
			# 57
			{
				"speaker": "John Toda",
				"text": "I'm okay.",
			},
			# 58
			{
				"text": "...",
			},
			# 59
			{
				"text": "I wipe the blood from my mouth with the back of my hand.",
			},
			# 60
			{
				"text": "I brace a hand against the wall and get back on my feet.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.25,
				"next_index": WEEK_END,
			},
			# 61 — WEEK_END
			{
				"text": "The sound of the television drowns whatever was on my mind.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "scene_03_day7_night_seen",
						"value": 1,
					},
					{
						"type": "fade_to_black",
						"duration": 0.35,
					},
				],
				"pause_after": 0.8,
			},
			# 62
			{
				"text": "",
				"actions": [
					{
						"type": "show_weekly_debt_transition",
					},
				],
			},
			# 63
			{
				"text": "Thus ended the first week of my new job.",
				"actions": [
					{
						"type": "hide_weekly_debt_transition",
					},
				],
			},
		],
	})
