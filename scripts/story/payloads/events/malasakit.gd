extends RefCounted

const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	return RandomEventPayload.build("malasakit", "Malasakit", [
		{"text": "I stop at the destination."},
		{"speaker": "John Toda", "text": "We're here."},
		{"speaker": "Passenger", "text": "Okay let me just get..."},
		{"speaker": "Passenger", "text": "Huh."},
		{"speaker": "Passenger", "text": "My wallet... it's not here."},
		{"speaker": "John Toda", "text": "What?"},
		{"speaker": "Passenger", "text": "I don't have my wallet. I must have left it at home."},
		{"text": "The passenger frantically searches their bag, but doesn't find anything."},
		{"speaker": "Passenger", "text": "What should I do..."},
	], [
		{"speaker": "John Toda", "text": "Do something about it then."},
		{"speaker": "Passenger", "text": "But I don't have money."},
		{"speaker": "John Toda", "text": "Maybe try borrowing from someone, I'll wait here."},
		{"speaker": "Passenger", "text": "Oh, ok."},
		{"text": "The passenger gets off and heads inside the building."},
		{"text": "After a few minutes they returned, bringing the fare."},
	], [
		{"speaker": "John Toda", "text": "Ehh... It's fine."},
		{"speaker": "Passenger", "text": "What?"},
		{"speaker": "John Toda", "text": "I said it's fine, there's nothing we can do about it."},
		{"speaker": "Passenger", "text": "Really?"},
		{"speaker": "John Toda", "text": "Just pay me next time or something. It's just one ride anyway."},
		{"speaker": "Passenger", "text": "Thank you."},
	], ["Do something about it, then.", "Let him off without paying"])
