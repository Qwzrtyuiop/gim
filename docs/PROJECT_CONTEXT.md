# Gulong project context

Prepared for GPT Sol on 24 October 2026 (Australia/Perth). This is repository context, usable across Sol versions; it does not select a model in the client. Source files and current Git status take precedence over this snapshot.

## Quick orientation

Gulong is a single-player, Philippine-set 2D side-scrolling driving game. John Toda takes passenger trips to earn fares while managing fuel, energy, upgrades, karma, and PHP 50,000 debt. Encounters lead into branching visual-novel scenes and character progression. The normal loop is menu/new-run intro -> passenger selection -> driving -> eligible story -> results -> another ride, store, or sleep/home. Day phases are morning, noon, and night; debt collection occurs on Days 8, 15, 22, and so on.

- Engine: Godot 4.6; installed editor/console: 4.6.2.
- Rendering: Forward Plus, Windows D3D12; viewport 1280x720, `canvas_items` stretch.
- Entry: `res://scenes/main_menu.tscn` in [project.godot](../project.godot).
- Autoload order: InputBindings, AudioSettingsManager, StoryLanguageManager, PlayerState, SaveSlotManager, AmbientAudioManager, AchievementPopupManager, PauseMenuManager, UIAudioManager.
- Saves: ten scrollable notebook slots in `user://saves/slot_01.tres` through `slot_10.tres`. Slot 1 autosaves once on arrival at each new day; slots 2–10 are manual saves from Escape → Save. Escape → Load and the main-menu Load Game open the same selector. The notebook frame presents a scrollable slot list on its left page and a larger preview/day/location/time on the right; the scrollbar stays hidden. Start Ride always resets the live run and begins the intro on Day 1, preserving the saved slots. The version-4 codec still owns progress data; optional resource metadata holds time, location, thumbnail and live driving state. `user://progress_save.tres` remains an internal recovery checkpoint and migrates into Slot 2 when no slots exist. Language/audio preferences remain separate.
- Controls: W/Up and S/Down change lanes, D/Right accelerates, A/Left brakes, Shift boosts, Q holds the horn (repeat taps can persuade bottom-lane traffic), Escape pauses in supported scenes. Main-menu hold-R resets progress.
- `scripts/input_bindings.gd` adds physical WASD aliases to Godot's shared directional actions, retaining default arrow/gamepad bindings and enabling menu navigation on the same keys. Driving retains logical-letter fallbacks; tutorial content is unchanged.
- The Escape menu uses `ui/frames/notebookclosed.png`, cropped to the visible cover with controls kept clear of the binder. Save/Load open the matching two-page notebook selector.
- The notebook right page has DELETE SAVE for the selected occupied slot, including autosave and damaged files, with Cancel-focused confirmation in both pause and main-menu Load. Deletion leaves live/recovery progress intact, removes only that slot's generated previews, and records `user://saves/.legacy_migration_complete` to prevent recovery reimport after all slots are deleted. Empty slots disable deletion; Slot 1 remains deleted until the next normal daily autosave. `save_slot_deletion` is registered for future isolated validation; it has not been run for this feature edit.
- Park and market story backgrounds have shared day/night splash markers (`parkrain.png`, `marketrain.png`). `story/story_background_weather.gd` follows the drawn background through fit/zoom/pan, reuses outdoor rain/heavy-rain rendering and tint, and reads weather without rolling or saving. Its strict marker-color mode ignores natural yellows and transparent padding; falling rain covers the scene while splashes stay inside the painted regions.
- VN scene characters can opt into per-background layouts using `speaker_placement: "background"` or a manual portrait's `placement: "background"`. `story/story_location_spawns.gd` reuses existing terminal day/night placements and holds future authored location layouts. A portrait's `background_placements` map can supply per-location cutout/sheet rectangles and sprite variants. Missing world placements hide the character instead of reusing an old scale; foreground dialogue portraits retain their fixed-height mode. See the portrait guide's location-placement workflow; new park/market/bar character sheets still need authoring.
- Terminal generics also use `terminalspawns/genericspawns2.png`: six alternate poses retain the second sheet's exact positions and sizes at existing waiting spots. A deterministic day/phase/passenger choice keeps appearances stable across reopening and loading without changing passenger IDs, counts or gameplay RNG. Regenerate both generic sets with `tools/extract_terminal_spawns.py`.
- Home has a temporary MAP button. `home/home_map.gd` hosts the aspect-fitted `map/topdown_map_view.gd`; fixed source rectangles in `map/topdown_map_catalog.gd` follow `assets/map/mapguide.png` without drawing the guide. Home closes the map, Station uses the existing hub departure, and Market/Park/Bar show day/night destination previews with Map/Home navigation; Market also opens the existing Store. Hospital uses `hospitalday.png` for morning/noon and `hospitalnight.png` for night/midnight. The three marked road exits stay locked. Browsing/travel spends no time or resources and preserves passenger offers; previews are scene-local, with Escape returning through Map to Home before the pause menu.
- Map/destination title labels are removed. Bar visits always show `barnight.png` outside; an aspect-fitted building rectangle enters `bar.png` only during night/midnight. Day/noon entry attempts show John's pointerless "It's closed." bubble. Outside/Escape returns to the exterior before the map; entry hover/focus follows the shared pointer/keyboard mode.
- Day/noon bar clicks are blocked directly on the map with John's pointerless "It's closed. I should try again later." message. Night/midnight clicks still travel normally. The map's local speech layer is shared across the map and destination views.
- Rain masks named `_indoor.png` clip all visible rain to their painted openings. Home uses renamed `houserain_indoor.png`; story/map backgrounds use it for both house phases, `barrain_indoor.png` for the bar interior, and `hospitalrain_indoor.png` for both hospital phases. Outdoor falling rain still covers the scene with masked splashes. Shared CPU/shader strict marker detection accepts both authored lime colors while ignoring transparent padding.
- The top-down map also shows current rain/heavy rain and its matching tint, clipped to the fitted day/night artwork beneath the navigation UI. It reads the existing weather without rolling or saving, and keeps the shared ambient audio running.
- Town map areas follow the updated `mapguide.png`, including the northern road. Days 1–7 show John's construction/check-later message on click; Day 8 onward opens `northmap.png` / `northmapnight.png`. The marked south road and Back/Escape return to town, keeping weather, phase and resources unchanged. The day/guide north canvas is 1671px wide and night is 1672px; hit regions use normalized guide coordinates with the active artwork's fitted size.
- North guide areas now identify Pier, Basketball Court, Construction Site, School, Big Station, Church, Abandoned Building and Back to South. Until individual backgrounds are added, seven destination views crop their exact map areas using the active day/night art, with unmasked falling rain and Map/Home navigation. Map/Escape returns to the north map; the south road returns to town. The guide's unnamed flag-building box remains unassigned.

