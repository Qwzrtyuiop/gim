extends RefCounted
class_name StoryCatalog

const GENERIC_PASSENGERS := [
	{
		"id": "generic_guy",
		"name": "Guy",
		"blurb": "Just another rider heading somewhere.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_vendor",
		"name": "Vendor",
		"blurb": "A market seller with goods to move.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_student",
		"name": "Student",
		"blurb": "A student on the way to class or home.",
		"is_generic": true,
		"first_distance": "medium",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_worker",
		"name": "Worker",
		"blurb": "A worker chasing the next shift.",
		"is_generic": true,
		"first_distance": "medium",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "generic_elder",
		"name": "Elder",
		"blurb": "An elder traveling at their own pace.",
		"is_generic": true,
		"first_distance": "short",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "generic_parent_child",
		"name": "Parent with Child",
		"blurb": "A parent trying to get their child across town.",
		"is_generic": true,
		"first_distance": "long",
		"first_appearance_chance": 1.0,
		"eligible_distances": ["medium", "long"],
	},
]

const MOCK_CHARACTERS := [
	{
		"id": "alma",
		"name": "Alma D.",
		"blurb": "Market regular with a sharp tongue.",
		"first_distance": "short",
		"first_appearance_chance": 0.85,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "benny",
		"name": "Benny R.",
		"blurb": "Former class clown turned fixer.",
		"first_distance": "medium",
		"first_appearance_chance": 0.70,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "cel",
		"name": "Cel V.",
		"blurb": "Clinic aide who notices everything.",
		"first_distance": "short",
		"first_appearance_chance": 0.55,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "dante",
		"name": "Dante K.",
		"blurb": "Night shift mechanic with secrets.",
		"first_distance": "long",
		"first_appearance_chance": 0.65,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "ely",
		"name": "Ely S.",
		"blurb": "Teacher who knew your father well.",
		"first_distance": "short",
		"first_appearance_chance": 0.45,
		"eligible_distances": ["short", "long"],
	},
	{
		"id": "faye",
		"name": "Faye M.",
		"blurb": "Salon owner with city gossip.",
		"first_distance": "medium",
		"first_appearance_chance": 0.80,
		"eligible_distances": ["short", "medium"],
	},
	{
		"id": "gardo",
		"name": "Gardo T.",
		"blurb": "Debt collector's runner, all smiles.",
		"first_distance": "long",
		"first_appearance_chance": 0.40,
		"eligible_distances": ["long"],
	},
	{
		"id": "hana",
		"name": "Hana P.",
		"blurb": "Student journalist chasing rumors.",
		"first_distance": "medium",
		"first_appearance_chance": 0.60,
		"eligible_distances": ["medium", "long"],
	},
	{
		"id": "ito",
		"name": "Ito L.",
		"blurb": "Barangay aide with missing files.",
		"first_distance": "long",
		"first_appearance_chance": 0.35,
		"eligible_distances": ["short", "medium", "long"],
	},
	{
		"id": "jessa",
		"name": "Jessa N.",
		"blurb": "Quiet vendor who keeps showing up.",
		"first_distance": "short",
		"first_appearance_chance": 0.75,
		"eligible_distances": ["short", "medium"],
	},
]


static func get_generic_passengers() -> Array:
	return GENERIC_PASSENGERS.duplicate(true)


static func get_unique_passengers(player_state) -> Array:
	var unique_passengers: Array = []
	for character_data in MOCK_CHARACTERS:
		if character_data is Dictionary:
			unique_passengers.append(_character_with_progress(player_state, (character_data as Dictionary).duplicate(true)))
	return unique_passengers


static func get_mock_characters(player_state) -> Array:
	var combined_characters: Array = []
	combined_characters.append_array(get_generic_passengers())
	combined_characters.append_array(get_unique_passengers(player_state))
	return combined_characters


static func get_character_by_id(player_state, character_id: String) -> Dictionary:
	var safe_id := str(character_id).strip_edges().to_lower()
	if safe_id.is_empty():
		return {}
	for character_data in get_mock_characters(player_state):
		if not character_data is Dictionary:
			continue
		var character: Dictionary = character_data
		if str(character.get("id", "")).strip_edges().to_lower() == safe_id:
			return character.duplicate(true)
	return {}


static func is_unique_character(character_id: String) -> bool:
	var safe_id := str(character_id).strip_edges().to_lower()
	for character_data in MOCK_CHARACTERS:
		if not character_data is Dictionary:
			continue
		if str((character_data as Dictionary).get("id", "")).strip_edges().to_lower() == safe_id:
			return true
	return false


static func _character_with_progress(player_state, character_data: Dictionary) -> Dictionary:
	var character_copy: Dictionary = character_data.duplicate(true)
	character_copy["progress"] = player_state.get_unique_character_progress(str(character_copy.get("id", "")))
	return character_copy
