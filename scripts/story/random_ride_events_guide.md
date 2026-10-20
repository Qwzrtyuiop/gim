# Random ride events

Malasakit rolls after a completed ride with a passenger marked `is_generic` in
the character catalog. Scheduled and character stories take priority. Named
characters, unknown passengers, failed trips, and already-paid results are
ineligible. Event-triggered special stages keep their own completion flow.

Edit `MALASAKIT_EVENT_CHANCE` in `scripts/config/game_tuning.gd` (default
`0.10`, or 10%). Each eligible result rolls once; that decision saves with
`last_stage_result`. Once selected, Malasakit is consumed for the run regardless
of the player's choice. Existing saves need no reset; newly completed rides
record the passenger ID needed for eligibility.

The English and Tagalog dialogue live in `payloads/events/malasakit.gd` and
`payloads/events/malasakit_tagalog.gd`. Both use `random_event_payload.gd`
for the shared station background and city ambience, matching Day 2. Use that
shared presentation for future random ride events too. Passenger dialogue uses
`assets/characters/placeholder.png` through the speaker portrait mapping.

Register both language scripts in `story_payload_catalog.gd` and build events
through that catalog. Memories and unlock-all automatically use the same entries;
there is no second memory list to update. Seen Malasakit scenes in existing saves
appear immediately. Character portraits are excluded from gallery images,
including portrait unlocks saved by older versions.

The original fare, time bonus, passenger penalty, and total are retained in
`last_stage_result.original_ride_earnings` and copied into the pending story.
The results screen pays out only after the event resolves:

- Collect: receive the exact original total, without recalculating or adding a
  second reward.
- Waive: receive zero for the entire ride, including its time bonus. Unlock
  Malasakit and increase future fares by `MALASAKIT_FARE_BONUS` (default `0.05`).

The bonus applies to every passenger's fare, including special rides, and to
ride-selection estimates. It does not increase time bonuses, stack, or expire
within the run. New runs reset it. Save/resume retains the chosen outcome and
bonus; memory replay cannot change earnings or unlock the reward.

The final line of each branch runs `resolve_random_ride_fare`, then jumps to
the end of the composition so one branch cannot fall through into the other.
The settlement and achievement save together, and repeat execution is harmless.