## Where to work

| Task | Start with |
| --- | --- |
| Shared balance, resources, shop prices, upgrades | `scripts/config/game_tuning.gd` |
| Stage profiles and modifier application | `scripts/game/stage_profiles.gd`, `scripts/game/game_stage_setup.gd` |
| Driving coordination, input, player movement | `scripts/game.gd`, `scripts/game/game_input.gd`, `scripts/game/player_vehicle_controller.gd` |
| Immediate passenger stories during driving | `scripts/game/ride_story_interruption.gd`, [driving story events](DRIVING_STORY_EVENTS.md) |
| NPC spawning, traffic AI, lane lookup | `scripts/game/vehicle_spawner.gd`, `scripts/game/vehicle_traffic_controller.gd`, `scripts/game/vehicle_behaviors.gd`, `scripts/game/vehicle_traffic_index.gd` |
| Hitboxes and collision rules | `scripts/game/vehicle_geometry.gd`, `scripts/game/vehicle_collision_controller.gd` |
| Menu traffic and wheels | `scripts/game/menu_traffic_controller.gd`, `scripts/game/vehicle_wheel_animation.gd` |
| Fare, trip completion, crash repair | `scripts/game/game_economy_manager.gd`, `scripts/game/game_flow_controller.gd`, `scripts/repair_transition.gd`, `scripts/state/player_crash_repair_state.gd` |
| Persistent state and migrations | `scripts/player_state.gd`, `scripts/state/`, `scripts/save/player_state_save_codec.gd`, `scripts/save/game_save_resource.gd` |
| Save slots, daily autosave, notebook selector, live ride restoration | `scripts/save/save_slot_manager.gd`, `scripts/save/save_game_context.gd`, `scripts/save/driving_save_snapshot.gd`, `scripts/ui/save_slot_screen.gd` |
| Selection, rider identities/progress | `scripts/ride_selection.gd`, `scripts/seeded_rider_runtime.gd`, `scripts/story/story_catalog.gd`, `scripts/story/story_catalog_data.gd` |
| Daily flow, rest, results | `scripts/day_start_scene.gd`, `scripts/stage_results.gd`, `scripts/sleep_transition.gd` |
| Story registry, routing, triggers | `scripts/story/story_payload_catalog.gd`, `scripts/story/story_trigger_service.gd`, `scripts/story/story_trigger_runtime.gd` |
| Story schema, rendering, actions, resume | `scripts/story/story_payload.gd`, `scripts/story_scene.gd`, `scripts/story/story_action_runner.gd`, `scripts/story/story_checkpoint.gd` |
| Authored stories and translations | `scripts/story/payloads/` |
| Memories, gallery, achievements | `scripts/story/story_memory_catalog.gd`, `scripts/story/story_gallery_unlocker.gd`, `scripts/gallery_library.gd`, `scripts/achievement_service.gd` |
| Shared interface, pause, audio | `scripts/ui/`, `scripts/audio_settings_manager.gd` |

## Working-tree handoff

Snapshot base: branch `main`, HEAD `feccfa8` (Stop tracking local Godot editor settings). There were 34 tracked changed/deleted files plus untracked implementation files and `tests/` before context preparation. These are existing work, not changes made to prepare this handoff. Run `git status --short` and inspect the relevant diff before continuing; do not reset or recreate deleted files blindly.

Current changes visible in source:

