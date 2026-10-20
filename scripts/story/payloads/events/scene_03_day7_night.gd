extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const FIRST_PAYMENT := GameTuning.WEEKLY_DEBT_GOALS[0]
const INTEREST_PAYMENT := 500
const COLLECTION_DAY := 8


static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.28,
			"pause_before": 0.18,
			"text": "The television plays on the background.",
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
		{
			"text": "I open my phone and check the time.",
		},
		{
			"text": "Then someone knocks.",
			"actions": [
				{
					"type": "play_music",
					"path": "res://assets/story/music/mind.mp3",
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
		{
			"speaker": "Man Outside",
			"text": "Northside Lending. Open up.",
		},
		{
			"text": "My hand reaches the lock, then stops there.",
		},
		{
			"speaker": "John Toda",
			"text": "Just... just a second.",
		},
		{
			"text": "The door opens before I can think of a better answer.",
			"actions": [
				{
					"type": "play_sfx",
					"path": StoryConstants.SFX_DOOR_OPEN,
					"volume_db": -3.0,
				},
			],
		},
		{
			"text": "Two men stand outside.",
		},
		{
			"text": "The one in front looks like he came straight from an office: clean shirt, polished shoes, smile with no warmth behind it.",
		},
		{
			"text": "The man behind him fills the doorway and says nothing.",
		},
		{
			"speaker": "Collector",
			"text": "Johnny boy.",
		},
		{
			"speaker": "John Toda",
			"text": "Good evening, sir.",
		},
		{
			"speaker": "Collector",
			"text": "Nice place. Easy to find, too.",
		},
		{
			"text": "He glances past my shoulder, taking in the room like he already owns a part of it.",
		},
		{
			"speaker": "Collector",
			"text": "Parents' house?",
		},
		{
			"speaker": "John Toda",
			"text": "I'll get the money.",
		},
		{
			"speaker": "Collector",
			"text": "Good. Don't keep me waiting.",
		},
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.22,
			"text": "I leave them at the door and go back inside.",
		},
		{
			"text": "My wallet waits on the table like it knows exactly how light it is.",
		},
	]

	var not_enough_gate_index: int = composition.size()
	composition.append({
		"text": "The bills do not reach the number they want.",
		"max_money": FIRST_PAYMENT - 1,
	})

	composition.append_array([
		{
			"text": "There is enough for the first payment.",
			"min_money": FIRST_PAYMENT,
		},
		{
			"text": "I count the bills once, then again, pressing each one flat with my thumb.",
		},
		{
			"text": "I think about every passenger who told me to hurry, every meter of gas, every peso that left faster than it came in.",
		},
		{
			"text": "The bill I returned on my second day comes back to me for a moment.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "Doing the right thing still has a cost.",
			"required_achievements": ["tapat"],
		},
		{
			"text": "I recognize the bill I kept on my second day.",
			"required_achievements": ["mapagsamantala"],
		},
		{
			"speaker": "John Toda",
			"text": "Even the easy money didn't feel easy for long.",
			"required_achievements": ["mapagsamantala"],
		},
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.22,
			"text": "I put the payment in his hand.",
			"actions": [
				{
					"type": "collect_debt",
					"day": COLLECTION_DAY,
				},
			],
		},
		{
			"text": "He counts without looking down for long, his smile barely moving.",
		},
		{
			"text": "Then he pauses.",
		},
		{
			"speaker": "Collector",
			"text": "And the interest?",
		},
		{
			"speaker": "John Toda",
			"text": "Interest?",
		},
		{
			"speaker": "Collector",
			"text": "You didn't know?",
		},
		{
			"text": "He takes my wallet from my hands.",
		},
	])

	var no_interest_gate_index: int = composition.size()
	composition.append({
		"text": "There is nothing left inside.",
		"max_money": INTEREST_PAYMENT - 1,
	})

	composition.append_array([
		{
			"text": "There is still one five-hundred-peso bill tucked inside.",
			"min_money": INTEREST_PAYMENT,
		},
		{
			"text": "He slips it out and folds it into his own pocket.",
			"actions": [
				{
					"type": "collect_first_week_interest",
					"amount": INTEREST_PAYMENT,
				},
			],
		},
		{
			"speaker": "Collector",
			"text": "Good. You're learning.",
		},
	])
	var extra_interest_end_index: int = composition.size() - 1

	var no_interest_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "Collector",
			"text": "Tsk.",
		},
		{
			"text": "He lifts two fingers without turning around.",
		},
		{
			"text": "I step forward when he keeps my wallet.",
		},
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
		{
			"background": StoryConstants.BACKGROUND_LOWANGLE_HOUSE,
			"background_fade": 0.18,
			"text": "The floor hits my shoulder before I understand I have fallen.",
		},
	])
	var no_interest_end_index: int = composition.size() - 1

	var not_enough_index: int = composition.size()
	composition.append_array([
		{
			"text": "I count them again anyway as if the amount would increase.",
		},
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.22,
			"speaker": "John Toda",
			"text": "This is what I have right now. I can get the rest tomorrow.",
		},
		{
			"text": "The collector takes the wallet instead of the money.",
		},
		{
			"speaker": "Collector",
			"text": "You made us come all the way here for this?",
		},
		{
			"speaker": "Collector",
			"text": "Tsk.",
		},
		{
			"text": "He lifts two fingers without turning around.",
		},
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
		{
			"background": StoryConstants.BACKGROUND_LOWANGLE_HOUSE,
			"background_fade": 0.18,
			"text": "The floor hits back in a raw thud.",
		},
	])
	var not_enough_end_index: int = composition.size() - 1

	var paid_departure_index: int = composition.size()
	composition.append_array([
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.2,
			"text": "He tosses the wallet back against my chest.",
		},
		{
			"speaker": "Collector",
			"text": "Next week's payment will be higher, so work hard, Johnny boy.",
		},
		{
			"text": "The large man watches me for one more second, then follows him into the dark.",
		},
	])
	var paid_departure_end_index: int = composition.size() - 1

	var violent_departure_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "Collector",
			"text": "Next week's payment will be higher, so work hard, Johnny boy.",
		},
		{
			"text": "Their footsteps leave first. Their shadows take longer.",
		},
		{
			"text": "I stay on the floor until the doorframe stops tilting.",
		},
		{
			"speaker": "John Toda",
			"text": "I'm okay.",
		},
		{
			"text": "No one is there to believe me.",
		},
		{
			"text": "I wipe the blood from my mouth with the back of my hand.",
		},
		{
			"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
			"background_fade": 0.25,
			"text": "I brace a hand against the wall and get back on my feet.",
		},
	])
	var violent_departure_end_index: int = composition.size() - 1

	var finish_index: int = composition.size()
	composition.append({
		"text": "The television is still talking inside.",
		"pause_after": 0.8,
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
	})
	composition.append({
		"text": "",
		"actions": [{"type": "show_weekly_debt_transition"}],
	})
	composition.append({
		"text": "Thus ended the first week of my new job.",
		"actions": [{"type": "hide_weekly_debt_transition"}],
	})

	composition[not_enough_gate_index]["next_index"] = not_enough_index
	composition[not_enough_gate_index]["skip_index"] = not_enough_gate_index + 1
	composition[no_interest_gate_index]["next_index"] = no_interest_index
	composition[no_interest_gate_index]["skip_index"] = no_interest_gate_index + 1
	composition[extra_interest_end_index]["next_index"] = paid_departure_index
	composition[no_interest_end_index]["next_index"] = violent_departure_index
	composition[not_enough_end_index]["next_index"] = violent_departure_index
	composition[paid_departure_end_index]["next_index"] = finish_index
	composition[violent_departure_end_index]["next_index"] = finish_index

	return {
		"story_id": "scene_03_day7_night",
		"speaker_portraits": true,
		"chapter_title": "Scene 3",
		"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
		"composition": composition,
	}
