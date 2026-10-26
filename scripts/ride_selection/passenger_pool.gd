extends RefCounted

# Generates and locks passenger offers, including first appearances and seeded riders.
# Keep generation order and rule consumption here so retry/fallback rolls stay aligned.

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const CharacterAvailability := preload("res://scripts/story/character_availability.gd")
const CARDS_PER_DISTANCE := 3

var screen
var rng := RandomNumberGenerator.new()


func _init(selection_screen) -> void:
	screen = selection_screen
	rng.randomize()


func roll() -> Dictionary:
	if not PlayerState.are_passengers_available():
		return {"short": [], "medium": [], "long": []}
	var capacity := _ordered_distances_for_generation().size() * CARDS_PER_DISTANCE
	var target := rng.randi_range(mini(GameTuning.TERMINAL_MIN_PASSENGERS, capacity), capacity)
	var seeded_setup := PlayerState.get_seeded_rider_pool_setup(_build_seed_selection_context())
	for _attempt in range(24):
		var rolled_pools := _roll_once(false, seeded_setup, target)
		if _has_minimum_offers(rolled_pools):
			return _lock_pools(rolled_pools)

	return _lock_pools(_roll_once(true, seeded_setup, target))


func _roll_once(force_first_appearance_unlocks: bool, seeded_setup: Dictionary, target: int) -> Dictionary:
	var character_pools := {"short": [{}, {}, {}], "medium": [{}, {}, {}], "long": [{}, {}, {}]}
	var used_ids: Dictionary = {}
	var first_appearance_rolls := _build_first_appearance_rolls(force_first_appearance_unlocks)
	var seeded_distance_slots: Dictionary = Dictionary(seeded_setup.get("distance_slots", {}))
	var distances := _ordered_distances_for_generation()

	# Reserve every scripted rider before random filling can select their ID.
	# These are raw candidates: rejected attempts must not mark anyone seen.
	for distance: String in distances:
		for assignment_variant in Array(seeded_distance_slots.get(distance, [])):
			if not assignment_variant is Dictionary:
				continue
			var assignment: Dictionary = assignment_variant
			var character: Dictionary = assignment.get("character", {})
			var character_id := str(character.get("id", ""))
			var slot := int(assignment.get("slot", -1))
			if slot < 0 or slot >= CARDS_PER_DISTANCE or character_id.is_empty() or used_ids.has(character_id):
				continue
			if not Dictionary(character_pools[distance][slot]).is_empty():
				continue
			used_ids[character_id] = true
			character_pools[distance][slot] = {
				"character": character,
				"forced_traffic": str(assignment.get("forced_traffic", "")),
				"rule_id": str(assignment.get("rule_id", "")),
			}

	target = maxi(target, used_ids.size())
	var priority_distance: String = distances[0]
	var priority_pool: Array = character_pools[priority_distance]
	var needs_short: bool = PlayerState.gas <= 40.0 or screen._is_forced_first_day_ride()
	if _count_non_empty_cards(priority_pool) == 0 and (used_ids.size() < target or needs_short):
		_add_candidate(character_pools, priority_distance, 0, used_ids, first_appearance_rolls, force_first_appearance_unlocks)

	var open_slots: Array[Dictionary] = []
	for distance: String in distances:
		for slot in range(CARDS_PER_DISTANCE):
			if Dictionary(character_pools[distance][slot]).is_empty():
				open_slots.append({"distance": distance, "slot": slot})
	while used_ids.size() < target and not open_slots.is_empty():
		var slot: Dictionary = open_slots.pop_at(rng.randi_range(0, open_slots.size() - 1))
		_add_candidate(character_pools, slot.distance, int(slot.slot), used_ids, first_appearance_rolls, force_first_appearance_unlocks)
	return character_pools


