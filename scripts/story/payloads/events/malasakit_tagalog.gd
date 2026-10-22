extends RefCounted

const RandomEventPayload := preload("res://scripts/story/payloads/events/random_event_payload.gd")


static func build() -> Dictionary:
	return RandomEventPayload.build("malasakit", "Malasakit", [
		{"speaker": "Passenger", "text": "Kuya para dito."},
		{"text": "Tinigil ko ang aking tricycle."},
		{"speaker": "John Toda", "text": "Andito na tayo."},
		{"speaker": "Passenger", "text": "Eto pamasahe ko."},
		{"speaker": "Passenger", "text": "Huh."},
		{"speaker": "Passenger", "text": "Teka, yung wallet ko."},
		{"speaker": "John Toda", "text": "Ano?"},
		{"speaker": "Passenger", "text": "Yung wallet ko kuya, naiwan ko sa bahay."},
		{"text": "Hinalungkat ng pasahero ang kanyang bag, pero wala siyang nahanap."},
		{"speaker": "Passenger", "text": "Lagot, pano na to..."},
	], [
		{"speaker": "John Toda", "text": "Edi gawahan mo nang paraan."},
		{"speaker": "Passenger", "text": "Pero wala akong pera."},
		{"speaker": "John Toda", "text": "Edi maghanap ka, Maghihintay ako dito."},
		{"speaker": "Passenger", "text": "Sige po..."},
		{"text": "Bumaba ang pasahero at pumasok siya sa building."},
		{"text": "Makalipas ang ilang minuto siya ay lumabas at binigay ang kanyang bayad."},
	], [
		{"speaker": "John Toda", "text": "Hay... Sige na nga."},
		{"speaker": "Passenger", "text": "Bakit?"},
		{"speaker": "John Toda", "text": "Bumaba ka na, libre na eto."},
		{"speaker": "Passenger", "text": "Talaga?"},
		{"speaker": "John Toda", "text": "Bayaran mo nalang sa susunod kung maalala mo. Isang biyahe lang naman to e."},
		{"speaker": "Passenger", "text": "Thank you."},
	], ["\"Edi gawahan mo nang paraan.\"", "Palampasin nang walang bayad"])