- Save slots preserve independent snapshots and confirm overwrites/loads. Manual previews capture the scene before the pause overlay appears; daily saves use its background artwork. Day-start writes wait for a stable scene and completed actions; money changes/location visits do not overwrite Slot 1. Loading an older day permits the next reached day to replace the autosave again. Starting/resetting a run preserves manual slots. Live driving restores distance, timers, vehicle positions/state and RNG; hazard cues restart in full and music/visual particles restart with the scene. Story slots capture the current presentation/action cursor even while text reveals, at choice prompts, during action waits and before the first line. Capture writes a separate payload into the slot without closing the live reader's batch or changing its pending checkpoint; reached text loads fully revealed and silently, and remaining actions run once. Loading closes the discarded reader's batches before applying the selected save. Scene transitions, story completion, unrelated state batches and gallery replay still block saving. `tests/save_slot_checks.gd` covers the slot UI, independence, driving restoration and daily trigger; `tests/story_slot_save_checks.gd` covers VN save/resume and batch isolation. Focused `save_slot` and `story_slot_save` checks passed together on 26 October in 9.7 seconds.
- Save-overhaul validation on 26 October: the full isolated Godot suite passed with 38 localized payloads, real Escape input, save/load, checkpoint/action-cursor, hub, driving, ambience and replay coverage (137.5 seconds Godot, 138.5 seconds total). All six Python fixture/runner tests passed. Story wait timers honor pause, and the old scene stays paused until the loaded scene is installed. No interactive visual playtest or export was performed; existing certificate-store and ObjectDB exit diagnostics remain, alongside expected invalid-input rejection warnings.
- Latest full validation on 26 October passed after adding map travel/bar hours, hospital backgrounds, map/indoor rain, WASD, alternate generic opacity, per-location portraits and camera regressions (134.6 seconds Godot, 135.7 seconds total; 38 localized payloads). All six Python fixture/runner tests passed, as did generic-sheet extraction and preload/UID/diff checks. Reproduced and fixed VN zoom-out being discarded by the centered-fit branch: camera rendering now keeps the calculated fitted size and padding while centering smaller images and panning larger ones. All new targets are registered in the full suite. Existing certificate-store/ObjectDB exit warnings remain; no interactive visual/audio playtest or export was performed.
- VN Escape input consumes its press after opening pause so the global handler cannot toggle it closed again; held-key repeats are ignored. The VN save regression sends actual viewport key presses/releases during standalone and inline driving stories, including typing, choices, waits and intro. Memory viewing disables the Save button, and the slot backend rejects manual saves and daily autosaves even if called directly without story context. Rejected attempts leave slot files, live progress, the recovery checkpoint and autosave marker unchanged.
- Story builders across intro, events, and character encounters now use a shared normalized schema in the new `story_payload.gd`. The old `payloads/events/random_event_payload.gd` and its UID are deleted. The payload guide and template document the canonical format.
- The new `story_checkpoint.gd` and changes to `story_scene.gd` capture reached presentation state, batch saves per completed step, and retain an action cursor when exiting during an animated step. Resume continues remaining actions without repeating completed rewards. Gallery replay remains separate from persistent effects.
- `story_catalog.gd` indexes static identity data while constructing live progress/name results and returning independent dictionaries.
- Jessa's runaway-fare trigger becomes eligible after a completed morning/noon ride, including before Day 2. Before that encounter is completed, her live passenger availability is morning/noon; afterward it returns to its existing night schedule. Narrow saved-rule migrations preserve consumed events and custom rules. Tests cover unpaid fare, hidden name, daytime/nighttime eligibility, migration, and once-per-run behavior in both languages.
- The new `vehicle_traffic_index.gd` caches ordered lane buckets per owner/frame. Spawn, removal, reset, and lane changes invalidate it. Collision rectangles cache by geometry inputs so same-frame movement/scale/texture changes can refresh them.
- Traffic-jam trips use `game/traffic_jam_gaps.gd` to split the main queue into groups of three or four cars with 650-pixel bumper gaps. Drivers preserve these openings; shoulder spawns and NPC lane changes avoid filling them. Tuning lives in `stage_profiles.gd`, and retries reset the grouping. Other traffic modes retain their usual spawning.
- Eligible passenger character scenes take priority over the Day 2 station-bill event. Only the selected scene's trigger is consumed; the bill remains available for a later eligible morning/noon ride. Other scheduled-event priority and character prerequisites remain as authored.
- Busy trips retain ordinary bottom-lane spawns: right-edge entry, 35–280 speed range, parked vehicles and 11–17.5-second base spawn delays. Busy speed/density randomization applies to the upper lanes. Cars from other lanes can still merge into the bottom lane using normal clearance checks; horn and overtaking exceptions remain available.
- `tests/run_refactor_checks.py` and the Godot regression scene are untracked parts of this work and must be preserved with their dependencies.

The next request was to clean up code and put related functions in their respective files. The organization below reflects that refactor; story content and saved IDs/section indices were preserved.

## Function ownership after cleanup

After a night trip ends, the hubs display **Midnight** and the terminal has no
passengers until the next day. Home's Ride action still opens the station street;
walking between home, station and store does not advance time or recover energy.
`state/player_day_phase_tracker.gd` derives closure from the existing result's
day/time (including failed trips and skipped nights), so saved version-4 runs
also respect it. The underlying phase remains `night` for sleep, weather and
story triggers. A reserved story night also blocks passenger selection.
Random, seeded, cached and scripted passenger departures share this gate, and
closed-terminal visits preserve existing locked pools. Actual sleep starts the
new day and reopens passenger selection.
`audio/ambient_audio_manager.gd` keeps shared ambience alive across locations,
using `ui/hub_night_ambience.gd` for the layered mix: the existing
`ambience/night.mp3` bed at -12 dB, a 25% dog-bark chance every five seconds at
home/store/station, and a looping `cars.mp3` layer at the station/terminal only.
These layers run during night and midnight. Dogs use eight quiet-boundary excerpts
from the original `night_dogs.mp3`, lasting 2-2.95 seconds at -28 dB; cars use
-22 dB. The helper's constants own this mix and cadence. Its private RNG does not
affect passenger or driving rolls, and barks cannot overlap. All layers register
as SFX. At midnight, home/station/store music stops; night results also discard
the carried driving track but retain rain ambience. Earlier phases keep their
music. Home rest refreshes ambience when the clock reaches night. Home, store
and station reuse the same rain/night players and dog timers, retaining playback
through scene handoffs. Traffic is enabled only at the station/terminal. Rides
and results also reuse shared rain/night loops, without hub dogs or traffic;
result rain resumes its saved offset only after a cold start. Music remains owned
by each screen. Pause suspends ambience; weather/phase changes adjust only the
affected layers. Menus, sleep and authored story scenes stop the shared mix so
their own audio can take over. Startup does not roll weather or save progress.
`tests/ambient_continuity_checks.gd` covers real travel handoffs and cleanup.
`tests/hub_ambience_checks.gd` covers layering,
seeded dog checks, cadence, pause, ownership and gameplay-RNG isolation.
`ui/station_idle_music.gd` adds music after spending 60 seconds on the
station/terminal screen. A private RNG chooses `music/story/jazz.mp3` or `midnight.mp3`
and loops that track until leaving the station, replacing normal station music while
leaving ambience running. Jazz's base volume is -14 dB and midnight's is 0 dB
to balance their different source levels; both use the Music category. This
idle track is an intentional exception to midnight's usual music silence.
Mouse, keyboard, touch and controller interaction do not reset the visit timer
or stop the track. Pause freezes playback
and the timer. Departure prevents a new idle track, and leaving the scene frees
the player/timer. Overlay and header refreshes preserve the idle session. No idle
music runs at home or the store. `tests/station_idle_music_checks.gd` covers
selection, interaction-independent timing/playback, pause, ownership and state isolation.
`tests/midnight_checks.gd` covers save/reload,
stale confirmation and entry guards, empty terminal navigation, sleep reopening,
midnight music and ambience ownership/pause. The full isolated regression suite and source/diff
checks passed. Headless checks do not establish audible mix quality.

