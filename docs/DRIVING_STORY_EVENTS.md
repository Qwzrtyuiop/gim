# Driving story events

Isidro's first event (`isidro_first_encounter`, saved character ID `ito`)
interrupts his ride immediately when either condition is reached:

- Speed exceeds 70 kph, using the unrounded speedometer conversion.
- The player receives one accepted vehicle collision, including a parked vehicle.

There is no relationship, completed-ride or Day 2 story requirement. Harmless
low-speed passing, disabled collision areas and invincibility contacts do not
count. The event consumes its trigger once per run. The English scene contains
the bribe/fine conversation; Tagalog remains `to be translated` with functional
choices. Offering to pay the fine requires PhP 2,000, but both branches ultimately
pay PhP 200. With less than PhP 200, Isidro takes the remaining cash.

`scripts/game/ride_story_interruption.gd` pauses the current driving subtree and
its audio, then opens the VN above gameplay. Distance, timer, fuel, traffic and
the current vehicle positions remain frozen. Isidro's scene uses
`driving_outcome = "end_without_fare"`: either ending closes the ride early,
records completion and advances the phase once, with zero fare and bonus.
Other interruption payloads can resume the same game instance without entry
costs or time advancement by omitting that outcome.
Collision damage still applies once; a fatal collision plays the event before
continuing through the normal repair flow.

Story checkpoints carry `_driving_interruption` in the existing pending-story
dictionary. Returning from the menu resumes that checkpoint; finishing then
restarts the driving scene under the game's existing live-ride save behavior,
without charging entry energy again. Fatal checkpoints preserve the repair
handoff. Memory replays cannot consume triggers, award progress or begin repairs.
Queued stories carry the interruption context until the final handoff.

The trigger phase is `driving`, with `unsafe_driving: true` in its context.
The threshold is `ISIDRO_FIRST_EVENT_SPEED_KMH` in
`scripts/config/game_tuning.gd`. `GameFlowController` records peak speed and
accepted collisions; completed results retain those values for future use.

Author the English scene in
`scripts/story/payloads/characters/isidro/isidro_first_encounter.gd`.
Keep the separate Tagalog placeholder until a translation is requested.
