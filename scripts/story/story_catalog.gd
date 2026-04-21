extends RefCounted
class_name StoryCatalog

const DEFAULT_UNIQUE_STORY_STAGE_SET_ID := "default_unique_story"
const DEFAULT_UNIQUE_STORY_STAGES := [
	{
		"id": "introduction",
		"title": "Introduction",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 0,
		"modifiers": {},
		"modifier_rules": [],
	},
	{
		"id": "familiar",
		"title": "Familiar Face",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 2,
		"modifiers": {},
		"modifier_rules": [],
	},
	{
		"id": "turning_point",
		"title": "Turning Point",
		"arc_id": "arc1",
		"arc_title": "Arc 1",
		"progress_required": 5,
		"modifiers": {},
		"modifier_rules": [],
	},
]

const DEFAULT_SESSION_DIALOGUE := {
	"go_faster": [
		{
			"english": "Go faster, will you?",
			"tagalog": "Pakibilisan naman o.",
		},
	],
	"hurry_up": [
		{
			"english": "Hurry up!",
			"tagalog": "Grabe, ang bagal.",
		},
	],
	"slow_down": [
		{
			"english": "Slow down.",
			"tagalog": "Pakibagalan po.",
		},
	],
	"careful": [
		{
			"english": "Drive more carefully.",
			"tagalog": "Pakiingatan po.",
		},
	],
	"special": [],
}

