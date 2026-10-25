extends RefCounted

# Generates and locks passenger offers, including first appearances and seeded riders.
# Keep generation order and rule consumption here so retry/fallback rolls stay aligned.

const EMPTY_CARD_CHANCE := 0.28
const CharacterAvailability := preload("res://scripts/story/character_availability.gd")

var screen
var rng := RandomNumberGenerator.new()


func _init(selection_screen) -> void:
	screen = selection_screen
	rng.randomize()


func roll() -> Dictionary:
	if not PlayerState.are_passengers_available():
		return {"short": [], "medium": [], "long": []}
	for _attempt in range(24):
		var seeded_setup := PlayerState.get_seeded_rider_pool_setup(_build_seed_selection_context())
		var rolled_pools := _roll_once(false, seeded_setup)
		if _has_distance_coverage(rolled_pools):
			PlayerState.consume_seeded_rider_rules(seeded_setup.get("rule_ids", []))
			return rolled_pools

	var fallback_seeded_setup := PlayerState.get_seeded_rider_pool_setup(_build_seed_selection_context())
	var fallback_pools := _roll_once(true, fallback_seeded_setup)
	PlayerState.consume_seeded_rider_rules(fallback_seeded_setup.get("rule_ids", []))
	return fallback_pools


func _roll_once(force_first_appearance_unlocks: bool, seeded_setup: Dictionary = {}) -> Dictionary:
	var character_pools: Dictionary = {}
	var used_ids: Dictionary = {}
	var first_appearance_rolls := _build_first_appearance_rolls(force_first_appearance_unlocks)
	var seeded_distance_slots: Dictionary = Dictionary(seeded_setup.get("distance_slots", {}))

	for distance_variant in _ordered_distances_for_generation():
		var distance := str(distance_variant)
		character_pools[distance] = _build_distance_pool(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks,
			Array(seeded_distance_slots.get(distance, []))
		)

	return character_pools


func _build_distance_pool(distance: String, used_ids: Dictionary, first_appearance_rolls: Dictionary, force_first_appearance_unlocks: bool, seeded_assignments: Array = []) -> Array[Dictionary]:
	var card_results: Array[Dictionary] = [{}, {}, {}]
	var has_seeded_character := false

	for assignment_variant in seeded_assignments:
		if not assignment_variant is Dictionary:
			continue
		var assignment: Dictionary = assignment_variant
		var seeded_character: Dictionary = assignment.get("character", {})
		var character_id := str(seeded_character.get("id", ""))
		var slot_index := int(assignment.get("slot", -1))
		if slot_index < 0 or slot_index >= card_results.size():
			continue
		if seeded_character.is_empty() or character_id.is_empty() or used_ids.has(character_id):
			continue
		used_ids[character_id] = true
		has_seeded_character = true
		card_results[slot_index] = _lock_character_for_selection(
			seeded_character,
			distance,
			str(assignment.get("forced_traffic", ""))
		)

	if not has_seeded_character:
		var guaranteed_character := _pick_character_for_distance(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks
		)
		if not guaranteed_character.is_empty():
			used_ids[str(guaranteed_character["id"])] = true
			var first_open_slot := _find_first_empty_card_slot(card_results)
			if first_open_slot >= 0:
				card_results[first_open_slot] = _lock_character_for_selection(guaranteed_character, distance)

	for slot_index in range(card_results.size()):
		if not (card_results[slot_index] as Dictionary).is_empty():
			continue
		if slot_index > 0 and rng.randf() < EMPTY_CARD_CHANCE:
			continue

		var filler := _pick_character_for_distance(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks
		)
		if filler.is_empty():
			continue

		used_ids[str(filler["id"])] = true
		card_results[slot_index] = _lock_character_for_selection(filler, distance)

	return card_results


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
		unseen_candidates.shuffle()
		return unseen_candidates[0]
	if not seen_candidates.is_empty():
		seen_candidates.shuffle()
		return seen_candidates[0]
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


func _has_distance_coverage(character_pools: Dictionary) -> bool:
	for difficulty_variant in PlayerState.STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		if _count_non_empty_cards(character_pools.get(difficulty, [])) <= 0:
			return false
	return true


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


func _find_first_empty_card_slot(card_results: Array[Dictionary]) -> int:
	for slot_index in range(card_results.size()):
		if (card_results[slot_index] as Dictionary).is_empty():
			return slot_index
	return -1


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