func _add_candidate(pools: Dictionary, distance: String, slot: int, used_ids: Dictionary, first_rolls: Dictionary, force_first: bool) -> void:
	var character := _pick_character_for_distance(distance, used_ids, first_rolls, force_first)
	if character.is_empty():
		return
	used_ids[str(character.id)] = true
	pools[distance][slot] = {"character": character}


func _lock_pools(candidates: Dictionary) -> Dictionary:
	var locked_pools: Dictionary = {}
	var rule_ids: Array[String] = []
	for distance: String in PlayerState.STAGE_DIFFICULTIES:
		var locked: Array[Dictionary] = []
		for candidate: Dictionary in candidates.get(distance, []):
			if candidate.is_empty():
				locked.append({})
				continue
			locked.append(_lock_character_for_selection(candidate.character, distance, str(candidate.get("forced_traffic", ""))))
			var rule_id := str(candidate.get("rule_id", ""))
			if not rule_id.is_empty() and not rule_ids.has(rule_id):
				rule_ids.append(rule_id)
		locked_pools[distance] = locked
	PlayerState.consume_seeded_rider_rules(rule_ids)
	return locked_pools


func _pick_character_for_distance(distance: String, used_ids: Dictionary, first_appearance_rolls: Dictionary, force_first_appearance_unlocks: bool) -> Dictionary:
	var unseen_candidates: Array[Dictionary] = []
	var seen_candidates: Array[Dictionary] = []

	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var character_id := str(character.get("id", ""))
		if used_ids.has(character_id):
			continue

		var is_seen := PlayerState.has_seen_mock_character(character_id)
		if is_seen:
			if _supports_selection_availability(character, distance, false):
				seen_candidates.append(character)
			continue

		if not _supports_selection_availability(character, distance, true):
			continue
		if not force_first_appearance_unlocks and not bool(first_appearance_rolls.get(character_id, false)):
			continue
		unseen_candidates.append(character)

	if not unseen_candidates.is_empty():
		return unseen_candidates[rng.randi_range(0, unseen_candidates.size() - 1)]
	if not seen_candidates.is_empty():
		return seen_candidates[rng.randi_range(0, seen_candidates.size() - 1)]
	return {}


func _build_first_appearance_rolls(force_first_appearance_unlocks: bool) -> Dictionary:
	var first_appearance_rolls: Dictionary = {}
	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var character_id := str(character.get("id", ""))
		if PlayerState.has_seen_mock_character(character_id):
			continue
		first_appearance_rolls[character_id] = force_first_appearance_unlocks or rng.randf() <= float(character.get("first_appearance_chance", 1.0))
	return first_appearance_rolls


func _ordered_distances_for_generation() -> Array[String]:
	if screen._is_forced_first_day_ride():
		return ["short"]
	var ordered_distances: Array[String] = []
	if PlayerState.gas <= 40.0:
		ordered_distances.append("short")
	if not ordered_distances.has(screen.selected_distance):
		ordered_distances.append(screen.selected_distance)
	for difficulty_variant in PlayerState.STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		if not ordered_distances.has(difficulty):
			ordered_distances.append(difficulty)
	return ordered_distances


func _has_minimum_offers(character_pools: Dictionary) -> bool:
	var count := 0
	for cards: Array in character_pools.values():
		count += _count_non_empty_cards(cards)
	if count < GameTuning.TERMINAL_MIN_PASSENGERS:
		return false
	return PlayerState.gas > 40.0 or _count_non_empty_cards(character_pools.get("short", [])) > 0


func _count_non_empty_cards(card_results: Array) -> int:
	var count := 0
	for card_variant in card_results:
		var card: Dictionary = card_variant as Dictionary
		if not card.is_empty():
			count += 1
	return count


func _supports_selection_availability(character: Dictionary, distance: String, is_first_appearance: bool) -> bool:
	if not _supports_time_in_selection(character):
		return false
	return _supports_distance_in_selection(character, distance, is_first_appearance)


