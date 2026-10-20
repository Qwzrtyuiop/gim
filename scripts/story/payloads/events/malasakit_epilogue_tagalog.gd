extends RefCounted

const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	return RandomEventPayload.build_scene("malasakit_epilogue", "Malasakit — Epilogue", [
		{"text": "Isang araw, habang ako ay nagpapahinga sa biyahe."},
		{"speaker": "Passenger", "text": "Kamusta na kayo kuya?"},
		{"text": "Lumapit saakin ang isang pamilyar na pasahero."},
		{"speaker": "John Toda", "text": "Kamusta. Naiwan mo ulit wallet mo?"},
		{"text": "Sinabi ko nang pabiro."},
		{"speaker": "Passenger", "text": "Hahaha, hindi ngayon kuya."},
		{"text": "Naglabas ng pera ang pasahero."},
		{"speaker": "Passenger", "text": "Eto, yung bayad para sa nakaraan."},
		{"text": "Tinanggap ko ang kanyang bayad."},
		{
			"text": "Nagpasalamat muli ang pasahero bago siya umalis.",
			"actions": [{"type": "repay_malasakit_fare"}],
		},
	])
