extends RefCounted

# Explicit stage definitions for event-triggered trips.
# See scripts/game/special_stage_blueprint_guide.md for the authoring format.
const STAGES := {
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