The store street now uses aligned 1698x926 `store.png` / `storenight.png` art and
the transparent `store_select.png` rectangle borders. Four shared full rectangles
select Lito's, the food counter, Home and Station, including their transparent
interiors; there are no separate night hit areas or alpha scans for store input.
`ui/store_street_view.gd` uses the shared pointer/keyboard mode and lighting from
the current clock. Midnight uses the shuttered `storemidnight.png` image in the
same fitted canvas. Shop rectangles remain selectable and show John's floating
"It's closed." response; entry and purchases remain blocked. Home and Station
exits remain available without spending a turn. Unseen shop tutorials wait for reopening. See
[store selection artwork](STORE_SELECTIONS.md).
Seven unused sources (five older station images, the garage spotlight and the
duplicate house selector) moved to `locations/check/unused/` with their image
bytes and import UIDs retained. Previous station path migrations still point
directly to the current station art; garage-spotlight paths migrate to its archive
location. Source sheets used by extraction tools remain active, and author-deleted
images were not restored. The archive README records the moved files.
The full isolated suite passed with `tests/store_select_checks.gd` covering
rectangular interiors, shared phases, resizing/focus, actual shop entry/purchases,
tutorial gates and archived save paths. Import/source hashes and moved-image bytes
were checked, with UIDs retained. A separate 16-case headless layout probe and
inspected composites covered both lighting phases and all four selection borders.
No interactive GUI playtest or export was performed; existing certificate-store
and exit-leak diagnostics remain.

Home now uses the aligned 1698x926 day/night backgrounds and the transparent
`locations/houseselect.png` sheet. Radio, calendar and sleeping curtain have
shared cached alpha masks and source regions, with phase-matched yellow-outlined
hover art. A selected item enlarges 6% above the room; its resting alpha remains
the hit shape. Phase changes only swap art and do not rebuild day/night hitboxes.
Home now uses the shared pointer/keyboard highlight mode so clicked items do not
remain enlarged after the pointer leaves. The existing bottom-right exit polygon,
actions, tutorials and modal rules remain. Speech anchors follow item enlargement.
`ui/house_selectable_catalog.gd` owns placement/art/masks and `ui/house_view.gd`
owns rendering/input. See [house selection artwork](HOUSE_SELECTABLES.md) for
regeneration commands, source rectangles and validation. User source images and
deleted older day/night selection images were preserved as supplied.
The full isolated suite passed with `tests/house_select_checks.gd` covering
shared masks, transparent picking, hover/focus isolation, three aspect ratios,
real home actions and speech anchors. The extraction/pixel checks and imported
source hashes passed. A separate 18-case headless probe and inspected day/night
composites covered foreground enlargement down to 640x360. No interactive GUI
playtest or export was performed; existing certificate-store/exit-leak diagnostics
remain.

Home, station/terminal and store now expose scene-local `show_message` /
`show_messages` APIs for speech balloons beside sprites or registered hotspots.
`ui/hub_dialogue.gd` owns transient queues, optional blocking input, localization,
gated/timed playback and the existing text-reveal/SFX helper;
`ui/hub_speech_box.gd` owns safe balloon/tail layout and bounded scrolling;
`ui/hub_dialogue_anchors.gd` tracks letterboxed art, terminal sprites and fitted
shop-owner portraits. Tutorials, home info panels and passenger confirmation
suspend speech; navigation/rest clears it. Store greetings and purchase/error
feedback demonstrate the feature. There are no new save fields, story actions or
automatic home/terminal conversations. See [hub speech authoring](HUB_DIALOGUE.md)
for targets, queues, custom Control/Sprite2D anchors and continuation signals.
The full isolated suite passed with `tests/hub_dialogue_checks.gd` covering queue
callbacks/cancellation, Unicode reveal, localized/hidden names, click isolation,
pause/blocking input, gated timers, moving/hidden/freed targets and real menu
integration. Store speech avoids visible purchase controls at standard and square
sizes. Independent headless probes and inspected composites cover home, terminal
and store, long-message scrolling and close clicks down to 640x360. No interactive
GUI/audio playtest or export was performed; existing certificate-store/exit-leak
diagnostics remain.

The ride-results screen now uses the terminal's warm dark panels over the city
background, with a full passenger portrait, a structured fare receipt, a prominent
total and a weekly-goal panel. `results/results_view.gd` owns presentation and
switches to a two-row composition for square/narrow viewports;
`results/result_passenger.gd` resolves the completed ride's saved identity and
hidden display name. Named passengers use existing VN portraits; generic/unknown
passengers use the existing silhouette. Failed rides now also retain the existing
`character_id` result key. Older results fall back to the current passenger only
when that key is absent. Authored unpaid/waived fares, penalties, failure reasons
and skipped-phase notes remain in the receipt. The goal bar shows available money
against the current collection goal; it does not record a debt payment.
`stage_results.gd` retains payout, music and Rest/Store/Ride routing.
The post-ride Rest button now returns directly home at the current clock, without
recovery or rest counters; it remains available even after the daily rest was used.
The existing home Rest/Sleep confirmation owns energy recovery and time changes.
Returning home preserves locked offers and pending night events, including on Day 1.
`tests/post_ride_home_checks.gd` verifies the actual result-to-home handoff, repeated
click protection, confirmed daytime/night recovery and deferred Benny night story.
`tests/results_screen_checks.gd` covers saved identity, portrait fitting, payout
once, special receipts, action availability, low-energy cancellation and three
viewport sizes. The full isolated suite passed. A separate headless probe and
inspected composites also cover 640x360 and tall/square portrait art; no interactive
GUI playtest or export was performed. Existing certificate-store/exit-leak
diagnostics remain.

