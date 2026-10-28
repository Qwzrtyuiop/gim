# Story controls for gameplay

Stories can now change game state and arrange the next scene through the same
ordered `actions` used for music and portraits. Put actions on a line or choice;
use `conditions` to decide when they run. No existing story is automatically
converted, and normal driving balance is unchanged.

Copy [gameplay_event_template.gd](payloads/templates/gameplay_event_template.gd)
for a complete branching event, or use the examples below. Register an actual
English/Tagalog pair in `story_payload_catalog.gd` and schedule it with the existing
trigger system. The example template is deliberately unregistered.

## Skip time and recover

```gdscript
"actions": [
	{
		"type": "advance_time",
		"days": 2,
		"clear_stress": true,
	},
]
```

`days` moves to morning on the target date. Use `phases` instead to spend calendar
slots: morning -> noon -> night -> next morning. Specify exactly one positive
whole count, at most 365 days or 1095 phases. `skip_days` and `skip_phases` are
shortcuts with `amount` (default 1).

Skipping time does not charge trip energy or stress, create completed rides, roll passenger
offers, or award rest achievements. Recovery is explicit: use `clear_stress:
true` to clear stress or `relieve_stress: 3` for a capped reduction. Without
either, stress is unchanged. Use `restore_energy: true` to refill the independent
energy budget or `recover_energy: 3` for partial energy recovery. Do not combine
full and partial recovery of the same resource.

Every crossed date runs daily resets, weather/gas-price setup and debt collection.
An unpaid later collection still ends the run, and advancement stops at that date.
The reached phase's weather becomes available to subsequent story conditions.
The current dialogue continues; after it ends the player goes home, or to game
over if collection failed. A later `return_to` can choose another destination.

An unresolved random-fare choice, active crash repair, active special trip, failed
run, or invalid arguments reject the action without changing time. Resolve the
fare before skipping. A payable completed fare is settled once before advancement.
Old passenger offers/sleep setup are cleared; the active story and rider identity
remain available to later lines. Already-paid entry energy and stress are not refunded.

Skipping dates does not play every intervening scheduled cutscene. Those trigger
rules keep their existing eligibility semantics; use `queue_story` when a specific
follow-up scene must play.

## Game effects

| Action | Parameters and result |
| --- | --- |
| `set_resource` | `resource`, `value`: set money, energy, stress, hull, gas, or karma |
| `change_resource` | `resource`, `amount`: add or subtract one of those resources |
| `add_gas` / `spend_gas` | Nonnegative `amount` in gas percentage points; spending rejects insufficient fuel |
| `restore_energy` | Optional nonnegative whole `amount`; omit to refill energy to 5 |
| `relieve_stress` | Optional nonnegative whole `amount`; omit to clear stress |
| `add_stress` | Nonnegative whole `amount`; caps at 10 |
| `damage_hull` / `repair_hull` | Nonnegative whole `amount`; hull stays within 0-10 |
| `set_upgrade_level` | Configured upgrade `id`, whole `level`; capped at its purchase limit |
| `add_upgrade_level` | Configured upgrade `id`, signed whole `amount`; capped between zero and its limit |
| `increment_event_value` | Counter `id`, optional numeric `amount` (default 1); creates missing counters at zero |
| `pay_debt` | Nonnegative whole `amount`; spends available money against remaining principal |
| `forgive_debt` | Nonnegative whole `amount`; reduces principal without spending money |
| `set_weather` | `weather`: clear, cloudy, rain, or heavy rain, for the current phase |

Resources retain their normal bounds: money/energy/stress/hull/gas cannot become negative,
energy is capped at 5, stress and hull at 10; gas cannot exceed capacity, and karma can be negative. Whole units
are required except for gas and event counters. Unknown resources/upgrades,
nonnumeric counters, infinite values and malformed parameters reject without
partial mutation. Legacy `tire_grip` resolves to fuel efficiency.

Debt actions affect principal; they do not mark a scheduled weekly collection as
paid or reset its history/carryover. The next collection remains due and is capped
by the remaining principal. Weather overrides are saved for the current phase;
they do not rewrite the day's forecast or future phases.

Existing actions still work, including money/energy/stress/hull/karma effects, achievements,
character progress/locks, event values, seeded riders, trigger insertion and
`start_special_stage`. See [special stages](../game/special_stage_blueprint_guide.md)
for explicit scripted driving scenarios.

## Branch on game state

New predicates belong inside `conditions`, so action parameters such as `days`
or `weather` are never accidentally treated as eligibility checks.

