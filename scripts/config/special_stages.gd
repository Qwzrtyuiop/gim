extends RefCounted

# Explicit stage definitions for event-triggered trips. No stages are enabled yet.
# See scripts/game/special_stage_blueprint_guide.md for the authoring format.
const STAGES := {}


static func get_definition(stage_id: String) -> Dictionary:
	return Dictionary(STAGES.get(stage_id.strip_edges().to_lower(), {})).duplicate(true)
