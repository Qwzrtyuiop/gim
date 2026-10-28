extends RefCounted

# Explicit stage definitions for event-triggered trips.
# See scripts/game/special_stage_blueprint_guide.md for the authoring format.
const STAGES := {
	"alma_special_delivery": {
		"display_name": "Special Delivery",
		"stage_type": "long-night-busy",
		"character_id": "alma",
		"modifiers": {
			"fare_php_per_meter_multiplier": 2.0,
		},
		"metadata": {
			"no_gas_usage": true,
			"no_stress_gain": true,
			"truck_horn": true,
			"truck_horn_cooldown": 5.0,
			"crash_protection": 10,
			"passenger_trait": "urgent",
			"music": "res://assets/audio/music/driving/alma_drive.mp3",
		},
	},
	"gardo_extra_lap": {
		"display_name": "One More Lap",
		"stage_type": "long-night-chill",
		"character_id": "gardo",
		"repeat_last_stage": true,
		"modifiers": {
			"fare_php_per_meter_multiplier": 2.0,
		},
	},
}


static func get_definition(stage_id: String) -> Dictionary:
	return Dictionary(STAGES.get(stage_id.strip_edges().to_lower(), {})).duplicate(true)


static func uses_gas(stage_id: String) -> bool:
	var definition: Dictionary = STAGES.get(stage_id.strip_edges().to_lower(), {})
	var metadata: Dictionary = definition.get("metadata", {})
	return not bool(metadata.get("no_gas_usage", false))


static func gains_stress(stage_id: String) -> bool:
	var definition: Dictionary = STAGES.get(stage_id.strip_edges().to_lower(), {})
	var metadata: Dictionary = definition.get("metadata", {})
	return not bool(metadata.get("no_stress_gain", false))
