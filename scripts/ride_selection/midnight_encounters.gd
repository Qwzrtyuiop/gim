extends RefCounted

# Encounters are separate from passenger offers and never start a ride.
const GARDO_ID := "gardo_midnight_encounter"
const ROLL_EVENT := "gardo_midnight_spawn"
const SPAWN_CHANCE := 0.35
const BOOSTED_SPAWN_CHANCE := 0.70
const BOOST_EVENT := "gardo_midnight_encounter_boost"
const GARDO_LINES := [
	"Go away.",
	"Leave me alone.",
	"Is there something wrong with you? Go away!",
	"...",
]


static func eligible(player_state) -> bool:
	return (
		not player_state.is_run_failed()
		and player_state.is_midnight()
		and int(player_state.character_completed_rides.get("gardo", 0)) >= 1
	)


static func prepare(player_state) -> void:
	if not eligible(player_state) or not _current_roll(player_state).is_empty():
		return
	# Cache misses too, so revisiting or reloading cannot reroll the same night.
	# This private generator leaves passenger, event and driving RNG untouched.
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.randomize()
	var spawn_chance: float = BOOSTED_SPAWN_CHANCE if bool(player_state.get_event_value(BOOST_EVENT, false)) else SPAWN_CHANCE
	player_state.set_event_value(ROLL_EVENT, {
		"day": player_state.get_current_day(),
		"present": encounter_rng.randf() < spawn_chance,
	})


static func offers(player_state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not eligible(player_state):
		return result
	var roll := _current_roll(player_state)
	if roll.is_empty() or not roll.present:
		return result
	var character: Dictionary = player_state.get_character_by_id("gardo")
	if character.is_empty():
		return result
	result.append({
		"kind": "encounter",
		"encounter_id": GARDO_ID,
		"character": character,
		"distance": "encounter",
		"slot": 0,
		"presentation": "midnight",
		"day": player_state.get_current_day(),
		"summary": {
			"kind": "encounter",
			"name": player_state.get_character_display_name("gardo"),
			"phase": "Midnight",
			"description": "Sitting alone at the terminal.",
			"badge": "ENCOUNTER",
		},
		"details": "Midnight encounter\nSitting alone at the terminal.",
	})
	return result


static func is_available(player_state, offer: Dictionary) -> bool:
	if not eligible(player_state):
		return false
	if str(offer.get("kind", "")) != "encounter" or str(offer.get("encounter_id", "")) != GARDO_ID:
		return false
	var day: Variant = offer.get("day", 0)
	if not day is int or day != player_state.get_current_day():
		return false
	var character: Variant = offer.get("character", {})
	if not character is Dictionary or str(character.get("id", "")) != "gardo":
		return false
	var roll := _current_roll(player_state)
	return not roll.is_empty() and bool(roll.present)


static func interact(player_state, offer: Dictionary) -> Dictionary:
	if not is_available(player_state, offer):
		return {}
	var roll := _current_roll(player_state).duplicate(true)
	var event_requested: Variant = roll.get("event_requested", false)
	if event_requested is bool and event_requested:
		return {}
	var stored_index: Variant = roll.get("dialogue_index", 0)
	var index := 0
	if stored_index is int:
		index = clampi(int(stored_index), 0, GARDO_LINES.size())
	if index < GARDO_LINES.size():
		roll["dialogue_index"] = index + 1
		player_state.set_event_value(ROLL_EVENT, roll)
		return {"text": GARDO_LINES[index], "start_event": false}
	roll["event_requested"] = true
	player_state.set_event_value(ROLL_EVENT, roll)
	return {"start_event": true}


static func _current_roll(player_state) -> Dictionary:
	var value: Variant = player_state.get_event_value(ROLL_EVENT, {})
	if not value is Dictionary:
		return {}
	var day: Variant = value.get("day", 0)
	if not day is int or day != player_state.get_current_day() or not value.get("present") is bool:
		return {}
	return value