Jessa's first encounter is daytime-only. `StoryCatalog` resolves
`intro_eligible_times` while `intro_completion_event` is not true, so merely seeing
her card or gaining ride progress does not switch her to nighttime availability.
After completing that event, she is absent for the rest of its recorded day and
can return on later nights. The live catalog derives `unavailable_day` from the
existing saved `jessa_runaway_fare_earnings.day`; no new persisted field, story
section or save-version change is needed. Shared `story/character_availability.gd`
checks the projected trip day and phase for random, seeded and cached offers.
Missing historical dates in older saves preserve the previous night schedule.
Her first-event trigger filters the completed ride's morning/noon phase, even if
finishing a noon ride has already moved the live clock to night. Older built-in
unrestricted trigger rules migrate without resetting consumed events; existing
locked night rides do not trigger the event or lose their fare. Story IDs, section
indices, current checkpoints and later encounter rules are preserved.
Coverage includes both localized daytime first encounters, nighttime fare/trigger
preservation, old/current saved-rule migration and `tests/jessa_daytime_checks.gd`
passenger-pool checks. The same-day absence also covers saved/seeded/terminal
offers, later-night availability, checkpoint reload and replay isolation.
Source/UID/link and diff checks passed; existing certificate-store/exit-leak
diagnostics remain.

Q uses a trimmed PCM `hold_horn.wav` derived from the original `hold_horn.mp3`
through a dedicated registered SFX player. The source MP3 is preserved; playback
uses its 0.12-1.10s audible core with 1ms edge fades, removing startup/tail silence
and MP3 decoding from horn taps. The WAV import uses uncompressed 16-bit PCM;
the regression checks for audible samples within the first 10ms. Holding it loops
the sound; separate presses count toward the nearest same-direction normal driver
ahead in the bottom lane when the player is in that lane (350-pixel bumper range).
Each car needs 2-5 taps, with counts resetting after a 2.5-second gap. At its
threshold it chooses ignore (30%), accelerate (35%) or pull over (35%); a blocked
pull-over falls back to acceleration. Ignore/response decisions stay with that car.
Acceleration lasts three seconds and respects following safety. Yielding cars stop,
move down to parked-car level, then allow passage once visibly off the driving
line. Existing parked cars, speeders and oncoming traffic do not react. Pausing,
focus loss, crash repair, ride completion and leaving gameplay stop the horn.
`game/player_horn_controller.gd` owns input/hold/cooldown; `vehicle_horn_response.gd`
owns patience, responses and shoulder clearance. Shared tuning uses `HORN_*` in
`config/game_tuning.gd`; normal following and overlap order is preserved. Reactions
are live traffic state and reset with a ride restart rather than changing saves.
The full isolated suite passed with `tests/horn_checks.gd` covering Q/audio lifecycle,
tap thresholds/timeout, all three seeded reactions, following/cap safety, occupied
shoulders, delayed pass-through and pause/focus/end cleanup. Three runner safety
tests and source/UID/link checks also passed. Existing certificate-store/exit-leak
diagnostics remain; no interactive driving/audio playtest or export was performed.

`ride_selection.tscn` now opens on the station street. Click the foreground
tricycle to enter the terminal, or the outlined entrance at
the far left edge to visit the store. The replacement art uses `Updated_day.png`
/ `Updated_night.png` with `Updated_day_select.png` / `Updated_night_select.png`
for hover outlines.
Both phases share a 1672x941 composition; source-pixel polygon traces scale with
the image, including the tricycle canopy and the narrow store entrance.
Selection, story and gallery references use the new paths; saved station
backgrounds and gallery keys migrate through `save/asset_path_migration.gd`.
`ui/station_view.gd` draws day/night art and the matching supplied outline inside
separate polygon hotspots. The passenger screen now uses `terminalday.png` /
`terminalnight.png` with individually segmented characters at the exact positions
in the supplied transparent day/night spawn sheets. All locked distances appear
together; hover/focus shows each passenger's trip in a padded card with separate
name/route/traffic, an optional special badge and aligned fare/fuel/risk columns.
Clicking opens a confirmation with the same card; Confirm uses the existing
ride/story entry. Cancel/Escape/backdrop returns without saves, costs, clock or
offer changes. The modal blocks background controls and starts on Cancel for
keyboard input. It revalidates the exact locked offer and clock before departure.
`passenger_trip_card.gd` and `passenger_confirmation.gd` own this presentation;
the coordinator owns the transient request and existing entry path.
Generic riders use eight faceless poses extracted from
`terminalspawns/genericspawns.png`, shared across day/night. Named spots are reserved
first; generics fill unused positions in stable ID order. Dante also reserves the
first standing spot to avoid an edge overlap. A full nine-offer lineup can use an
extra narrow standing position at the far left. Future missing art retains the
empty-box fallback; the existing six generic passenger IDs and fare rules stay intact.
Hover/focus replaces the resting sprite with one 6% larger foreground image,
anchored at its feet; the previous shifted-copy outline has been removed.
Shared `ui/input_highlight_mode.gd` distinguishes pointer hover from intentional
keyboard/controller navigation. Programmatic focus on terminal open/close no longer
leaves the tricycle or one passenger highlighted while the mouse is elsewhere;
Tab/arrows/controller navigation still exposes focus until the pointer is used.
The terminal and station share the same `HubStatusHeader` instance and styling,
with live money/energy/fuel icons and values. The terminal uses its optional
display-time override for the projected trip's day/phase; closing it returns the
header to the current clock. Passenger instructions start below the header and
the tutorial highlights the shared header instead of duplicate plain text.
`terminal_spawn_catalog.gd` owns placements; `terminal_passenger_view.gd` owns
rendering and alpha-aware input; `selection_view.gd` gathers live eligible offers
and formats details. The old card panel and distance controls have been removed.
See [terminal passenger art and behavior](TERMINAL_PASSENGERS.md), including the
lossless extraction command. `ride_selection/station_interface.gd` owns terminal
navigation, header and back control. Closing the screen preserves offers and
the last selected distance. The first passenger tutorial starts on open;
the prologue's opening ride enters the terminal automatically. The same first-ride
check repairs older station saves whose passenger tutorial has not started;
later visits use the street normally. Both localized intro handoffs have a real
reader-to-selection regression that verifies tutorial visibility and one entry cost.
Saved passenger stories return to the open terminal. Its `passengers_open` flag uses
the existing pending-selection dictionary. Same-mode rest transitions also retain
their locked offers when walking to the store and back, without time/resource costs.
The full isolated regression suite passed, including actual pointer clicks on the
tricycle, terminal passengers and generic riders; all-distance offers; live/projected
schedules and Jessa's intro gate; tutorial gating; resizing; store round trips;
saved VN returns; and one-time repair of wholly unusable legacy locks. Extraction
checks prove all 23 crops reproduce the transparent placement sheets exactly.
Pointer/focus checks cover automatic focus, mouse departure, keyboard navigation,
opening/closing and resumed terminals. Header checks cover shared styling, live
resource updates, projected time and layout at three aspect ratios.
Confirmation checks cover no-effect cancellation, Escape/focus/background input,
stale-clock rejection, correct confirmed trips, one-time costs and Jessa's event
starting only after confirmation. Shared trip-card bounds and column separation
are checked at three viewport sizes, with a separate component probe at 640x360.
Source/UID/link and diff checks passed. Independent headless view probes and
inspected composites covered both phases and information-panel/control separation;
no interactive GUI playtest or export was performed. Existing certificate-store
and exit-leak diagnostics remain.

