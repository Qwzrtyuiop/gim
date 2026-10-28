# Events when selecting a passenger

Use the `passenger_selected` trigger phase to start a story when a passenger card
is clicked, before entry costs or ride advancement. Other passengers and normal
rides keep their usual behavior. Existing saves receive missing built-in rules
without resetting consumed triggers.

Jessa's second event is registered as `jessa_second_encounter`. It requires
`jessa_runaway_fare_seen: true`, then triggers once when she is selected from her
normal passenger offers. It does not force her to appear. The English and Tagalog
[Jessa payloads](payloads/characters/jessa/jessa_second_encounter.gd) confront her
about the unpaid fare, then offer police or warning branches. Both endings mark
`jessa_second_encounter_seen` and return at the same clock with the other offers
preserved. Jessa leaves until that live phase changes; the saved
`jessa_second_encounter_absence` day/phase also blocks random, seeded and cached
offers on revisits/reloads. An entirely empty lineup can roll other passengers.
The choice
is saved as `jessa_second_encounter_choice` (`police` or `warning`). Only her
spoken introduction in the warning branch sets `jessa_name_revealed`; explicit
speaker labels preserve the reveal in memory replays without changing live state.
The original scaffold completion at section 1 remains reserved for older saves;
new encounters jump over it into the appended scene.

## Schedule another passenger event

Register localized payload builders in `story_payload_catalog.gd`, then add a
rule to `story_trigger_rules.gd` or insert one through `add_story_trigger`:

```gdscript
{
	"id": "another_passenger_event",
	"phase": "passenger_selected",
	"character_id": "jessa",
	"bypass_character_story_gate": true,
	"required_events": ["jessa_runaway_fare_seen"],
	"payload_id": "registered_payload_id",
}
```

`bypass_character_story_gate` allows an encounter before the Day 2 bill event;
omit it when the normal character-story gate should apply. Normal trigger
conditions and one-shot consumption apply. Day, time, distance, traffic and stage
type describe the selected offer. `current_time_of_day` describes the live clock,
which may differ when selection follows rest or another transition.

Set the payload's `return_scene` and `next_scene` to
`res://scenes/ride_selection.tscn` for the default return. Missing destinations
receive that default. No action is required to keep the clock, resources,
selected distance, passenger offers, back destination and transition mode.

## Choose the outcome

Use a line or choice action; the handoff waits until dialogue finishes:

```gdscript
"actions": [
	{
		"type": "selection_outcome",
		"outcome": "ride",
	},
]
```

| Outcome | Behavior |
| --- | --- |
| `return` | Return to the existing passenger selection. This is the default. |
| `ride` | Start the clicked passenger's stored ride, with its distance, traffic and special type. Apply normal entry checks, stress relief and trip stress once. |
| `skip` | Spend one calendar phase without a ride or entry cost, then return to fresh offers in the reached phase. Daily resets and debt collection still apply. |

`skip` advances the live clock by one phase, even when a selection screen is
previewing a later ride phase through a rest transition.

If a queued ride cannot start, return to selection and show the normal entry
error. The player can refuel, rest or choose another passenger. Fuel still drains
during driving rather than on entry.

For longer skips, use existing `skip_phases`, `skip_days` or `advance_time`, then
`selection_outcome` with `return` or `ride`. A changed clock discards old offers
and uses `current_stage` so the next ride does not advance time a second time.
A `ride` outcome after a skip keeps the originally clicked passenger and their
stored trip settings as a scripted continuation, even if their usual availability
differs in the reached phase.

The last destination action wins: `return_to` may send the player home, to the
store or to the menu instead. `queue_story` carries the passenger continuation
and chosen outcome into the next registered story, and only its final completion
starts a ride. Failure goes to game over. `start_special_stage` takes priority
and uses its own existing driving flow; author it as an alternative outcome.

## Saves and implementation

The selected passenger snapshot and outcome live inside the existing saved
`pending_story` dictionary. They do not require a save-format change. Trigger
consumption and story entry save together; story departure and clearing the
pending story save together. Existing checkpoint/action cursors prevent a skip
or cost from repeating after reload. Memory playback suppresses these effects.
The clicked passenger becomes the active character for story actions that omit
an explicit character ID; merely opening the event does not award ride progress.

- `ride_selection/passenger_story.gd` owns trigger entry and continuation.
- `ride_selection/ride_departure.gd` owns normal departure checks and setup.
- `story_game_flow.gd` routes actions and story chains.
- `tests/passenger_story_checks.gd` covers eligibility, actual card/reader return,
  save/resume, unchanged offers/time, optional rides/skips and replay isolation.

Paths above are relative to `scripts/` except the regression file. Run the
[isolated regression suite](story_payloads_guide.md) before changing this flow.
