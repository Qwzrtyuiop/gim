# Gulong project context

Prepared for GPT Sol on 24 October 2026 (Australia/Perth). This is repository context, usable across Sol versions; it does not select a model in the client. Source files and current Git status take precedence over this snapshot.

## Quick orientation

Gulong is a single-player, Philippine-set 2D side-scrolling driving game. John Toda takes passenger trips to earn fares while managing fuel, energy, upgrades, karma, and PHP 50,000 debt. Encounters lead into branching visual-novel scenes and character progression. The normal loop is menu/new-run intro -> passenger selection -> driving -> eligible story -> results -> another ride, store, or sleep/home. Day phases are morning, noon, and night; debt collection occurs on Days 8, 15, 22, and so on.

- Engine: Godot 4.6; installed editor/console: 4.6.2.
- Rendering: Forward Plus, Windows D3D12; viewport 1280x720, `canvas_items` stretch.
- Entry: `res://scenes/main_menu.tscn` in [project.godot](../project.godot).
- Autoload order: AudioSettingsManager, StoryLanguageManager, PlayerState, AchievementPopupManager, PauseMenuManager, UIAudioManager.
- Saves: `user://progress_save.tres`, explicit version-4 resource/codec. Language and audio preferences use separate files. Live driving is restarted rather than restored as an exact traffic/RNG snapshot.
- Controls: W/Up and S/Down change lanes, D/Right accelerates, A/Left brakes, Shift boosts, Escape pauses in supported scenes. Main-menu hold-R resets progress.

## Where to work

| Task | Start with |
| --- | --- |
| Shared balance, resources, shop prices, upgrades | `scripts/config/game_tuning.gd` |
| Stage profiles and modifier application | `scripts/game/stage_profiles.gd`, `scripts/game/game_stage_setup.gd` |
| Driving coordination, input, player movement | `scripts/game.gd`, `scripts/game/game_input.gd`, `scripts/game/player_vehicle_controller.gd` |
| NPC spawning, traffic AI, lane lookup | `scripts/game/vehicle_spawner.gd`, `scripts/game/vehicle_traffic_controller.gd`, `scripts/game/vehicle_behaviors.gd`, `scripts/game/vehicle_traffic_index.gd` |
| Hitboxes and collision rules | `scripts/game/vehicle_geometry.gd`, `scripts/game/vehicle_collision_controller.gd` |
| Menu traffic and wheels | `scripts/game/menu_traffic_controller.gd`, `scripts/game/vehicle_wheel_animation.gd` |
| Fare, trip completion, crash repair | `scripts/game/game_economy_manager.gd`, `scripts/game/game_flow_controller.gd`, `scripts/repair_transition.gd`, `scripts/state/player_crash_repair_state.gd` |
| Persistent state and migrations | `scripts/player_state.gd`, `scripts/state/`, `scripts/save/player_state_save_codec.gd`, `scripts/save/game_save_resource.gd` |
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

- Story builders across intro, events, and character encounters now use a shared normalized schema in the new `story_payload.gd`. The old `payloads/events/random_event_payload.gd` and its UID are deleted. The payload guide and template document the canonical format.
- The new `story_checkpoint.gd` and changes to `story_scene.gd` capture reached presentation state, batch saves per completed step, and retain an action cursor when exiting during an animated step. Resume continues remaining actions without repeating completed rewards. Gallery replay remains separate from persistent effects.
- `story_catalog.gd` indexes static identity data while constructing live progress/name results and returning independent dictionaries.
- Jessa's runaway-fare trigger now becomes eligible after her first completed ride, including before Day 2, with a narrowly matched migration of the older saved trigger rule. Tests cover unpaid fare, hidden name, migration, and once-per-run behavior in both languages.
- The new `vehicle_traffic_index.gd` caches ordered lane buckets per owner/frame. Spawn, removal, reset, and lane changes invalidate it. Collision rectangles cache by geometry inputs so same-frame movement/scale/texture changes can refresh them.
- `tests/run_refactor_checks.py` and the Godot regression scene are untracked parts of this work and must be preserved with their dependencies.

The next request was to clean up code and put related functions in their respective files. The organization below reflects that refactor; story content and saved IDs/section indices were preserved.

## Function ownership after cleanup

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

# Existing isolated regression suite (requires imported assets).
python tests/run_refactor_checks.py --godot $godotConsole

# Fixture-copy safety and stale-source checks (no Godot dependency).
python -m unittest discover -s tests -p test_refactor_runner.py -v

# Check whitespace and inspect the working-tree status.
git diff --check
git status --short
```

On a fresh checkout, import assets with the Godot editor before running regressions. The runner replaces the mirrored scripts, scenes, assets, and tests in `.godot/refactor_checks/` so stale deleted sources cannot mask broken imports. It checks resolved destination paths before removal, including fixture-root aliases. It preserves the import cache and fixture `test_user/`, redirects `user://` paths there, and instruments save counts in the copy. It uses headless GL compatibility rendering and a 90-second subprocess timeout. Success requires exit code 0, no unexpected engine/script errors, and `PASS: all refactor regression checks`. Output is buffered until the Godot process exits.

Covered checks: registered payloads in both languages and English fallbacks, schema normalization/legacy adaptation/jump bounds, catalog identity and live progress, Jessa first-ride routing/migration, traffic lane order/membership, same-frame collision cache invalidation, following, one-save-per-step behavior, real save/load, branch-correct presentation, interrupted actions, and authored Elena/Jessa resumes. Cleanup coverage also exercises seeded-rule copy/mutation behavior, one-time payout batching, real menu/home/store/selection scenes, tutorial completion, shop purchases, locked passenger offers across distances, and driving initialization/traffic/hit visuals in normal, busy, and speeders profiles. Warning playback is enabled after fixing the active-buffer error; accelerated driving still does not verify real-time Tween/audio timing.

For changed behavior beyond those checks, use a disposable save and test the relevant branches: traffic at low FPS and lane transitions; economy across all phases and debt collection; stories in both languages, reward-line reload, and gallery replay; UI at the reference resolution and another aspect ratio. Headless checks do not establish visual/audio quality or export readiness.

## Validation at handoff

After the 24 October 2026 bug-fix pass, the expanded isolated runner exited 0 with `PASS: all refactor regression checks`, including all four focused bug-check modules, 20 localized payload builds, and the earlier scene/checkpoint/traffic coverage. The suite now also checks cached-save refresh, failed replacement cleanup, debt rollover, entry-save batching, real warning audio, independent runtime-texture hitboxes, competing speeders, response routing, and replay preservation of live checkpoints. Three Python runner tests passed for stale-source removal, wrong destinations, and fixture-root aliases. Godot still logged the pre-existing `Failed to read the root certificate store` and ObjectDB leak warning at exit. No interactive playtest or export was performed.

Documentation links, source whitespace, literal preload paths, and script UID presence/uniqueness were checked. The original context-only setup added `AGENTS.md` and this file; the subsequent cleanup reorganizes the modules listed above and expands the existing regression suite. Generated tooling/test artifacts stay under ignored `.godot/`. Existing gameplay/story edits were preserved.

The root `AGENTS.md` follows the [official Codex repository-guidance convention](https://learn.chatgpt.com/docs/customization/overview). Model selection remains a client setting; no model or global configuration was changed.
