# Special stages after story events

Definitions live in `scripts/config/special_stages.gd`. Its `STAGES` registry is
intentionally empty until actual stages are designed. Ordinary trips are unchanged.

## Define a stage

Add an entry to `STAGES`. This is an example only, not an enabled stage:

```gdscript
const STAGES := {
    "example_trip": {
        "display_name": "Example Trip",
        "stage_type": "short-night-speeders",
        "target_distance": 800.0,
        # Optional: omit to retain the current passenger.
        "character_id": "benny",
        "modifiers": {
            "time_limit": 90.0,
            "fare_php_per_meter": 0.0,
            "time_bonus_php_per_second": 0.0,
        },
        "metadata": {},
    },
}
```

`stage_type` is required and explicit: distance (`short`, `medium`, `long`),
time (`morning`, `noon`, `night`), and traffic (`chill`, `normal`, `traffic-jam`,
`busy`, `speeders`). Invalid or missing definitions warn and leave the event's
normal destination intact; they do not silently pick a random stage.

`target_distance` is optional; without it, the usual distance range is used.
`display_name` and `metadata` are available to future custom UI/controllers;
metadata alone does not implement new behavior.

## Trigger it from an event

Put this action on a dialogue line or choice in the event payload:

```gdscript
{
    "speaker": "John",
    "text": "Let's go.",
    "actions": [
        {"type": "start_special_stage", "id": "example_trip"},
    ],
}
```

The action queues the stage. Remaining dialogue plays normally, then the story's
outro fades directly into gameplay, bypassing ride selection. The queue is saved
with the story; the last executed `start_special_stage` action wins. Put it on a
branch if only that choice should launch the stage. Add it to both language
payloads when they should behave identically.

Gallery/memory replays ignore this action and cannot launch a real trip.

## Entry and completion

- Each new scripted driving leg requires fuel, positive hull and 1 energy.
  Entry spends 1 energy and adds 1 stress once; reloading the paid leg is free.
- Normal stress handling penalties, fuel/boost restrictions and collision damage
  apply. Collisions raise stress and damage hull without spending energy.
  Hull reaching zero ends the trip and starts repairs; maximum stress is playable.
- Gate optional extra-ride choices on energy, hull and fuel so an exhausted player
  can choose the non-driving branch instead.
- The stage replaces the next trip, using the explicit time in `stage_type` as
  its calendar slot. Morning completion advances to noon; noon advances to night;
  night completion offers the normal overnight rest, not another night trip.
- An earlier time than the current phase, or an already-used slot, belongs to
  the next day. A later explicit time skips intervening slots. Day rollover uses
  normal daily conditions and debt collection.
- Successful completion pays once and opens the special trip's results. It does
  not restore the preceding result or return to an interrupted sleep/ride
  selection. Those pending transitions are cleared when the special trip starts.
  The preceding fare is paid before launch so it cannot be overwritten.
- Fatal collisions abandon the special stage and enter the normal repair flow.
- Save/resume preserves the chosen definition and calendar slot. A saved
  completed special stage finishes its handoff instead of replaying the trip.
  In-progress driving resumes from the beginning, as ordinary driving does.

## Modifiers and custom behavior

Supported numeric keys:

- `fare_php_per_meter`
- `time_limit`
- `time_bonus_php_per_second`
- `overtime_fare_penalty_php_per_second`
- `player_max_speed`
- `player_acceleration_x`
- `player_brake_x`
- `player_lane_lerp_x`
- `player_coast_x`

Each supports `_multiplier`, `_delta`, `_min`, and `_cap` suffixes.
`player_max_speed_limit` is also supported.

Gameplay exposes `owner.stage_special_type`, `owner.special_stage_id`, and
`owner.special_stage_blueprint`. Put future scenario mechanics in the relevant
controller, reading the blueprint's `metadata`.

The existing rider-card assignment (`stage_special_type: "special"` and
`special_stage_id`) still works and shares this registry. The event entry bypass
applies only to `start_special_stage`, not ordinary ride selection.
