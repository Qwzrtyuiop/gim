extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")
const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	var composition: Array = [
		{"text": "I finally arrive at the passenger's destination."},
		{"speaker": "John Toda", "text": "Alright, we're here."},
		{"speaker": "Jessa", "text": "Oh, okay. Thanks."},
		{"speaker": "John Toda", "text": "That'll be the fare, miss.", "ride_fare_line": true},
		{"speaker": "Jessa", "text": "Right, just a second..."},
		{"text": "The girl reaches into her pocket and pulls out a small wallet."},
		{"speaker": "Jessa", "text": "Let's see..."},
		{"speaker": "Jessa", "text": "Oh..."},
		{"speaker": "John Toda", "text": "Hm?"},
		{"speaker": "Jessa", "text": "..."},
		{"speaker": "Jessa", "text": "Hey! What's that?!"},
		{"text": "She suddenly points at something behind me."},
		{"speaker": "John Toda", "text": "Huh? What?"},
		{"text": "I turn around, but there's nothing there."},
		{"speaker": "John Toda", "text": "What are you—"},
		{
			"text": "By the time I look back, the girl is already running down the street.",
			"actions": [{
				"type": "play_music",
				"path": "res://assets/audio/music/story/funny.mp3",
				"loop": true,
				"fade_in": 0.0,
				"fade_out": 0.0,
				"volume_db": -9.0,
			}],
		},
		{"speaker": "John Toda", "text": "HEY!"},
	]
	var choice_index := composition.size() - 1
	var chase_index := composition.size()
	composition.append_array([
		{"speaker": "John Toda", "text": "Get back here!"},
		{
			"text": "I jump out of the tricycle and run after her.",
			"actions": [{
				"type": "play_sfx", "path": StoryConstants.MUSIC_RUNNING_SFX,
				"loop": false, "volume_db": -4.0,
			}],
		},
		{"speaker": "John Toda", "text": "HEY! YOU HAVEN'T PAID YET!"},
		{"speaker": "Jessa", "text": "SORRY!"},
		{"text": "The girl turns into a narrow alley. By the time I reach it, she's nowhere to be seen.", "background": StoryConstants.BACKGROUND_ALLEY},
		{"speaker": "John Toda", "text": "Hah... Hah...", "actions": [{"type": "stop_sfx"}]},
		{"speaker": "John Toda", "text": "You've got to be kidding me..."},
		{"text": "After catching my breath, I walk back to my tricycle. I have a feeling this isn't the last time I'll see her.", "background": StoryConstants.BACKGROUND_STATION},
	])
	var let_go_index := composition.size()
	composition.append_array([
		{"text": "I watch the girl disappear around the corner."},
		{"speaker": "John Toda", "text": "..."},
		{"speaker": "John Toda", "text": "Haaah..."},
		{"text": "I let out a long sigh, then turn back toward my tricycle.", "background": StoryConstants.BACKGROUND_STATION},
		{"speaker": "John Toda", "text": "There goes my fare."},
		{"text": "I get back in and continue driving. I have a feeling this isn't the last time I'll see her."},
	])
	composition[choice_index]["choices"] = [
		{"text": "Chase her.", "next_index": chase_index},
		{"text": "Let her go.", "next_index": let_go_index},
	]
	for branch: Dictionary in [
		{"start": chase_index, "end": let_go_index - 1, "choice": "chase"},
		{"start": let_go_index, "end": composition.size() - 1, "choice": "let_go"},
	]:
		composition[branch.start]["actions"] = [
			{"type": "set_event_value", "id": "jessa_runaway_fare_choice", "value": branch.choice},
		]
		composition[branch.end]["actions"] = [
			{"type": "set_event_value", "id": "jessa_runaway_fare_seen", "value": true},
		]
		composition[branch.end]["next_index"] = composition.size()
	return RandomEventPayload.build_scene("jessa_runaway_fare", "Runaway Fare", composition)