const UNIQUE_SESSION_DIALOGUE_OVERRIDES := {
	"alma": {
		"special_1": [
			{"english": "Didn't think I'd run into you out here again, John.", "tagalog": "Dito ka pala nakatira?"},
			{"english": "City nights taught me one thing: never trust a quiet street.", "tagalog": "Kung may natutunan man ako sa siyudad, ito ay huwag magtiwala sa tahimik na kalsada."},
		],
	},
	"benny": {
		"special_1": [
			{"english": "It's been a long time since I've seen you around here. What happened to your city job?", "tagalog": "Long time no see pre, Kala ko ba doon ka nagtratrabaho sa siyudad?"},
			{"english": "Remember me? We used to hang out a lot during high school.", "tagalog": "Naaalala mo pa ako? Tayo yung laging magkakasama nung high school."},
		],
		"special_2": [
			{"english": "Construction starts early. If I'm late, the foreman will chew me out.", "tagalog": "Maaga nanaman ang pasok. Sana di ako masigawan ni porman."},
			{"english": "Funny, no? We used to cut class. Now we're the ones getting chased by time.", "tagalog": "Dati pa cutting cutting pa tayo, ngayon tayo na ang hinahabol ng oras.."},
		],
	},
	"cel": {
		"special_1": [
			{"english": "You can tell a lot about a person by how they drive when they're tired.", "tagalog": "Masasabi mo lang na kilala mo ang isang tao pag nakita mo na siya na magmaneho."},
			{"english": "The clinic is always full...", "tagalog": "Punuan nanaman siguro sa trabaho."},
		],
	},
	"dante": {
		"special_1": [
			{"english": "Night shift leaves the grease on your hands and the noise in your head.", "tagalog": "Paminsan-minsan, ang katahimikan lang ng gabi ang nagpapatila sa ingay ng aking ulo."},
			{"english": "Some things are easier to say when the engines are louder than people.", "tagalog": "Mas madaling intidihin ang mga makina kaysa sa mga tao."},
		],
	},
	"ely": {
		"special_1": [
			{"english": "Your father used to look just as stubborn behind the wheel.", "tagalog": "Naaalala ko ang tatay mo tuwing nakikita kita."},
			{"english": "A teacher learns to spot worry before a student says a word.", "tagalog": "Alam nang guro na may problema bago pa magsalita ang estudyante."},
		],
	},
	"faye": {
		"special_1": [
			{"english": "The men who talk sweet are usually the ones hiding the ugliest things.", "tagalog": "Yung mga lalaking matamis magsalita, sila kadalasan ang may pinakatagong kapangitan."},
			{"english": "You hear everything working nights. Most of it isn't worth hearing.", "tagalog": "Marami kang maririnig habang nagtratrabaho sa gabi na madalas mas mabuni nalang na di mo narinig."},
		],
	},
	"gardo": {
		"special_1": [
			{"english": "Some days I stay at the office just to avoid going home too early.", "tagalog": "May mga araw na nagpapagabi ako sa opisina para lang hindi ako umuwi."},
			{"english": "A necktie makes people think you're doing fine. That's the joke of it.", "tagalog": "Sabi nila mas dadali ang buhay pag may pamilya ka na."},
		],
	},
	"hana": {
		"special_1": [
			{"english": "Rumors get cleaner on paper, but messier in real life.", "tagalog": "May mga bagay na mas madaling mabasa sa papel kaysa makita mo nang harapan."},
			{"english": "If people keep lowering their voice around a story, it usually means it's real.", "tagalog": "Madalas ang katahimikan ay sinyales na may nangyayari."},
		],
	},
	"ito": {
		"special_1": [
			{"english": "People think we see everything. Truth is, we mostly see what we're told to ignore.", "tagalog": "Gano katagal pa ang aking hihintayin bago may magbago."},
			{"english": "Let's not stop too long.", "tagalog": "Sana walang mangyari ngayong araw."},
		],
	},
	"jessa": {
		"special_1": [
			{"english": "If anyone asks, you didn't see me.", "tagalog": "Kapag may naghanap saakin, hindi mo ako nakita."},
			{"english": "I just need a little more time before I go back.", "tagalog": "Kaya ko pa to..."},
		],
	},
}

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
		"name": "Alma",
		"blurb": "Bartender from the city who knows you personally.",
		"first_distance": "short",
		"first_appearance_chance": 0.85,
		"eligible_distances": ["short", "medium"],
		"eligible_times": ["morning", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "First Bargain"},
			"familiar": {"title": "Regular Customer"},
			"turning_point": {"title": "A Bartender's Life"},
		},
	},
	{
		"id": "benny",
		"name": "Benny",
		"blurb": "Former classmate working construction.",
		"first_distance": "medium",
		"first_appearance_chance": 0.70,
		# debug- normal values medium long
		"eligible_distances": ["medium","long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Old Jokester"},
			"familiar": {"title": "Benny's Hustle"},
			"turning_point": {"title": "A Risky Favor"},
		},
	},
	{
		"id": "cel",
		"name": "Celina",
		"blurb": "Clinic aide who is quietly very observant.",
		"first_distance": "short",
		"first_appearance_chance": 0.55,
		"eligible_distances": ["medium", "long"],
		"eligible_times": ["morning", "noon", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Sharp Eyes"},
			"familiar": {"title": "Clinic Errands"},
			"turning_point": {"title": "Celina Knows"},
		},
	},
	{
		"id": "dante",
		"name": "Dante",
		"blurb": "Night shift mechanic carrying a secret.",
		"first_distance": "long",
		"first_appearance_chance": 0.65,
		"eligible_distances": ["short","medium", "long"],
		"eligible_times": ["night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "After Hours"},
			"familiar": {"title": "Shop Talk"},
			"turning_point": {"title": "Dante's Secret"},
		},
	},
	{
		"id": "ely",
		"name": "Elena",
		"blurb": "Teacher who knew your father well.",
		"first_distance": "short",
		"first_appearance_chance": 0.45,
		"eligible_distances": ["short","long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "A Familiar Name"},
			"familiar": {"title": "Lessons Remembered"},
			"turning_point": {"title": "Your Father's Past"},
		},
	},
		{
			"id": "faye",
			"name": "Magda",
			"blurb": "Red light district worker who reads people fast.",
			"first_distance": "medium",
			"first_appearance_chance": 0.80,
			"eligible_distances": ["short", "medium","long"],
			"eligible_times": ["night"],
			"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
			"story_stage_overrides": {
				"introduction": {"title": "Salon Chatter"},
				"familiar": {"title": "Magda Hears Things"},
				"turning_point": {"title": "A Name Dropped"},
			},
		},
	{
		"id": "gardo",
		"name": "Gardo",
		"blurb": "Office worker quietly dealing with family problems.",
		"first_distance": "long",
		"first_appearance_chance": 0.40,
		"eligible_distances": ["long"],
		"eligible_times": ["morning", "noon","night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "All Smiles"},
			"familiar": {"title": "Too Close to Trouble"},
			"turning_point": {"title": "Gardo's Message"},
		},
	},
	{
		"id": "hana",
		"name": "Hana",
		"blurb": "Student journalist chasing rumors.",
		"first_distance": "medium",
		"first_appearance_chance": 0.60,
		"eligible_distances": ["medium", "long"],
		"eligible_times": ["morning", "night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Notebook Ready"},
			"familiar": {"title": "Questions on the Road"},
			"turning_point": {"title": "Hana Connects the Dots"},
		},
	},
	{
		"id": "ito",
		"name": "Isidro",
		"blurb": "Corrupt barangay tanod who looks perpetually worn down.",
		"first_distance": "long",
		"first_appearance_chance": 0.35,
		"eligible_distances": ["short", "medium", "long"],
		"eligible_times": ["morning", "noon"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "Late Paperwork"},
			"familiar": {"title": "Missing Records"},
			"turning_point": {"title": "Isidro Slips Up"},
		},
	},
	{
		"id": "jessa",
		"name": "Jessa",
		"blurb": "Runaway youth hiding from her family.",
		"first_distance": "short",
		"first_appearance_chance": 0.75,
		"eligible_distances": ["short", "medium"],
		"eligible_times": ["night"],
		"story_stage_set": DEFAULT_UNIQUE_STORY_STAGE_SET_ID,
		"story_stage_overrides": {
			"introduction": {"title": "A Quiet Ride"},
			"familiar": {"title": "Jessa Returns"},
			"turning_point": {"title": "What Jessa Carries"},
		},
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
	var safe_id: String = str(character_id).strip_edges().to_lower()
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
	var safe_id: String = str(character_id).strip_edges().to_lower()
	for character_data in MOCK_CHARACTERS:
		if not character_data is Dictionary:
			continue
		if str((character_data as Dictionary).get("id", "")).strip_edges().to_lower() == safe_id:
			return true
	return false


static func get_unique_character_story_state(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return {}

	var character_data: Dictionary = _get_unique_character_base_data(safe_id)
	if character_data.is_empty():
		return {}

	var story_stages: Array = _resolve_story_stages(player_state, character_data, context)
	if story_stages.is_empty():
		return {}

	var progress: int = player_state.get_unique_character_progress(safe_id)
	var stage_index: int = _resolve_story_stage_index(story_stages, progress)
	var current_stage: Dictionary = story_stages[stage_index]
	var next_stage: Dictionary = story_stages[stage_index + 1] if stage_index + 1 < story_stages.size() else {}
	var resolved_modifiers: Dictionary = _resolve_story_stage_modifiers(current_stage, context)

	return {
		"character_id": safe_id,
		"progress": progress,
		"stage_index": stage_index,
		"stage_count": story_stages.size(),
		"stage_data": current_stage.duplicate(true),
		"stage_id": str(current_stage.get("id", "")),
		"stage_title": str(current_stage.get("title", "")),
		"arc_id": str(current_stage.get("arc_id", "")),
		"arc_title": str(current_stage.get("arc_title", "")),
		"stage_progress_required": int(current_stage.get("progress_required", 0)),
		"next_stage_id": str(next_stage.get("id", "")),
		"next_stage_title": str(next_stage.get("title", "")),
		"next_arc_id": str(next_stage.get("arc_id", "")),
		"next_arc_title": str(next_stage.get("arc_title", "")),
		"next_stage_progress_required": int(next_stage.get("progress_required", progress)),
		"story_stages": story_stages.duplicate(true),
		"modifiers": resolved_modifiers,
	}


static func get_character_stage_modifiers(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	var story_state: Dictionary = get_unique_character_story_state(player_state, character_id, context)
	if story_state.is_empty():
		return {}
	var modifiers: Variant = story_state.get("modifiers", {})
	return (modifiers as Dictionary).duplicate(true) if modifiers is Dictionary else {}


static func get_character_session_dialogue(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	if str(character_id).strip_edges().is_empty():
		return {}
	var resolved_dialogue: Dictionary = _duplicate_session_dialogue(DEFAULT_SESSION_DIALOGUE)
	var character_data: Dictionary = get_character_by_id(player_state, character_id)
	if character_data.is_empty():
		return resolved_dialogue

	var safe_id: String = str(character_data.get("id", "")).strip_edges().to_lower()
	_merge_session_dialogue(resolved_dialogue, character_data.get("session_dialogue", {}))
	_merge_session_dialogue(resolved_dialogue, UNIQUE_SESSION_DIALOGUE_OVERRIDES.get(safe_id, {}))

	if is_unique_character(safe_id):
		var story_state: Dictionary = get_unique_character_story_state(player_state, safe_id, context)
		if not story_state.is_empty():
			var stage_data: Variant = story_state.get("stage_data", {})
			if stage_data is Dictionary:
				_merge_session_dialogue(resolved_dialogue, (stage_data as Dictionary).get("session_dialogue", {}))

	return _resolve_progress_scoped_session_dialogue(player_state, safe_id, resolved_dialogue)


static func _character_with_progress(player_state, character_data: Dictionary) -> Dictionary:
	var character_copy: Dictionary = character_data.duplicate(true)
	var character_id: String = str(character_copy.get("id", ""))
	character_copy["progress"] = player_state.get_unique_character_progress(character_id)
	var story_state: Dictionary = get_unique_character_story_state(player_state, character_id)
	if not story_state.is_empty():
		character_copy["story_stage_id"] = str(story_state.get("stage_id", ""))
		character_copy["story_stage_title"] = str(story_state.get("stage_title", ""))
		character_copy["story_arc_id"] = str(story_state.get("arc_id", ""))
		character_copy["story_arc_title"] = str(story_state.get("arc_title", ""))
		character_copy["story_stage_index"] = int(story_state.get("stage_index", 0))
		character_copy["story_stage_count"] = int(story_state.get("stage_count", 0))
		character_copy["next_story_stage_id"] = str(story_state.get("next_stage_id", ""))
		character_copy["next_story_stage_title"] = str(story_state.get("next_stage_title", ""))
		character_copy["next_story_arc_id"] = str(story_state.get("next_arc_id", ""))
		character_copy["next_story_arc_title"] = str(story_state.get("next_arc_title", ""))
		character_copy["next_story_stage_progress_required"] = int(story_state.get("next_stage_progress_required", 0))
	return character_copy


static func _get_unique_character_base_data(character_id: String) -> Dictionary:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	for character_data in MOCK_CHARACTERS:
		if not character_data is Dictionary:
			continue
		var candidate: Dictionary = character_data
		if str(candidate.get("id", "")).strip_edges().to_lower() == safe_id:
			return candidate.duplicate(true)
	return {}


static func _resolve_story_stages(player_state, character_data: Dictionary, context: Dictionary = {}) -> Array:
	var raw_stages: Variant = character_data.get("story_stages", [])
	var story_stages: Array = []
	if raw_stages is Array and not (raw_stages as Array).is_empty():
		for stage_data in raw_stages:
			if stage_data is Dictionary:
				story_stages.append((stage_data as Dictionary).duplicate(true))
	else:
		var stage_set_id: String = str(character_data.get("story_stage_set", DEFAULT_UNIQUE_STORY_STAGE_SET_ID))
		var stage_overrides: Dictionary = character_data.get("story_stage_overrides", {})
		var fallback_stages: Array = DEFAULT_UNIQUE_STORY_STAGES if stage_set_id == DEFAULT_UNIQUE_STORY_STAGE_SET_ID else DEFAULT_UNIQUE_STORY_STAGES
		for stage_data in fallback_stages:
			if not stage_data is Dictionary:
				continue
			var stage_copy: Dictionary = (stage_data as Dictionary).duplicate(true)
			var stage_id: String = str(stage_copy.get("id", ""))
			if stage_overrides.has(stage_id) and stage_overrides[stage_id] is Dictionary:
				stage_copy.merge((stage_overrides[stage_id] as Dictionary).duplicate(true), true)
			story_stages.append(stage_copy)

	story_stages.sort_custom(func(a, b):
		return int(a.get("progress_required", 0)) < int(b.get("progress_required", 0))
	)

	var effective_week: int = _resolve_story_stage_week(player_state, context)
	var available_story_stages: Array = []
	for stage_data in story_stages:
		if not stage_data is Dictionary:
			continue
		var stage_dict: Dictionary = stage_data
		if not _story_stage_available_for_week(stage_dict, effective_week):
			continue
		available_story_stages.append(stage_dict)
	if available_story_stages.is_empty():
		return story_stages
	return available_story_stages


static func _resolve_story_stage_index(story_stages: Array, progress: int) -> int:
	var resolved_index := 0
	for index in range(story_stages.size()):
		var stage_data = story_stages[index]
		if not stage_data is Dictionary:
			continue
		var required_progress := int((stage_data as Dictionary).get("progress_required", 0))
		if progress >= required_progress:
			resolved_index = index
	return resolved_index


static func _resolve_story_stage_week(player_state, context: Dictionary) -> int:
	if context.has("week"):
		return maxi(1, int(context.get("week", 1)))
	if context.has("day"):
		return maxi(1, player_state.get_week_number(int(context.get("day", player_state.get_current_day()))))
	return maxi(1, player_state.get_week_number())


static func _story_stage_available_for_week(stage_data: Dictionary, week_number: int) -> bool:
	var effective_week: int = maxi(1, int(week_number))
	if stage_data.has("min_week") and effective_week < int(stage_data.get("min_week", effective_week)):
		return false
	if stage_data.has("max_week") and effective_week > int(stage_data.get("max_week", effective_week)):
		return false
	var weeks_variant: Variant = stage_data.get("weeks", [])
	if weeks_variant is Array and not (weeks_variant as Array).is_empty():
		for allowed_week in weeks_variant:
			if int(allowed_week) == effective_week:
				return true
		return false
	return true


static func _resolve_story_stage_modifiers(stage_data: Dictionary, context: Dictionary) -> Dictionary:
	var resolved_modifiers: Dictionary = {}
	var base_modifiers: Variant = stage_data.get("modifiers", {})
	if base_modifiers is Dictionary:
		resolved_modifiers.merge((base_modifiers as Dictionary).duplicate(true), true)

	var rule_entries: Variant = stage_data.get("modifier_rules", [])
	if not rule_entries is Array:
		return resolved_modifiers

	for rule_data in rule_entries:
		if not rule_data is Dictionary:
			continue
		var rule: Dictionary = rule_data
		if not _modifier_rule_matches_context(rule, context):
			continue
		var rule_modifiers: Variant = rule.get("modifiers", {})
		if rule_modifiers is Dictionary:
			resolved_modifiers.merge((rule_modifiers as Dictionary).duplicate(true), true)
	return resolved_modifiers


static func _modifier_rule_matches_context(rule: Dictionary, context: Dictionary) -> bool:
	if not _matches_rule_value(context, rule, "stage_type", "stage_types"):
		return false
	if not _matches_rule_value(context, rule, "difficulty", "difficulties"):
		return false
	if not _matches_rule_value(context, rule, "time_of_day", "times_of_day", ["time"]):
		return false
	if not _matches_rule_value(context, rule, "traffic", "traffics"):
		return false
	return true


static func _matches_rule_value(
	context: Dictionary,
	rule: Dictionary,
	singular_key: String,
	plural_key: String,
	context_aliases: Array = []
) -> bool:
	if not rule.has(singular_key) and not rule.has(plural_key):
		return true

	var context_value := ""
	if context.has(singular_key):
		context_value = str(context.get(singular_key, "")).strip_edges().to_lower()
	else:
		for alias_key in context_aliases:
			if context.has(alias_key):
				context_value = str(context.get(alias_key, "")).strip_edges().to_lower()
				break

	if context_value.is_empty():
		return false

	if rule.has(singular_key):
		return context_value == str(rule.get(singular_key, "")).strip_edges().to_lower()

	var allowed_values: Variant = rule.get(plural_key, [])
	if not allowed_values is Array:
		return false
	for value in allowed_values:
		if context_value == str(value).strip_edges().to_lower():
			return true
	return false


static func _duplicate_session_dialogue(source_dialogue: Dictionary) -> Dictionary:
	var duplicated: Dictionary = {}
	for category_variant in source_dialogue.keys():
		var category: String = str(category_variant)
		var entries: Variant = source_dialogue.get(category, [])
		var duplicated_entries: Array = []
		if entries is Array:
			for entry in entries:
				if entry is Dictionary:
					duplicated_entries.append((entry as Dictionary).duplicate(true))
				else:
					duplicated_entries.append(entry)
		duplicated[category] = duplicated_entries
	return duplicated


static func _merge_session_dialogue(target_dialogue: Dictionary, source_dialogue: Variant) -> void:
	if not source_dialogue is Dictionary:
		return

	for category_variant in (source_dialogue as Dictionary).keys():
		var category: String = str(category_variant)
		if not target_dialogue.has(category):
			target_dialogue[category] = []
		var target_entries: Array = target_dialogue.get(category, [])
		var source_entries: Variant = (source_dialogue as Dictionary).get(category, [])
		if not source_entries is Array:
			continue
		for entry in source_entries:
			if entry is Dictionary:
				target_entries.append((entry as Dictionary).duplicate(true))
			else:
				target_entries.append(entry)
		target_dialogue[category] = target_entries


static func _resolve_progress_scoped_session_dialogue(player_state, character_id: String, source_dialogue: Dictionary) -> Dictionary:
	var resolved_dialogue: Dictionary = {}
	var progress: int = player_state.get_unique_character_progress(character_id)
	for category_variant in source_dialogue.keys():
		var category: String = str(category_variant).strip_edges().to_lower()
		var entries: Variant = source_dialogue.get(category_variant, [])
		if not entries is Array:
			continue
		var scoped_info: Dictionary = _progress_scoped_dialogue_category_info(category)
		if scoped_info.is_empty():
			resolved_dialogue[category] = (entries as Array).duplicate(true)
			continue
		if int(scoped_info.get("progress", -1)) != progress:
			continue
		var base_category: String = str(scoped_info.get("base_category", ""))
		if not resolved_dialogue.has(base_category):
			resolved_dialogue[base_category] = []
		var target_entries: Array = resolved_dialogue.get(base_category, [])
		for entry_index in range((entries as Array).size()):
			var decorated_entry: Variant = _decorate_progress_scoped_dialogue_entry(
				player_state,
				character_id,
				base_category,
				category,
				entry_index,
				(entries as Array)[entry_index]
			)
			if decorated_entry == null:
				continue
			target_entries.append(decorated_entry)
		resolved_dialogue[base_category] = target_entries
	return resolved_dialogue


static func _progress_scoped_dialogue_category_info(category: String) -> Dictionary:
	var safe_category: String = str(category).strip_edges().to_lower()
	var underscore_index: int = safe_category.rfind("_")
	if underscore_index <= 0 or underscore_index >= safe_category.length() - 1:
		return {}
	var suffix: String = safe_category.substr(underscore_index + 1)
	if not suffix.is_valid_int():
		return {}
	return {
		"base_category": safe_category.substr(0, underscore_index),
		"progress": int(suffix),
	}


static func _decorate_progress_scoped_dialogue_entry(player_state, character_id: String, base_category: String, source_category: String, entry_index: int, entry: Variant) -> Variant:
	var entry_id: String = "%s:%s:%s:%d" % [character_id, base_category, source_category, entry_index]
	if player_state.has_consumed_unique_session_dialogue(entry_id):
		return null
	if entry is Dictionary:
		var entry_dict: Dictionary = (entry as Dictionary).duplicate(true)
		entry_dict["_session_dialogue_id"] = entry_id
		entry_dict["_session_dialogue_once"] = true
		entry_dict["_session_dialogue_ordered"] = true
		return entry_dict
	return {
		"english": str(entry),
		"_session_dialogue_id": entry_id,
		"_session_dialogue_once": true,
		"_session_dialogue_ordered": true,
	}
