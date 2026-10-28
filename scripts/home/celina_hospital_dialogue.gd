extends RefCounted

# Talking and shopping share a scene-local shuffled pool, separate from game RNG.
const DEFAULT_LINES := [
	"Hello. Do you need something?",
	"Are you here to buy medicine?",
	"Welcome. What can I help you with?",
	"Hm? Looking for something?",
	"Just a moment. I'll be right with you.",
	"Need some first aid supplies?",
	"If you need anything, just ask.",
]
const FAMILIAR_MIN_BOND := 2
const FAMILIAR_LINES := [
	"Oh, John. Need something? Or are you just visiting again?",
	"Hello again, John. How's your hand?",
]
const CLOSING_LINES := [
	"Not buying anything? That's alright.",
	"Take care on your way out.",
	"Don't forget to get some rest, okay?",
	"Hm? Changed your mind?",
	"Alright. Come back if you need anything.",
	"Well, I should get back to work.",
]

var _rng := RandomNumberGenerator.new()
var _greetings: Array = []
var _closing: Array = []
var _familiar := false
var _last_greeting := ""
var _last_closing := ""


func _init() -> void:
	_rng.randomize()


func next_greeting() -> String:
	var introduced := bool(PlayerState.get_event_value("celina_hospital_introduction_seen", false)) or bool(PlayerState.get_event_value("celina_hospital_shop_unlocked", false))
	var familiar := introduced and PlayerState.get_unique_character_progress("cel") >= FAMILIAR_MIN_BOND
	if familiar != _familiar:
		_familiar = familiar
		_greetings.clear()
	if _greetings.is_empty():
		var pool: Array = DEFAULT_LINES.duplicate()
		if familiar:
			pool.append_array(FAMILIAR_LINES)
		_refill(pool, _greetings, _last_greeting)
	_last_greeting = str(_greetings.pop_back())
	return _last_greeting


func next_closing() -> String:
	if _closing.is_empty():
		_refill(CLOSING_LINES, _closing, _last_closing)
	_last_closing = str(_closing.pop_back())
	return _last_closing


func _refill(pool: Array, bag: Array, previous: String) -> void:
	bag.assign(pool)
	# Array.shuffle uses the global RNG; keep dialogue independent of gameplay.
	for index in range(bag.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var value: Variant = bag[index]
		bag[index] = bag[other]
		bag[other] = value
	if bag.size() > 1 and str(bag.back()) == previous:
		var other := _rng.randi_range(0, bag.size() - 2)
		var value: Variant = bag[other]
		bag[other] = bag.back()
		bag[bag.size() - 1] = value