VN character sprites now support named variants. Magda uses saved ID `faye` with
`magda` as an alias; her `alt` variant resolves `Magda_alt.png`. Jessa's `alt`
variant resolves `Jessa_alt.png` under her existing `jessa` ID. The shared
`story_character_sprites.gd` registry owns character art/aliases, while
`story_character_sprite_runtime.gd` owns scene-local selections. Use a line's
`sprite`, initial payload `character_sprites`, or a `set_character_sprite` action.
Automatic speakers and named casts retain their choices through checkpoints;
memory playback remains isolated. See [sprite authoring](../scripts/story/story_portraits_guide.md#character-sprite-variants).
The full isolated suite passed with sprite-specific tests for remembered choices,
named-cast geometry/custom textures, stale texture aliases, old checkpoints,
special-CG visibility and live-save isolation during memory playback. Three runner
checks and source/UID/link checks passed. User-supplied character art was preserved;
no GUI playtest or export was performed.

Passenger selections support `passenger_selected` story triggers before entry
costs or time advancement. Jessa's second encounter (`jessa_second_encounter`)
requires her completed runaway-fare event and contains the full English/Tagalog
confrontation, with police and warning branches. Both endings return at the same
clock with the other offers preserved; Jessa leaves until the live phase changes,
including across revisits/reloads and projected trip phases. Only the warning
branch reveals her name when she introduces herself. Branch, completion and
phase-absence flags use existing event values.

Hana's `hana_first_encounter` (Lost ID 1) replaces her bond-2 placeholder after
a completed ride. Reading the ID reveals her name; finishing the scene records
the ID in existing story event values. `hana_second_encounter` (Lost ID 2) starts
when Hana is next selected at the terminal after event 1. It returns the ID,
awards her notebook, plays funny music at the notebook reveal, and returns to the
same selection without a ride or time cost. Hana leaves that live phase's offers,
using the same saved absence handling as Jessa. Both item images show during
their relevant lines. English is authored; Tagalog body text stays `to be translated`.

Gardo's `gardo_first_encounter` plays once after a completed nighttime ride,
without a bond gate. Accepting starts `gardo_extra_lap`, repeating that route
and distance in the same night with double fare rate and no new entry cost.
Refusing pays the original fare, returns home, and raises his future midnight
encounter chance from 35% to 70%. English contains the full scene; Tagalog body
text remains `to be translated`. No checks were run for this addition.

`ride_selection/passenger_story.gd` owns the saved continuation;
`ride_selection/ride_departure.gd` shares normal ride entry with the card screen.
The new `selection_outcome` action supports `return`, `ride`, and `skip` (one phase).
See [passenger events](../scripts/story/passenger_events_guide.md) for authoring,
chained stories and longer skips. These use existing version-4 dictionaries.
The full isolated regression suite passed with passenger-event checks for both
languages, pre-cost entry, unchanged offers/time, rest recovery, optional rides
and phase skips, actual reader handoffs, saved departure reload and replay
suppression. Three runner safety checks and source/UID/link checks also passed.
The runner now allows 24000 frames/120 seconds for the expanded suite; expected
invalid-input warnings and existing certificate-store/exit-leak diagnostics remain.
No GUI playtest or export was performed for this addition.

Story text now reveals gradually with original retro talking blips by default.
`scripts/story/story_dialogue_playback.gd` owns Label reveal/skip timing;
`story_dialogue_voice.gd` owns a dedicated SFX player; defaults and speaker pitches
live in `scripts/config/story_dialogue_settings.gd`. See
[dialogue playback authoring](../scripts/story/story_dialogue_playback_guide.md).
The first Continue press finishes text, the next advances; choices wait until
reveal/actions finish. Narration is silent, pause freezes playback, and reached
checkpoint text reloads fully without replaying effects or voice.
The final isolated suite passed with dedicated real-timing playback and audio
checks, including partial Unicode reveal, first/second Continue, choice gating,
pause, silent reload, voice cadence/mute and custom clip isolation. Existing
behavior tests explicitly opt into instant text in their disposable fixture;
production text remains animated. Three runner tests and source/UID/link checks
also passed; the existing certificate-store and exit-leak diagnostics remain.

The VN system now also exposes opt-in gameplay commands. See
[`scripts/story/story_game_controls_guide.md`](../scripts/story/story_game_controls_guide.md)
for authoring and the unregistered gameplay event template. `story_action_catalog.gd`
owns supported-command metadata/validation, `story_game_effects.gd` owns resource,
upgrade, debt, counter and weather effects, `story_game_flow.gd` owns queued handoffs,
and `state/player_story_time_state.gd` owns calendar advancement through normal debt
and daily rules. Conditions support gameplay values and boolean groups; choices
can display unmet requirements. Existing stories and driving tuning are unchanged.

VN upgrade verification: the full isolated Godot suite passed after adding
`story_time_controls_checks.gd`, `story_game_effects_checks.gd`,
`story_branch_tools_checks.gd`, and `story_game_flow_checks.gd`. Tests include real
reader/save/resume, interruption during a time skip, chained scenes, home/game-over
handoffs, replay suppression, cross-date collections, invalid conditions/effects,
and example-template validation. Three runner safety tests and source/link/UID
checks also passed. Invalid-input tests intentionally emit rejection warnings;
the existing certificate-store and ObjectDB exit diagnostics remain. No GUI
playtest or export was performed for this upgrade.

Scene scripts coordinate lifecycle, input, signals, and scene transitions. Domain helpers hold related implementations and call the owning helper directly. Story progression and scene signal callbacks remain available; unused story/menu/home/store forwarding methods were removed in a second pass. The traffic facade preserves the static API used by other controllers.

| Responsibility | Implementation owner |
| --- | --- |
| Story music/SFX, resume audio, fades | `scripts/story/story_audio_runtime.gd` |
| Story conditions and conditional section routing | `scripts/story/story_conditions.gd` |
| Backgrounds/camera, portraits, gallery capture, screen fades | `scripts/story/story_presentation.gd` |
| Story dialogue/choice UI, themes, debt overlays | `scripts/story/story_interface.gd` |
| Persistent story actions and replay classification | `scripts/story/story_action_runner.gd` |
| Trigger defaults, normalization, and saved-rule migrations | `scripts/story/story_trigger_rules.gd`; matching and payload selection remain in `story_trigger_service.gd` |
| Traffic entity state and warning presentation | `scripts/game/vehicle_traffic_entities.gd`, `scripts/game/vehicle_traffic_signals.gd` |
| Lane prediction/safety, spacing/overlap/pin relief, maneuvers | `scripts/game/vehicle_lane_navigation.gd`, `scripts/game/vehicle_traffic_spacing.gd`, `scripts/game/vehicle_traffic_maneuvers.gd` |
| Shared spawn calculations | `scripts/game/vehicle_spawn_rules.gd` (keeps spawner/scheduler dependencies acyclic) |
| Passenger pools and seeded offer generation | `scripts/ride_selection/passenger_pool.gd` |
| Passenger cards, portraits, risk display, selection tutorial | `scripts/ride_selection/selection_view.gd`, `scripts/ride_selection/selection_tutorial.gd` |
| Store item presentation/purchases and tutorial | `scripts/store/store_items.gd`, `scripts/store/store_tutorial.gd` |
| Main-menu debug tools and audio/language controls | `scripts/menu/main_menu_debug.gd`, `scripts/menu/main_menu_settings.gd` |
| Home panels/calendar/radio and tutorial | `scripts/home/home_interface.gd`, `scripts/home/home_tutorial.gd` |
| Shared tutorial overlay construction | `scripts/ui/tutorial_overlay_helper.gd`; each screen helper keeps its own steps and control-lock behavior |
| Gallery grids/memories/previews and library themes | `scripts/library/gallery_view.gd`, `scripts/library/library_theme.gd`; gallery/achievements scenes retain navigation and callbacks |
| Player hit recovery/visuals and background selection | Existing `scripts/game/player_vehicle_controller.gd` and `scripts/game/game_environment_controller.gd` |
| Seeded-rule mutation and result/payout state | Existing `scripts/seeded_rider_runtime.gd` and `scripts/state/player_stage_state.gd`; `PlayerState` remains the public facade |

The gameplay audio manager is now a child of the gameplay scene, so leaving the scene frees it with its audio players. This fixes an orphaned manager without changing playback rules.

The second pass also fixed resumed choices reapplying older choice event metadata over event changes made by completed actions. Metadata now applies only at the start of the choice; the saved action cursor continues the remaining actions. A focused interrupted-choice regression covers event preservation and one-time rewards.

## Confirmed bug fixes

- Day rollover now captures the original phase before changing the clock, so entering a collection day cannot skip debt. Day/weather/debt changes and trip-entry recovery/energy costs save as completed batches.
- Save reloads bypass Godot's mutable resource cache. Snapshot writes use a checked temporary file beside the destination, replace the previous save only after a successful write, clean up failed replacements, and report write errors without changing the version-4 data contract.
- Optional choice responses append runtime sections behind an explicit original-end marker, preserving authored jump indices and preventing response continuation loops, including nested choices and save/resume.
- Gallery playback uses transient `pending_memory_replay` state. Persistent `pending_story` and the live resume scene remain intact through memory completion, interruption, and unrelated autosaves. Replay state is not serialized.
- Traffic warning beeps no longer clear an active audio buffer. Speeders cannot replace another vehicle's pending warning or repeatedly restart its countdown.
- Texture hitbox caches use texture identity so distinct runtime textures with empty resource paths retain independent bounds.

Focused regressions live in `tests/day_flow_bug_checks.gd`, `tests/save_bug_checks.gd`, `tests/story_bug_checks.gd`, and `tests/traffic_bug_checks.gd`, and run through the isolated suite. The day-rollover, entry-save, stale-cache, audio-buffer, hitbox-cache, and warning-ownership failures were reproduced before their fixes.

## Read the relevant guide

- [Story payload contract and regression runner](../scripts/story/story_payloads_guide.md)
- [Story portrait authoring](../scripts/story/story_portraits_guide.md)
- [Random ride events](../scripts/story/random_ride_events_guide.md)
- [Special-stage blueprints](../scripts/game/special_stage_blueprint_guide.md)
- [Longer development reference](../DEVELOPMENT_REFERENCE.md)

The development reference began as a 5 October audit and was updated through 20 October. Its file counts, lack-of-tests statement, story-resume findings, and line-number citations predate the current changes. Verify them in source before treating them as open bugs. The Tagalog Day 7 payload still has three `test` lines; Bayanihan retains an English fallback. An authored payload existing in both languages does not imply full translation. The special-stage registry remains intentionally empty.

## Local commands and safe validation

Run from the repository root in PowerShell. Godot is not on PATH in the inspected environment. `.vscode/settings.json` contains the local editor path and is ignored by Git; the console executable below also exists.

```powershell
$godotConsole = 'C:/Users/qwzrt/Documents/godot/Godot_v4.6.2-stable_win64_console.exe'
& $godotConsole --version

# List focused checks without preparing a fixture or launching Godot.
python tests/run_refactor_checks.py --list

# When requested, run only the relevant checks (requires imported assets).
python tests/run_refactor_checks.py --godot $godotConsole --check payloads
# Repeat --check to select several targets in one isolated run.
python tests/run_refactor_checks.py --godot $godotConsole --check story_dialogue_voice --check story_dialogue_playback

# Run the entire suite only when explicitly requested.
python tests/run_refactor_checks.py --godot $godotConsole --full

# Fixture-copy safety and stale-source checks (no Godot dependency).
python -m unittest discover -s tests -p test_refactor_runner.py -v

# Check whitespace and inspect the working-tree status.
git diff --check
git status --short
```

Skip checks unless the user requests them. Small dialogue, music-cue and presentation edits do not need a regression run or new tests. When checks are requested, select the smallest relevant target and do not repeat passing checks without a new reason. The runner requires `--check` or `--full`, preventing accidental full-suite runs.

On a fresh checkout, import assets with the Godot editor before running regressions. The runner refreshes mirrored scripts, scenes and tests in `.godot/refactor_checks/`; assets and imported resources copy only when size or modification time changes, with stale files removed. Copies remain independent of live sources. It checks resolved destination paths before removal, including fixture-root aliases. It preserves fixture `test_user/`, redirects `user://` paths there, and instruments save counts in the copy. It uses headless GL compatibility rendering, with a 30-second focused timeout and a 150-second full-suite timeout; `--timeout SECONDS` overrides either. It reports preparation and runtime separately, and focused targets report their duration. Success requires exit code 0, no unexpected engine/script errors, and the selected/full PASS marker. Godot output is buffered until the process exits.

On 26 October 2026 the full isolated suite passed in 129 seconds after updating
Isidro's old scaffold fixtures for the authored no-fare ending. It includes 26
localized payloads and the street-background/seated-sprite checks. The existing
certificate-store error, deliberate invalid-input warnings and ObjectDB exit-leak
warning remain. The 150-second full-suite timeout accommodates this measured run.

Covered checks: registered payloads in both languages and English fallbacks, schema normalization/legacy adaptation/jump bounds, catalog identity and live progress, Jessa first-ride routing/migration, traffic lane order/membership, same-frame collision cache invalidation, following, one-save-per-step behavior, real save/load, branch-correct presentation, interrupted actions, and authored Elena/Jessa resumes. Cleanup coverage also exercises seeded-rule copy/mutation behavior, one-time payout batching, real menu/home/store/selection scenes, tutorial completion, shop purchases, locked passenger offers across distances, and driving initialization/traffic/hit visuals in normal, busy, and speeders profiles. Warning playback is enabled after fixing the active-buffer error; accelerated driving still does not verify real-time Tween/audio timing.

For changed behavior beyond those checks, use a disposable save and test the relevant branches: traffic at low FPS and lane transitions; economy across all phases and debt collection; stories in both languages, reward-line reload, and gallery replay; UI at the reference resolution and another aspect ratio. Headless checks do not establish visual/audio quality or export readiness.

## Validation at handoff

After the 24 October 2026 bug-fix pass, the expanded isolated runner exited 0 with `PASS: all refactor regression checks`, including all four focused bug-check modules, 20 localized payload builds, and the earlier scene/checkpoint/traffic coverage. The suite now also checks cached-save refresh, failed replacement cleanup, debt rollover, entry-save batching, real warning audio, independent runtime-texture hitboxes, competing speeders, response routing, and replay preservation of live checkpoints. Three Python runner tests passed for stale-source removal, wrong destinations, and fixture-root aliases. Godot still logged the pre-existing `Failed to read the root certificate store` and ObjectDB leak warning at exit. No interactive playtest or export was performed.

Documentation links, source whitespace, literal preload paths, and script UID presence/uniqueness were checked. The original context-only setup added `AGENTS.md` and this file; the subsequent cleanup reorganizes the modules listed above and expands the existing regression suite. Generated tooling/test artifacts stay under ignored `.godot/`. Existing gameplay/story edits were preserved.

The root `AGENTS.md` follows the [official Codex repository-guidance convention](https://learn.chatgpt.com/docs/customization/overview). Model selection remains a client setting; no model or global configuration was changed.
