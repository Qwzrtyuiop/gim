extends RefCounted

# Appearance belongs to this offer, independently of its generic gameplay ID.
const SpawnCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")


static func assign(pools: Dictionary, phase: String) -> bool:
	var characters: Array[Dictionary] = []
	var generics: Dictionary = {}
	var used_slots: Dictionary = {}
	for cards_variant in pools.values():
		if not cards_variant is Array:
			continue
		for character_variant in cards_variant:
			if not character_variant is Dictionary:
				continue
			var character: Dictionary = character_variant
			var id := str(character.get("id", ""))
			if id.is_empty() or str(character.get("pickup_location", "station")) != "station":
				continue
			if bool(character.get("is_generic", false)) or id.begins_with("generic_"):
				characters.append(character)
				if not generics.has(id):
					generics[id] = character
			elif not SpawnCatalog.entry(id, phase == "night").is_empty():
				var named_slot := int(SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.get(id, -1))
				if named_slot >= 0:
					used_slots[named_slot] = true
	var assignments: Dictionary = {}
	# Reserve existing appearances first so absent riders never reposition others.
	for id: String in generics:
		var character: Dictionary = generics[id]
		var saved_slot: Variant = character.get("generic_spawn_slot")
		if saved_slot is int and _valid_slot(saved_slot) and not used_slots.has(saved_slot):
			assignments[id] = saved_slot
			used_slots[saved_slot] = true
	var free_slots: Array[int] = []
	for slot in range(SpawnCatalog.GENERIC_ENTRIES.size()):
		if not used_slots.has(slot):
			free_slots.append(slot)
	var appearance_rng := RandomNumberGenerator.new()
	appearance_rng.randomize()
	var changed := false
	var appearances: Dictionary = {}
	for id: String in generics:
		var character: Dictionary = generics[id]
		if not assignments.has(id):
			var assigned_slot := -2
			if not free_slots.is_empty():
				assigned_slot = free_slots.pop_at(appearance_rng.randi_range(0, free_slots.size() - 1))
			else:
				while used_slots.has(assigned_slot):
					assigned_slot -= 1
			assignments[id] = assigned_slot
			used_slots[assigned_slot] = true
		var slot: int = assignments[id]
		var alternate := false
		if SpawnCatalog.GENERIC_ALTERNATE_ENTRIES.has(slot):
			var saved_alternate: Variant = character.get("generic_spawn_alternate")
			alternate = saved_alternate if saved_alternate is bool and character.get("generic_spawn_slot") == slot else appearance_rng.randf() < 0.5
		appearances[id] = {"slot": slot, "alternate": alternate}
	for character: Dictionary in characters:
		var appearance: Dictionary = appearances[str(character.id)]
		if character.get("generic_spawn_slot") != appearance.slot or character.get("generic_spawn_alternate") != appearance.alternate:
			character["generic_spawn_slot"] = appearance.slot
			character["generic_spawn_alternate"] = appearance.alternate
			changed = true
	return changed


static func _valid_slot(slot: int) -> bool:
	return (slot >= 0 and slot < SpawnCatalog.GENERIC_ENTRIES.size()) or (slot <= -2 and slot >= -SpawnCatalog.GENERIC_IDS.size() - 1)