func _supports_distance_in_selection(character: Dictionary, distance: String, is_first_appearance: bool) -> bool:
	if is_first_appearance:
		return str(character.get("first_distance", "")) == distance

	var eligible_distances: Array = character.get("eligible_distances", [])
	return eligible_distances.has(distance)


func _supports_time_in_selection(character: Dictionary) -> bool:
	return CharacterAvailability.supports_time(
		character,
		PlayerState.get_next_stage_time(screen._transition_mode()),
		PlayerState.get_transition_display_day(screen._transition_mode()),
	)


func _lock_character_for_selection(picked_character: Dictionary, active_distance: String, forced_traffic: String = "") -> Dictionary:
	var was_seen_before_roll := PlayerState.has_seen_mock_character(str(picked_character["id"]))
	PlayerState.mark_mock_character_seen(str(picked_character["id"]))
	var locked_character: Dictionary = picked_character.duplicate(true)
	locked_character["active_distance"] = active_distance
	var selected_traffic := forced_traffic.strip_edges().to_lower()
	if screen._is_forced_first_day_ride():
		selected_traffic = "chill"
	if not PlayerState.STAGE_TRAFFIC_TYPES.has(selected_traffic):
		selected_traffic = PlayerState.get_random_stage_traffic_type()
	locked_character["stage_traffic"] = selected_traffic
	locked_character["stage_special_type"] = _roll_stage_special_type(active_distance, selected_traffic)
	locked_character["special_stage_id"] = ""
	locked_character["is_first_appearance"] = not was_seen_before_roll
	return locked_character


func _roll_stage_special_type(active_distance: String, selected_traffic: String) -> String:
	if screen._is_forced_first_day_ride():
		return PlayerState.STAGE_SPECIAL_TYPE_NONE

	var urgent_weight := 0.14
	var careful_weight := 0.12
	match selected_traffic:
		"traffic-jam":
			urgent_weight += 0.06
		"busy":
			urgent_weight += 0.08
			careful_weight += 0.05
		"speeders":
			urgent_weight += 0.04
			careful_weight += 0.12

	match active_distance:
		"medium":
			urgent_weight += 0.03
			careful_weight += 0.02
		"long":
			urgent_weight += 0.05
			careful_weight += 0.04

	var roll := rng.randf()
	if roll < urgent_weight:
		return PlayerState.STAGE_SPECIAL_TYPE_URGENT
	if roll < urgent_weight + careful_weight:
		return PlayerState.STAGE_SPECIAL_TYPE_CAREFUL
	return PlayerState.STAGE_SPECIAL_TYPE_NONE


func _build_seed_selection_context() -> Dictionary:
	var next_time_of_day := PlayerState.get_next_stage_time(screen._transition_mode())
	var current_time_of_day := PlayerState.get_current_time_of_day()
	return {
		"day": PlayerState.get_transition_display_day(screen._transition_mode()),
		"time_of_day": next_time_of_day,
		"phase_of_day": next_time_of_day,
		"current_day": PlayerState.get_current_day(),
		"current_time_of_day": current_time_of_day,
		"current_phase": current_time_of_day,
		"current_stage_type": PlayerState.get_current_stage_type(),
	}


func for_distance(distance: String) -> Array[Dictionary]:
	if not PlayerState.are_passengers_available():
		return [{}, {}, {}]
	var locked_pool: Array = screen.locked_character_pools.get(distance, [])
	var card_results: Array[Dictionary] = []
	for card_variant in locked_pool:
		var card := card_variant as Dictionary
		card_results.append(card)
	while card_results.size() < 3:
		card_results.append({})
	return card_results


func preview_stage_type(character: Dictionary) -> String:
	if screen._is_forced_first_day_ride():
		return PlayerState.FIRST_STAGE_TYPE
	return PlayerState.build_stage_type(
		str(character.get("active_distance", screen.selected_distance)),
		PlayerState.get_next_stage_time(screen._transition_mode()),
		str(character.get("stage_traffic", "chill"))
	)
