# Random ride events

## Repeatable generic passenger moments

Ten short events in `payloads/events/generic/` use the same Day-3-and-later,
Day-2-bill-completed gate as the existing random events. Scheduled/character
stories (including the Day 2 bill), the due Malasakit epilogue, and selected
Malasakit/Bayanihan events take priority. If none plays, generic passengers get
`GENERIC_PASSENGER_EVENT_CHANCE` (25%) to roll one eligible minor event uniformly.
Named passengers, failed rides and paid results cannot roll these scenes.

| Event | Reward | Additional requirement |
| --- | --- | --- |
| Keep the Change | PhP 20, stress -1 | No overtime |
| A Compliment | Stress -2 | None |
| An Extra Tip | PhP 15, stress -1 | Completed ride was morning/noon |
| Lucky Day | PhP 30, stress -1 | None |
| A Quiet Ride | Stress -2 | No crashes/collisions |
| Rounding Up | PhP 20 | None |
| A Friendly Passenger | Stress -2 | None |
| A Small Favor | PhP 25, stress -1 | None |
| An Unexpected Conversation | Stress -2 | None |
| A Generous Stranger | PhP 40, stress -1 | None |

`generic_passenger_events.gd` owns eligibility. The completed result stores
`had_crash` before achievement tracking resets ride flags; it also supplies the
completed phase/overtime rather than the already-advanced live clock. Selection
is cached in the result's existing random-event fields and is never rerolled for
that ride. These story IDs have no run-wide consumed marker, so later rides can
repeat them; each new occurrence resets its section cursor. Rewards are ordinary
persistent actions on the final reward line, covered by the story checkpoint and
suppressed in Memories. Tips add directly to cash in addition to the normal ride
payout. Scenes use day/night street art, no added music, and aligned Tagalog
"to be translated" placeholders. No save-version change is needed.

## Bayanihan

Bayanihan uses `BAYANIHAN_EVENT_CHANCE` (default 10%) after a completed
unnamed-passenger ride, once per run, with the same post-Day-2 gate below.
The due Malasakit epilogue takes priority. Otherwise, one draw allocates each
available event its configured chance, so only one event plays per result.
If configured chances total more than 100%, their weights are normalized.

`payloads/events/bayanihan.gd` contains the supplied English script, also used
as the Tagalog fallback until a translation is supplied. It uses the shared
background/music and the placeholder Driver portrait. Helping unlocks Bayanihan
with its permanent +5% fare bonus (additive with Malasakit's +5%)
and records `bayanihan_outcome = help`; declining records `decline`. Neither
choice changes the ride payout, energy, or gas. Helping skips the phase following
the completed ride, with a warning on the choice: after a morning ride it skips
noon, leaving night available; after a noon ride it skips night and the results
screen leads into overnight sleep. It cannot roll after a night ride. Eligibility
uses the completed ride's time, since the live clock has already advanced.
The skip and achievement are saved together and cannot repeat on resume; stale
passenger selections are cleared. Results keep the completed ride's payout and
offer the correct rest transition for the new time. Replays do not grant the
achievement or change the saved outcome. The event is registered in the shared
catalog, so it appears in Memories automatically.

All random events unlock on Day 3 or later, after either choice has completed
the Day 2 station-bill event (`day_2_station_bill`). This shared gate covers
Malasakit, its epilogue, and random story pools. Blocked rides do not roll or
consume an event. A previously selected pending story can still resume.

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
`payloads/events/malasakit_tagalog.gd`. Both use the standard payload format from
`story_payloads_guide.md`, with `StoryConstants.BACKGROUND_STATION` and
`StoryConstants.STATION_MUSIC` for the shared presentation matching Day 2. Use
those defaults for matching station scenes. The minor passenger moments instead
use completed-phase street backgrounds without an added music cue. Passenger dialogue uses
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

## Malasakit epilogue

Waiving the original fare also saves its exact earnings breakdown and day in
`event_values.malasakit_waived_earnings`. This survives subsequent rides.
Starting the following day, the epilogue is guaranteed after the next eligible
completed unnamed-passenger ride. Scheduled stories still take priority; named
passengers and failed rides do not consume it. The delay is editable through
`MALASAKIT_EPILOGUE_DELAY_DAYS` (minimum one day).

The final line pays back the original waived total directly. The latest ride's
earnings remain separate, and the Malasakit fare bonus stays active. Payment and
`malasakit_repaid` save together, preventing duplicate payments on resume.
The epilogue occurs once per run and automatically becomes a replayable Memory
when seen. Replay does not pay money.

Older saves recover the amount from the original Malasakit result or pending
story snapshot when available. If later rides already overwrote that snapshot,
the exact old amount cannot be recovered; the epilogue stays ineligible rather
than using a different ride's earnings.
