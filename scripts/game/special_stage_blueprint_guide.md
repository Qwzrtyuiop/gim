# Special Stage Blueprint Guide

`special` stages are custom gameplay variants that sit on top of the normal stage flow.

## Already Wired
- `PlayerState.current_stage_special_type` can now be `special`.
- `PlayerState.current_special_stage_id` stores the concrete custom mode id, such as `police_chase`.
- `ride_selection.gd` passes `special_stage_id` into `PlayerState` when a rider card is chosen.
- `game.gd` exposes `special_stage_id` and `special_stage_blueprint` at runtime.
- `game_stage_setup.gd` has `SPECIAL_STAGE_BLUEPRINTS` plus `apply_special_stage_blueprint(owner)`.
- Stage results now preserve `special_stage_id` for completed and failed stages.

## Current Behavior
- Nothing new happens yet by default.
- `SPECIAL_STAGE_BLUEPRINTS` is empty, so all `special` stages are still inert until you register one.
- The scaffold only applies blueprint modifiers if both of these are true:
- `stage_special_type == "special"`
- `special_stage_id` matches an entry in `SPECIAL_STAGE_BLUEPRINTS`

## Blueprint Shape
Use this shape inside `scripts/game/game_stage_setup.gd`:

```gdscript
const SPECIAL_STAGE_BLUEPRINTS := {
	"police_chase": {
		"display_name": "Police Chase",
		"modifiers": {
			"time_limit_multiplier": 0.78,
			"player_acceleration_x_multiplier": 1.12,
			"player_max_speed_limit": 640.0,
		},
		"metadata": {
			"spawn_police": true,
			"heat_level": 2,
			"vehicle_override": "res://assets/vehicles/player_tricycle.png",
		},
	},
}
```

## Supported Modifier Keys
These already flow through `_apply_numeric_owner_modifier(...)`:
- `fare_php_per_meter`
- `time_limit`
- `time_bonus_php_per_second`
- `overtime_fare_penalty_php_per_second`
- `player_max_speed`
- `player_acceleration_x`
- `player_brake_x`
- `player_lane_lerp_x`
- `player_coast_x`

You can also use the existing suffix patterns:
- `_multiplier`
- `_delta`
- `_min`
- `_cap`

Special case already supported:
- `player_max_speed_limit`

## How To Assign One
Wherever you build the chosen rider/stage payload, set:

```gdscript
{
	"stage_special_type": "special",
	"special_stage_id": "police_chase",
}
```

If `stage_special_type` is not `special`, the runtime automatically clears `special_stage_id`.

## Runtime Access
Inside gameplay:
- `owner.stage_special_type`
- `owner.special_stage_id`
- `owner.special_stage_blueprint`

That means later you can branch on either the id or metadata:

```gdscript
if owner.special_stage_id == "police_chase":
	# Spawn cop vehicles, sirens, chase UI, etc.
	pass
```

## Recommended Pattern
- Use `stage_special_type = "special"` as the top-level bucket.
- Use `special_stage_id` for the actual scenario name.
- Keep numeric tuning in `modifiers`.
- Keep non-numeric flags, asset paths, and custom behavior settings in `metadata`.
- Put bespoke runtime logic in the controller that owns that behavior, not all inside `game_stage_setup.gd`.

## Good Future Examples
- `police_chase`
- `borrowed_motorcycle`
- `flooded_road`
- `broken_brakes`
- `vip_convoy`
- `escape_route`

## Suggested Next Step
When you are ready to build the first one, start with a blueprint that only changes modifiers and one metadata flag. Then wire one controller to react to that metadata so the first custom mode stays easy to test.
