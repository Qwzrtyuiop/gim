extends RefCounted

# One locked offer keeps its distance and slot; only its waiting place changes.
# Stored fields make travel/save reloads reuse the same place and authored pose.
const SpawnCatalog := preload("res://scripts/ride_selection/passenger_area_spawn_catalog.gd")
const DISTANCES := ["short", "medium", "long"]
const LOCATIONS := ["station", "market", "street"]
const STREET_CHANCES := {"morning": 0.75, "noon": 0.40}
const MARKET_NAMED_CHANCES := {"morning": 0.20, "noon": 0.70}
const MARKET_GENERIC_CHANCES := {"morning": 0.30, "noon": 0.55}


static func assign(pools: Dictionary, phase: String, day: int, force_station := false) -> bool:
	var characters: Array[Dictionary] = []
	var unique: Dictionary = {}
	var fingerprint := "%d:%s" % [day, phase]
	for distance: String in DISTANCES:
		var cards: Array = pools.get(distance, [])
		for slot in range(cards.size()):
			if not cards[slot] is Dictionary:
				continue
			var character: Dictionary = cards[slot]
			var id := str(character.get("id", ""))
			if character.is_empty() or id.is_empty():
				continue
			characters.append(character)
			fingerprint += ":%s:%d:%s:%s:%s" % [distance, slot, id, str(character.get("stage_traffic", "")), str(character.get("stage_special_type", ""))]
			if not unique.has(id):
				unique[id] = character
	var daytime: bool = STREET_CHANCES.has(phase) and not force_station
	# Reserve saved generic spots before any newly assigned rider can take one.
	var market_slots: Dictionary = {}
	if daytime:
		for id: String in unique:
			var character: Dictionary = unique[id]
			if location(character) != "market" or not _is_generic(character):
				continue
			var slot := _market_slot(str(character.get("pickup_variant", "")))
			if slot >= 0 and not market_slots.has(slot):
				market_slots[slot] = id
	var assignments: Dictionary = {}
	for id: String in unique:
		var character: Dictionary = unique[id]
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = (fingerprint + ":" + id).hash()
		var area := "station"
		if daytime:
			var saved_area := str(character.get("pickup_location", ""))
			area = saved_area if _supports_area(character, saved_area) else _roll_area(character, phase, local_rng)
		var variant := ""
		if area == "market" and _is_generic(character):
			var slot := _market_slot(str(character.get("pickup_variant", "")))
			if slot < 0 or str(market_slots.get(slot, "")) != id:
				var available: Array[int] = []
				for index in range(SpawnCatalog.generic_count("market")):
					if not market_slots.has(index):
						available.append(index)
				if not available.is_empty():
					slot = available[local_rng.randi_range(0, available.size() - 1)]
					market_slots[slot] = id
				else:
					area = "station"
			if area == "market":
				variant = "slot_%d" % slot
		elif area != "station":
			var variants := SpawnCatalog.variant_ids(area, id)
			var saved_variant := str(character.get("pickup_variant", ""))
			variant = saved_variant if variants.has(saved_variant) else variants[local_rng.randi_range(0, variants.size() - 1)]
		assignments[id] = {"location": area, "variant": variant}
	var changed := false
	for character: Dictionary in characters:
		var assignment: Dictionary = assignments[str(character.id)]
		if character.get("pickup_location", "") != assignment.location or not character.has("pickup_variant") or character.pickup_variant != assignment.variant:
			character["pickup_location"] = assignment.location
			character["pickup_variant"] = assignment.variant
			changed = true
	return changed


static func location(character: Dictionary) -> String:
	var area := str(character.get("pickup_location", "station"))
	return area if LOCATIONS.has(area) else "station"


static func _supports_area(character: Dictionary, area: String) -> bool:
	if area == "station":
		return true
	if area == "market" and _is_generic(character):
		return SpawnCatalog.generic_count(area) > 0
	return not SpawnCatalog.variant_ids(area, str(character.get("id", ""))).is_empty()


static func _roll_area(character: Dictionary, phase: String, local_rng: RandomNumberGenerator) -> String:
	var id := str(character.get("id", ""))
	if not SpawnCatalog.variant_ids("street", id).is_empty():
		return "street" if local_rng.randf() < float(STREET_CHANCES[phase]) else "station"
	if not SpawnCatalog.variant_ids("market", id).is_empty():
		return "market" if local_rng.randf() < float(MARKET_NAMED_CHANCES[phase]) else "station"
	if _is_generic(character):
		return "market" if local_rng.randf() < float(MARKET_GENERIC_CHANCES[phase]) else "station"
	return "station"


static func _is_generic(character: Dictionary) -> bool:
	return bool(character.get("is_generic", false)) or str(character.get("id", "")).begins_with("generic_")


static func _market_slot(variant: String) -> int:
	if not variant.begins_with("slot_"):
		return -1
	var suffix := variant.trim_prefix("slot_")
	if not suffix.is_valid_int():
		return -1
	var slot := int(suffix)
	return slot if slot >= 0 and slot < SpawnCatalog.generic_count("market") else -1
