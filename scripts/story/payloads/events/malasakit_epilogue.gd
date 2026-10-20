extends RefCounted

const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	return RandomEventPayload.build_scene("malasakit_epilogue", "Malasakit — Epilogue", [
		{"text": "One day, while I was taking a break."},
		{"speaker": "Passenger", "text": "Hello there."},
		{"text": "A familiar passenger walked toward me."},
		{"speaker": "John Toda", "text": "Hey there, did you forget your wallet today too?"},
		{"text": "I said jokingly."},
		{"speaker": "Passenger", "text": "Fortunately, not today."},
		{"text": "The passenger brought out money."},
		{"speaker": "Passenger", "text": "Here, payment for the last time."},
		{"text": "I take the payment from the passenger."},
		{
			"text": "They thanked me once more before they left.",
			"actions": [{"type": "repay_malasakit_fare"}],
		},
	])
