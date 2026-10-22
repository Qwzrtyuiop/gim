extends RefCounted

const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	var composition: Array = [
		{"text": "While driving down the road, I notice a tricycle parked by the roadside. Its driver is standing beside it, looking troubled."},
		{"speaker": "Driver", "text": "Hey! Boss! Hold on a second!"},
		{"speaker": "John Toda", "text": "Hm? What's wrong?"},
		{"speaker": "Driver", "text": "I ran out of gas. The gas station isn't that far, but this thing's too heavy to push alone."},
		{"speaker": "Driver", "text": "Mind giving me a hand?"},
		{"speaker": "John Toda", "text": "Ah..."},
	]
	var choice_index := composition.size() - 1
	var help_index := composition.size()
	composition.append_array([
		{"speaker": "John Toda", "text": "Alright, I'll help you."},
		{"speaker": "Driver", "text": "Great! Thanks, boss!"},
		{"text": "I park my tricycle somewhere safe and help him push his toward the gas station."},
		{"speaker": "John Toda", "text": "Man, this thing's heavy..."},
		{"speaker": "Driver", "text": "Sorry about that. I thought I had enough gas to make it."},
		{"speaker": "John Toda", "text": "Next time, check your tank."},
		{"speaker": "Driver", "text": "Yeah, I really should. Haha!"},
		{"text": "After a few minutes of pushing, we finally reach the gas station."},
		{"speaker": "Driver", "text": "Thanks a lot, boss. You really saved me there!"},
		{"speaker": "John Toda", "text": "Don't mention it. Take care."},
		{
			"text": "I return to my tricycle and continue driving.",
			"actions": [
				{"type": "resolve_bayanihan", "outcome": "help"},
			],
		},
	])
	var decline_index := composition.size()
	composition.append_array([
		{"speaker": "John Toda", "text": "Sorry, boss. I've got somewhere to be."},
		{"speaker": "Driver", "text": "Oh, is that so? Alright, no problem."},
		{"speaker": "John Toda", "text": "The gas station's pretty close, right?"},
		{"speaker": "Driver", "text": "Yeah. I think I can manage."},
		{"speaker": "John Toda", "text": "Alright. Take care."},
		{"text": "I drive past him. In my side mirror, I can see the driver slowly pushing his tricycle along the roadside."},
		{"speaker": "John Toda", "text": "..."},
		{
			"text": "I continue on my way.",
			"actions": [{"type": "resolve_bayanihan", "outcome": "decline"}],
		},
	])
	composition[choice_index]["choices"] = [
		{"text": "\"Sure, I'll help.\"\nWarning: You will lose one turn.", "next_index": help_index},
		{"text": "\"Sorry, I'm busy.\"", "next_index": decline_index},
	]
	composition[decline_index - 1]["next_index"] = composition.size()
	composition[-1]["next_index"] = composition.size()
	return RandomEventPayload.build_scene("bayanihan", "Bayanihan", composition)