```gdscript
{
	"text": "Buy fuel (PhP 100)",
	"conditions": {
		"min_money": 100,
		"max_gas": 90,
	},
	"show_locked": true,
	"locked_text": "Buy fuel (PhP 100)",
	"locked_reason": "Needs PhP 100 and room in the tank.",
	"actions": [
		{"type": "spend_money", "amount": 100},
		{"type": "add_gas", "amount": 10},
	],
	"next_index": REFUELLED,
}
```

- Exact, `min_`, and `max_` checks: money, energy, stress, hull, gas, karma, day, week,
  remaining_debt and character_progress. Progress also requires `character_id`.
- Exact text checks: `phase` (or `time_of_day`) and `weather`.
- Upgrade maps: `upgrade_levels`, `min_upgrade_levels`, `max_upgrade_levels`,
  such as `"min_upgrade_levels": {"engine_tune": 2}`.
- Counter bounds: `"event_value_ranges": {"benny_trust": {"min": 2, "max": 5}}`.
  Also supports `equals`, `less_than` and `more_than`. A missing or nonnumeric
  counter does not match.
- Boolean groups: `all` / `any` arrays of condition dictionaries, and `not` with
  one condition dictionary. Maximum nesting is 16. Invalid new predicate schemas
  fail closed, including inside negation.

Existing required/forbidden events, exact event values, achievements and money
aliases remain supported. Event presence is distinct from event truth: a key
with value false still satisfies `required_events`.

Unmet choices are hidden by default. Set `show_locked: true` to display them
disabled with optional replacement text and a tooltip explaining the requirement.
If every displayed choice is locked, normal Continue becomes available. Always
provide a safe line-level `next_index` fallback; Continue follows that route.
New numeric/text predicates also accept `required_` forms outside `conditions`
for compatibility, but nested conditions are clearer for new content.

## Control what happens after dialogue

Passenger-card events can return to the same offers, start the selected ride,
or skip a phase with `selection_outcome`. See
[passenger event authoring](passenger_events_guide.md) for its trigger phase,
outcomes and save behavior.

```gdscript
"actions": [
	{"type": "return_to", "destination": "store"},
	{"type": "queue_story", "id": "benny_tropa_night"},
]
```

- `return_to`: home, store, ride_selection, or main_menu. The handoff waits for
  the current story to finish. A hub/selection handoff uses the current calendar
  slot and settles any payable previous fare. It does not start a free drive.
- `queue_story`: registered story `id` to play next, in the selected language,
  before the final destination. It starts at section zero. The last queued ID wins;
  unknown IDs and self-queueing reject. Scheduling a chain does not consume a
  separate trigger or override a story's own persistent one-shot rules.
- `end_run`: nonempty `reason`. The run is marked failed; remaining dialogue can
  explain the outcome, then the game-over screen opens.

Failure overrides other destinations. Existing `start_special_stage` takes
priority over a queued next story when both appear; author one handoff per branch.
Otherwise a queued story plays first, then its supplied destination. Later story
lines may override that destination with their own controls. Returning to the menu
saves home as the Continue destination. Legacy line/choice `next_scene` still works.

## Saves, memories and authoring checks

The runtime checkpoints the ordered action cursor and the chosen handoff together.
Loading during a wait continues the remaining actions; completed time skips,
rewards and counters do not repeat. A completed line or choice plus its destination
line flushes one batched save. Save format stays at version 4; new handoff fields
are stored inside the existing pending-story dictionary.

All game-control actions are suppressed in gallery replays, including direct
action dispatch, while music/portraits/camera/dialogue still run. Replays cannot
spend money, skip dates, change weather, start a drive, chain live stories or end
the run.

`StoryPayload.validate(payload)` now reports unknown action types and invalid
new action arguments. `story_action_catalog.gd` is the shared supported-command
and persistence registry. Runtime checks reject unknown actions with a warning.
Use normal conditions to guard costs; actions execute in order and are not a
general rollback transaction if an author combines unrelated failed commands.

Run the isolated regression suite from the root. New checks cover time/debt
boundaries, resources, upgrades, counters, weather, locked choices, boolean
conditions, save/resume, chaining through the actual story reader, and replay
isolation. The example template is validated but does not enable a game event.

Energy is an independent daily activity budget alongside stress and hull. Use `restore_energy` or `add_energy` for energy, `relieve_stress` for stress, and `repair_hull` for hull. Gallery replays suppress these persistent changes. Older saves retain their energy while deriving initial stress from their old energy ratio.
