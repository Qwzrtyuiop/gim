# Gulong project context

Prepared for GPT Sol on 24 October 2026 (Australia/Perth). This is repository context, usable across Sol versions; it does not select a model in the client. Source files and current Git status take precedence over this snapshot.

## Quick orientation

- Church map clicks during night/midnight now show John's "It's closed." textbox and keep the player on the map. Closed attempts advertise/spend no energy, grant no stress relief and consume no visit; daytime prayer behavior is unchanged. Source/diff reviewed; no runtime checks requested.

- North-map Pier now opens `locations/pier.png` in morning/noon and `piernight.png` at night/midnight, replacing its cropped-map placeholder. Both use outdoor `pierrain.png` for splash placement while falling rain covers the scene. Existing free travel, north-road gate and MAP navigation remain. Source/diff reviewed; no runtime checks requested.

- New-day title cards now reveal remaining debt and "Collection in Y Days" beneath DAY X, with nonlooping `drum.mp3` registered as SFX on the debt fade. Sleep/recovery prepares the reached date's collection before rendering its balance and keeps the captured target day for the title; the existing ding still accompanies DAY X. Day 1's first ride now reaches the existing initial title-card scene (the former rollover-and-target<=1 condition was unreachable). Source/diff reviewed; no runtime checks requested.

- Garage tricycle repair sessions use the new wrench/slider/target art: clicking the tricycle asks "Spend 1 energy to attempt repairs?" with YES/NO; energy is charged only on YES. One energy pays for up to three timing clicks, each success restores one hull point, and the target moves between clicks. The UI uses a charcoal steel workshop frame with warm brass edges, stepped corners, rivets and an inset wrench surface over an 85%-opaque dark backdrop; `home/garage_repair_frame.gd` owns its decoration. Hit/miss feedback floats away, with a small screen shake on either result. Full condition and insufficient energy are rejected before payment; sessions end early at full hull. `home/garage_repair_overlay.gd` owns timing/presentation, `home/garage_tricycle_hotspot.gd` traces the authored selector for both lighting phases, and HomeMap coordinates entry/navigation. Escape pauses motion and feedback; saving waits until the session is closed, while paid energy and earned hull use existing PlayerState persistence. No phase, gas or stress change. Source/diff reviewed; no runtime tests requested.

- Home's original bottom-right floor selector now opens the garage directly through the existing HomeMap location view. The `garage` action shares one normalized polygon across day/night; `garagenormal.png` / `garagenight.png` use `garagerain_indoor.png`, and BACK returns to Home while MAP opens normal travel. Entering spends no energy and advances no time. Source/diff reviewed; no runtime checks requested.

- Editor compiler-warning cleanup on 29 October: fresh language-server diagnostics for all 316 production scripts report zero errors/warnings. Fixed shadowed imports/locals, unused parameters, incompatible ternaries, enum assignments and static calls; three signals emitted by domain helpers have narrow documented unused-signal annotations. Isolated `scene_modules`, `state_ownership`, `story_game_effects`, `hub_music` and `save_slot` pass together (6.7 seconds Godot / 8.0 total). Save-slot fixtures now finish their intro fade and release shared audio before teardown; rainy-night music fixtures explicitly seed the reached phase. No leaked resources remain in that run. Only the existing certificate-store diagnostic and expected invalid-input test warnings remain. No full suite or real-player save mutation.

- Godot runtime-log review on 29 October found one distinct error repeated 6,647 times: ordinary driving looked up missing `alma_delivery_equipment` metadata. `AlmaDeliveryEquipment.for_owner()` now checks host validity and `has_meta()` before reading it. Isolated `horn` and `driving_modules` checks passed (5.0 seconds Godot / 7.2 total), with no script/gameplay errors; existing certificate-store and ObjectDB test-exit diagnostics remain. Real save files and historical logs were preserved.

- Benny's reserved drinking evening now queues `benny_tropa_night` when John reaches Home at Night, including noon rest and returning through the map. `home/benny_evening_encounter.gd` matches/consumes only Benny's existing saved trigger and uses normal VN checkpoints. It spends the evening through `night_phase_consumed_day`, returns Home at Midnight and leaves other day-end stories for actual Sleep. Existing pending invitations can trigger without waiting until the following morning. Story IDs, section indices, choices and reward actions are unchanged. Source/diff reviewed; no tests requested.

- Generic passenger gameplay profiles now have independent station appearances. `ride_selection/generic_passenger_appearance.gd` assigns available authored spots and alternate poses once per locked lineup, storing `generic_spawn_slot` and `generic_spawn_alternate` in each offer. Named spots remain reserved; crop geometry and alternate opacity stay with their authored artwork. Existing saved offers gain missing appearance fields when opened, and ordinary refreshes preserve them. Market already stores its independently assigned generic spot in `pickup_variant`. Generic IDs, schedules, trip traits, fares and random-event eligibility remain unchanged; nested offer dictionaries provide persistence without a save-version change. Source/diff reviewed; no regression run requested.

- Alma's `alma_special_delivery` now begins from her Bar sprite at bond 2 after `alma_first_encounter_seen`, during an unspent Night. Her hub sprite locks to its idle pose while eligible; the character click starts the inline VN instead of routine speech. Both initial choices lead to a Long/Night/Busy scripted ride with Rush passenger rules and double base fare, using `alma_drive.mp3`. The drink relieves 10 stress; the active stage owns a saved 10-point hull-damage buffer. `game/alma_delivery_equipment.gd` supplies the one-time truck-horn tutorial and Q equipment: nonlooping `truck_horn.mp3`, a 5-second cooldown, and guaranteed collision-free pullovers for every currently visible vehicle until passed. Cooldown/tutorial/yield state survives live slots; normal Q behavior remains unchanged elsewhere. Successful special-stage completion claims the fare once and queues `alma_special_delivery_success`, then returns to the Bar interior at Midnight without another travel cost. Only initial Accept grants `alma_bar_discount_unlocked`; all Bar liquor labels/affordability/payment share rounded 10%-off pricing. Refuse still delivers but has no discount; fatal hull failure follows normal repairs and cannot grant success rewards. Started/completed flags restore ordinary Bar interactions after the event. New fields live in existing event/active-stage/live-runtime dictionaries, covered by normal codec/reset behavior without a version bump. English scenes and aligned Tagalog placeholders are registered; BigHorn appears at its story beat. New assets were imported; source/diff reviewed, no regression suite or manual gameplay/audio test requested for this addition.

- Alma's existing bond-2 after-ride placeholder is now the authored `alma_first_encounter` / Small World scene. It uses completed-ride Street Day/Night art, branches on saved `bar_visited`, reveals her name at her introduction (`alma_name_revealed`) and completes with the existing seen flag. Successful Bar arrivals record visit history; cancelled, closed and unaffordable attempts do not. Version-5 saves with dated `alma_bar_visit_absence` history migrate that visit flag, while completed older placeholder events remain valid name-unlock evidence through optional character metadata. Legacy completion section 1 is retained; English/Tagalog branches/actions align with intentional translation placeholders. Normal fare/result return is unchanged and no flyer item is granted. Source/diff reviewed only; no regression run requested for this story addition.

- Latest validation, 28 October: the expanded full isolated Godot suite passed in 171.9 seconds (173.5 total), including 106 localized payloads and new `construction_work`, `location_visit`, `achievement_reward`, `generic_passenger_event` and `local_hub_audio` targets. All six Python fixture/runner tests passed. Construction coverage verifies fixed Tropa-at-unlock pay, once-only cash/bond/energy/phase updates, pending receipt ownership and reloads, story-locked Benny bond gains without reopening his route, and WORKING/complete/choice geometry at 1280x720 and 640x360. Visit coverage verifies both Park and Church's real inline slot saves/resumes, independent daily claims, hidden counters, ordered/random scenes and Makadiyos relief. Replacement Benny crop/mask/placement and local ambience ownership passed. Fixed fresh work receipts aliasing saved state and work bond being silently blocked by Benny's narrative lock; updated map/midnight fixtures for current phase, daily visits, new VN overlays and free/blocked destinations. The source audit found no missing literal resources, missing script UIDs or duplicate script UIDs across 307 scripts / 960 references. Final whitespace checks passed. Only the existing certificate-store diagnostic, expected invalid-input warnings and ObjectDB exit warning remain; no unexpected script/engine errors. All gameplay tests used disposable saves; no export or manual visual/audio playtest was performed.

- Construction work now captures `event_values.construction_work_pay` on the introduction's unlock step: PhP 750 when Tropa is already earned, otherwise PhP 500. Conditional snapshot actions retain the original unlock action at index 0 and refuse to overwrite an existing rate. Future Tropa unlocks do not change it; prompt, actual payment and receipt use `PlayerState.get_construction_work_pay()`. Older already-unlocked jobs lacking the historical snapshot preserve the former PhP 750 agreement; pending work receipts preserve their existing payment. Each new work transaction also grants Benny +1 bond through the normal progress API, batched with pay/energy/phase and guarded by the daily claim/pending receipt. Existing event-value and bond fields provide save/reset compatibility without a schema change. Source/diff reviewed; tests not run.

- Park arrivals now use the same inline VN/checkpoint/return flow as Church: five sequential visit scenes, then five uniformly randomized short variants, with day/night Park backgrounds and aligned Tagalog placeholders. Park still costs 1 energy and relieves up to 2 stress. Park and Church are each limited to one paid visit per calendar day; `state/player_location_visit_state.gd` batches hidden per-location counters and dated claims under existing event values. Later attempts show John's come-back-tomorrow textbox and spend no energy, grant no relief and advance no visit dialogue. Map hover/cursor information reflects exhausted visits; reopening the current location and VN save/resume returns do not count again. Midnight retains the same day's claims. The existing version-5 ledger codec/reset covers new saves, old-save defaults and new-run clearing. Source/diff reviewed; tests not run.

- Paid Church arrivals now play inline prayer VNs: five sequential authored scenes followed by a uniform random selection of five short variants on visits 6+. `home/church_prayer_encounter.gd` increments the existing hidden visit count and selects the story, while the normal pending payload/checkpoint preserves that selection across VN saves. Current-location reopens and story returns do not count, spend energy or repeat stress relief. Finishing the fifth prayer unlocks `makadiyos` (Makadiyos / Religious), with the same final action on later short prayers to credit older saves already beyond five visits. Normal action cursors suppress repeated awards and memory replays suppress persistent effects. Makadiyos increases future Church visit stress relief from 2 to 3, with the same earned-bonus getter used by live recovery and map hover/cursor information. All prayer narration is authored in English with aligned Tagalog placeholders; visible chapter titles do not expose visit numbers. Source/diff reviewed; tests not run.

- Church now opens its authored interior (`assets/story/backgrounds/churchday.png`) from the existing north-map destination. Each distinct successful arrival costs the standard 1 travel energy, relieves up to 2 stress (3 with Makadiyos) and increments hidden per-run `event_values.church_visit_count` in one state batch; current-location reopens, cancelled travel and insufficient-energy attempts grant nothing. The existing ledger codec/reset preserves slots, defaults older saves to zero and clears the count for new runs without a version change. Church shares Park's stress-benefit hover cursor; its indoor rain is muffled, with no interior falling rain until a mask is authored. The supplied day artwork is used in all phases for now. Source/diff reviewed; tests not run.

- Construction Site now uses `constructionday/night.png`, the authored full-canvas Benny spawn, `constructionrain.png` and local construction ambience. Clicking Benny plays the once-only `benny_construction_introduction`; Tapat without Sinungaling uses the honest branch, otherwise John denies the debt. Both unlock construction work and remove the site's later travel-energy cost. Subsequent clicks use an inline, saveable VN Yes/No prompt; work costs 2 energy, pays PhP 750, consumes one phase and is limited to once per calendar day. Night work consumes the evening into Midnight; work is blocked at Midnight. `state/player_construction_state.gd` batches the dated claim, money, energy, phase and pending presentation receipt in existing event values, avoiding a save-version change. The repair-derived `construction_work_overlay` animates WORKING dots before Continue. `home/hub_story_overlay.gd` reuses VN checkpoints; standalone slot resumes restore the map/site through Home without another travel charge or payment. Entering Map on Day 8 or later gives a once-only John announcement about the road north, including older saves that missed Day 8. Tagalog uses aligned translation placeholders. Source reviewed only; no regression run or manual playtest requested.

Gulong is a single-player, Philippine-set 2D side-scrolling driving game. John Toda takes passenger trips to earn fares while managing fuel, energy, stress, tricycle hull, upgrades, karma, and PHP 50,000 debt. Encounters lead into branching visual-novel scenes and character progression. The normal loop is menu/new-run intro -> passenger selection -> driving -> eligible story -> results -> another ride, store, or sleep/home. Day phases are morning, noon, and night; debt collection occurs on Days 8, 15, 22, and so on.

- Latest validation, 28 October: the full isolated Godot suite passed after the energy cap changed to 5 (152.3 seconds Godot, 153.6 total), including 38 localized payloads. All six Python fixture/runner tests passed. Added controls/tutorial and mixed-food regressions; fixed an unbuilt tutorial highlight access, a passenger tutorial callback surviving scene exit, and held rehearsal controls carrying into driving. Existing version-5 and legacy saves clamp energy to 5 without altering saved stress/hull or legacy stress ratios. Six rendered tutorial captures were reviewed at 1280x720 and 640x360. Asset references, UID uniqueness and final whitespace checks passed. Expected rejection warnings and the existing ObjectDB exit warning remain; no export or manual audio/balance playtest was performed. All runtime work used disposable fixture saves.
- Passenger pickup now shares one locked 2-to-9-offer pool across Station/Terminal, Market and Street. The new Street map guide rectangle is `(531, 514, 398, 152)` and all three pickup locations cost zero travel energy. Map clicks on Market/Street open the existing selection scene at that location; MAP/Escape returns to the shared town map. Distance/slot indexes and ordinary ride confirmation/departure remain unchanged. Each saved character dictionary stores `pickup_location` and one `pickup_variant`, while pending selection stores the active pickup location; the existing nested-dictionary codec preserves these without a save-version change. Named IDs remain unique across all three areas, with one of each authored Hana/Celina/Jessa street pose selected. Street residents Hana/Celina/Jessa/Isidro have 75% street assignment in morning and 40% at noon; Benny/Elena have 20% market assignment in morning and 70% at noon. Up to three generics use the market silhouettes (30% morning / 55% noon), with all others staying at the station. New-area passengers are daytime only; night offers and Gardo midnight encounters stay at the station. Hana now supports noon, and Jessa supports daytime after her intro while retaining intro, same-day and phase-absence gates. `passenger_pickup_assignment.gd` owns stable distribution; `passenger_area_spawn_catalog.gd` and extraction-tool layouts own the exact market/street placements. Pickup validation on 28 October passed 17 affected targets in 61.2 seconds Godot (62.3 total), including the new `passenger_pickup` checks, real map navigation, energy, confirmations/stories, schedules/absence, midnight, save slots and scene modules. Market/street extraction checks also verified all 12 crops and authored positions. Corrected a test-helper type inference error and its overly opaque-body assumption for translucent market silhouettes; production hit thresholds were unchanged. No unexpected engine/script errors remained; existing certificate-store and ObjectDB exit diagnostics remain. The latest full-suite entry predates this feature; no full-suite repeat, export or manual gameplay/audio assessment was performed.
- Street art now uses `passengerstreetday.png` in morning/noon, `passengerstreetnight.png` at night and `passengerstreetmidnight.png` during Midnight. The shared area catalog, renderer, map catalog and save previews follow these variants; legacy saved data/slot metadata redirect the former `passengerstreet.png` path to the day asset without rewriting slot files. All three images were imported and the source/diff reviewed; the preceding 17-target run predates this small art update, with no new regression run requested.
- Pickup/station background music now selects `music/driving/night_station.mp3` during live night with rain or heavy rain, replacing `normalstage1.mp3`. The new track loops through a local stream copy, remains on the Music category and uses the existing rain ducking. Repeated refreshes keep the same playback; midnight silence, bar ownership and AFK shuffle retain priority. The AFK shuffle pool contains jazz, midnight and midnight2, with no immediate repeats. The asset was imported and source/diff reviewed without a regression run or listening check.
- Hub music now belongs to the persistent `audio/hub_music_manager.gd` autoload. Home, Store and pickup screens expose aliases to its single Music player instead of creating scene-owned players. Matching tracks retain the same stream/playback through map-driven scene changes; switching themes or temporarily yielding to the bar remembers each track position for resumption. Home interiors use peace and outdoor/map/food views use normalstage1; rainy-night background music takes priority throughout the hubs. The old store track is selected only inside the mechanic shop when no rainy-night override applies. Midnight and AFK/bar ownership remain gated. Successful slot loads and departures to non-hub scenes clear cached positions; ordinary hub travel does not. Music remains pausable and weather-ducked, without adding persisted state. Updated ambient continuity coverage and added the `hub_music` target, registered in the full suite. This change was source/diff reviewed only; no regression run or listening check was requested.
- Bar interiors now expose a SHOP button at night and midnight. `store/bar_shop.gd` presents Alma's `characters/almashop.png` portrait alongside the shared shop item rows, live money/stress and a close button; it scales as a single modal at smaller resolutions. `GameTuning.BAR_ITEMS` contains Beer (PhP 120 / up to 3 stress), Rum (PhP 220 / up to 6) and Whiskey (PhP 350 / up to 10), consumed immediately without energy recovery. The shared purchase helper checks affordability, clamps actual relief and batches payment/recovery/purchase counting into one save. Food and liquor can still be purchased at full energy or zero stress; gas and repairs remain blocked when full. Liquor is exclusive to the bar; the food/mechanic midnight closure remains intact. Escape/backdrop closes the shop before leaving the bar, with navigation/NPC input disabled behind it. Bar music, ambience and indoor rain continue throughout shopping. No new persisted fields are added. Source/diff reviewed; no regression run or visual playtest was requested for this addition.
- Location navigation now uses a horizontal bottom-left row through `DashboardTheme.layout_button_row`: the bar reads MAP / SHOP / OUTSIDE, other destination views show their available actions in that order, and passenger selection places MAP beside STORE. The row scales whole buttons together on narrow screens, keeps keyboard/Tab order aligned with the visual order, and leaves trip previews/status clear of the buttons. Home, Store and the station front each have a bottom-left MAP button. Direct HOME navigation buttons are removed; Home is selected from the map. Source/diff reviewed without a regression run or visual playtest.
- MAP is available on every location screen, including Store, the station front and every pickup area. Store embeds the same HomeMap with origin `store`, so Back/Escape returns to Store and destinations preserve current offers/time; its former left Home hotspot opens Map. Store tutorial copy follows that route. Station retains the legacy `station_back_button` field as a MAP control, independent of direct-back restrictions, and passenger MAP buttons close the picker before opening navigation. Mandatory tutorials, confirmations and shop overlays keep their input gates. Source/diff reviewed only; no regression run requested.
- Hospital is now locked by default in the shared map catalog and HomeMap travel guard. Completing Celina's "Just a Scratch" (`celina_first_encounter_seen`, either branch/language or legacy completion) unlocks normal paid access; gallery replay does not unlock it. Each distinct paid Park arrival relieves up to `GameTuning.PARK_STRESS_RELIEF` (2) stress while spending the existing 1 energy in one state batch. Cancelled/blocked trips and free reopening of the current Park give no relief. Park's hover cursor shows `+2` beside the brain icon alongside the energy cost, with the benefit repeated in location text. Existing map/travel regressions cover the new gate, actual relief, no repeated free recovery, clamping and single-save behavior; source/diff reviewed, tests not run for this change.
- Daily character stress relief is handled by `PlayerState.relieve_character_interaction(location_id, character_id)` through `state/player_resource_state.gd`. A successful click grants 1 stress relief once per location per day (`hospital`, `bar`, `park`), storing location dates in existing `event_values.daily_character_stress_relief` in the same batch as recovery. Reset/save/load already cover event values; no schema change is needed. Calm clicks do not consume the claim, midnight shares the day, and the regular speech/voice remains intact. HomeMap connects visible Celina/Alma/Benny interactions with live-location/modal checks; decorative hospital crowd is not interactive. Park has no authored character sprites currently, so `_on_park_character_interacted`/`park_character_interacted` provide the future hook without adding placeholder NPCs. The optional scope/park-placement questions default to once per location and future Park art unless the user steers otherwise. Source/diff reviewed; no tests run.
- Alma cycles seven default bar-click lines, adding two familiar greetings at bond 2+. User-closing her shop with CLOSE/Escape/backdrop cycles a separate seven-line pool using her normal local voice. Navigation/forced closes do not play or advance those closing lines, and shop-closing speech does not trigger character-interaction stress relief. The cursors are scene-local and do not add save fields. Source/diff reviewed without a regression run.
- Celina's local hospital introduction (`celina_hospital_introduction`, A Familiar Face) starts on her hospital sprite after `celina_first_encounter_seen` (the bandage/Just a Scratch event), without an additional bond requirement. It reveals her name and completes with `celina_hospital_introduction_seen` / `celina_hospital_shop_unlocked`; Tagalog sections remain aligned "to be translated" placeholders. `home/hospital_encounter.gd` preserves the hospital return across VN saves without charging travel twice. Subsequent clicks open the `celinashop.png` medicine modal. The shared `store/location_shop.gd` now supplies bar/hospital layout and input; `GameTuning.HOSPITAL_ITEMS` defines first aid (PhP 150, +1 energy / -3 stress, once per calendar day) and beta blockers (PhP 180, 3 points of nonstacking next-ride stress protection). `state/player_stress_shield_state.gd` activates protection before ride-entry stress and expires remaining active points on completion/failure/retry/abandonment. A yellow border surrounds the brain icon while protection remains. First-aid claims, pending/active shield and story return use existing event values, covered by version-5 reset/save/load without a schema change. Source/diff reviewed; no regression run or visual playtest requested.
- Locked Hospital map clicks now show John's pointerless "I don't really have a reason to go there.." textbox through the same local dialogue helper as the closed bar. Hover only displays the Hospital label; travel stays gated and costs no energy until Celina's bandage event is complete. Source/diff reviewed; no tests run.
- Stress driving penalties are doubled while retaining linear 0-to-10 scaling: at 10, top speed -40%, acceleration -50%, braking -30%, lane responsiveness -60%, coasting deceleration +40% and vehicle wiggle +60%. Ride stress gain remains 2, maximum stress remains playable, and existing shared tuning/live refresh applies the new balance. Source/diff reviewed; no tests run for this tuning change.
- Nighttime now has no default background music at home, maps, pickups or ordinary shops. Every ride plays its traffic-appropriate driving music in all phases, including night. Other explicit exceptions remain: rainy-night hub `night_station`, mechanic-shop theme, bar interior music, authored story cues and the midnight passenger-screen AFK shuffle. Leaving an exception returns to silence during a clear night; shared rain/night ambience and location SFX continue. Default driving music also cannot carry into nighttime results, including older saved carry data. Day/noon themes retain their shared playback/resumption. Existing audio assertions were updated; source/diff reviewed without a regression run or listening check.
- Returning to the station on Day 1 Noon after a completed Day 1 morning ride now starts `ride_selection/map_tutorial.gd` before reopening passengers. It waits for the tricycle click/Enter, opens the real map, then highlights Station/Market/Street pickups and Park's tuned stress relief/energy cost before explaining future unlocks and closing with a farewell. Travel is disabled during the explanations; completion leaves the map open and usable. The existing event ledger stores `tutorial_first_ride_map_complete` only after finishing, so unfinished saves can restart the walkthrough without spending resources or advancing time. Later dates/phases and failed rides do not trigger it. Source/diff reviewed; no tests or visual playtest requested.
- Successful Bar/Hospital arrivals remove Alma/Celina respectively from the current phase's passenger offers. HomeMap records dated `alma_bar_visit_absence` / `celina_hospital_visit_absence` entries in the existing event ledger, batched with paid arrival; closed, locked, cancelled or unaffordable trips do not remove anyone. Their catalog `phase_absence_event` fields reuse live availability for random, seeded and saved offers across all pickup areas, and the station refreshes offers after closing its embedded map without rerolling them. Later phases restore normal eligibility, while saves preserve the current absence. Source/diff reviewed; no tests run.
- Crash repairs now quote 4 hull at the shared normal mechanic rate (`HULL_REPAIR_COST_PER_POINT`, PhP 50), costing PhP 200. If that full bill is unaffordable, the player keeps all cash and receives only a free 1-hull emergency patch. Normal shop repairs still offer 2 hull for PhP 100. Pending repair dictionaries persist `hull_restore` / `free_repair` alongside their fixed bill; recovery and payment remain once-only, with the existing overnight rest/debt flow. Older pending quotes without the new amount keep their already-paid full-hull recovery. The repair screen reports the actual amount and explains free patches. Existing repair expectations were updated; source/diff reviewed, no tests run.
- Hospital dialogue now uses `home/celina_hospital_dialogue.gd`: a private-RNG shuffle cycles seven default greetings, adding two John-specific lines only after Celina's introduction and at bond 2+. Celina clicks speak locally; the hospital's separate SHOP button opens medicine after the introduction unlock. Clicking and shop openings share the greeting bag, and shop greetings anchor to the `celinashop` portrait with Celina's voice. User-closing the shop speaks one of six closing lines at her hospital sprite; forced navigation closes remain silent. Only actual character interaction uses the existing once-per-day hospital stress relief, so shop greetings/closing cannot consume or repeat it. Dialogue cursors remain scene-local. Source/diff reviewed; no tests run.
- Achievement rewards now add Bayanihan +5% fares (stacking additively with Malasakit to +10%), Masipag +1 maximum energy, and Maparaan/Matiyaga/Maingat +2 maximum stress each. Base energy/stress caps remain 5/10, reaching 6/16 with all capacity achievements. Caps derive from earned IDs rather than accumulated increments; unlocks retain current values, loading restores achievements before clamping resources, old saves receive already-earned rewards, and new-run reset clears rewards before restoring base resources. Stress penalties scale against the earned maximum, with the same full-cap penalties and fixed achievement thresholds. Sleep fills/displays the current energy cap. Ride-entry stress is now 1; existing trip cards/tutorials use the tuning constant. Existing version-5 fields support this without a schema change. Source/diff reviewed; no tests run.
- Ten repeatable generic-passenger end-of-ride stories now live in `story/payloads/events/generic/`, with aligned Tagalog placeholders and catalog/Memory entries. They follow the existing random-event unlock (Day 3+, Day 2 bill completed), below scheduled/character stories, the due repayment epilogue and selected Malasakit/Bayanihan stories. A tunable 25% fallback roll chooses uniformly among eligible scenes; Quiet Ride requires no crashes, Keep the Change no overtime, and Extra Tip a morning/noon completed ride. The result records `had_crash` before ride flags reset; its existing random-event selection fields prevent rerolls, while fresh occurrences reset only the new scene's section cursor. Final persistent reward actions add the supplied tip/stress relief once through normal checkpoints and are suppressed in Memories. No save-version change. Hospital/Bar NPC talking now relieves 2 stress once per location/day, with the future Park hook staying at 1. Source/diff reviewed; no tests run.
- Engine: Godot 4.6; installed editor/console: 4.6.2.
- Rendering: Forward Plus, Windows D3D12; viewport 1280x720, `canvas_items` stretch.
- Entry: `res://scenes/main_menu.tscn` in [project.godot](../project.godot).
- Autoload order: InputBindings, AudioSettingsManager, StoryLanguageManager, PlayerState, SaveSlotManager, AmbientAudioManager, HubMusicManager, AchievementPopupManager, PauseMenuManager, UIAudioManager.
- Saves: ten scrollable notebook slots in `user://saves/slot_01.tres` through `slot_10.tres`. Slot 1 autosaves once on arrival at each new day; slots 2–10 are manual saves from Escape → Save. Escape → Load and the main-menu Load Game open the same selector. The notebook frame presents a scrollable slot list on its left page and a larger preview/day/location/time on the right; the scrollbar stays hidden. Start Ride always resets the live run and begins the intro on Day 1, preserving the saved slots. The version-5 codec owns energy/stress/hull progress data and migrates earlier saves; optional resource metadata holds time, location, thumbnail and live driving state. `user://progress_save.tres` remains an internal recovery checkpoint and migrates into Slot 2 when no slots exist. Language/audio preferences remain separate.
- Energy caps at 5; stress and hull each cap at 10. Energy starts at 5 and pays 1 per ride/attempt or distinct paid map destination; Home/Store/Station (including Market gateway), map-region navigation, menus, purchases and crashes are free. Stress starts at 0, adds 2 at ride entry, and progressively worsens speed/controls while maximum stress remains playable. Hull starts at 10; collisions add stress and damage hull, with zero hull going directly to repairs before passenger events. Rest restores 2 energy/reduces stress by 2; sleep fills energy to 5/reduces stress by 4 without repairing hull. Food reduces stress and the mechanic sells partial hull repairs. Existing saves clamp energy to 5 on load while preserving stress/hull and legacy stress conversion. See [resource rules and APIs](PLAYER_RESOURCES.md). UI headers/HUD show all five money/energy/stress/hull/fuel values, with a generated brain icon for stress. Old energy gameplay modifiers are removed; live-save factors avoid stacking stress penalties.
- Hub status uses `ui/hub_status_header.gd`: a full-width, 44-pixel, semitransparent black top bar with money, centered day/phase and energy/stress/hull/gas on one line. Resource signals refresh it, compact typography fits narrow screens, and all children ignore input. The ID-card implementation/UID now live in `scripts/archive/ui/player_id_card.gd`; both card artworks/import metadata are preserved in `assets/archive/ui/id_card/`. No live scene loads the archived card or reserves its bottom corner. Passenger selection and shared hover/confirmation cards retain tuned per-ride energy/stress costs; encounter-only offers omit them. Routine hover/click/no-passenger prompts are removed, while actionable errors remain in a bottom status strip. Store owner panels use the full height below the status bar. Driving keeps its compact footer/lowered gauge and day/stage/weekly goal panel without the debt-remaining text; results retain receipt stats. Status-header and driving-HUD geometry, values and input transparency passed the full isolated suite; tutorial captures were visually checked at 1280x720 and 640x360.
- Controls: W/Up and S/Down change lanes, D/Right accelerates, A/Left brakes, Shift boosts, Q holds the horn (repeat taps can persuade bottom-lane traffic), Escape pauses in supported scenes. Main-menu hold-R resets progress.
- `scripts/input_bindings.gd` adds physical WASD aliases to Godot's shared directional actions, retaining default arrow/gamepad bindings and enabling menu navigation on the same keys. Driving retains logical-letter fallbacks; tutorial content is unchanged.
- Driving has hidden per-ride `top_lane_pressure` (0..1). Logical lane 0 fills it in 8 seconds; other lanes drain it over 90 seconds. The scheduler gradually accelerates only the top-lane spawn clock up to 6x, preserving warning cadence and existing clearance/gap checks. It freezes outside active driving, resets on fresh rides/retries, and survives live driving save/load; older runtime saves default to zero. Tuning lives in `config/game_tuning.gd`; `top_lane_pressure` passed in the full isolated suite on 27 October.
- Incoming traffic now rolls groups of 1–4 vehicles after each advance warning. Followers queue offscreen with 120–220-pixel visible bumper gaps, retain normal clearance/following rules, and save as ordinary traffic entities. Incoming cars are no longer culled merely for being beyond the right edge while awaiting entry. Pressure still controls group frequency; other lanes keep single-vehicle spawns. Non-Chill incoming base delays were subsequently eased to 15–24 seconds for Normal/Traffic Jam, 7.2–12 for Busy and 13–21 for Speeders, before the existing speed/day/pressure modifiers; Chill stays at 22–34. This balance adjustment has not been playtested. Group count/gap tuning lives beside oncoming settings in `config/game_tuning.gd`; `incoming_group` covers all sizes, spacing, warning cadence, queued entry and save/load and passed in the full suite on 27 October before this adjustment.
- The Escape menu uses `ui/frames/notebookclosed.png`, cropped to the visible cover with controls kept clear of the binder. Save/Load open the matching two-page notebook selector.
- The notebook right page has DELETE SAVE for the selected occupied slot, including autosave and damaged files, with Cancel-focused confirmation in both pause and main-menu Load. Deletion leaves live/recovery progress intact, removes only that slot's generated previews, and records `user://saves/.legacy_migration_complete` to prevent recovery reimport after all slots are deleted. Empty slots disable deletion; Slot 1 remains deleted until the next normal daily autosave. Overwrite cleanup also checks generated filenames for the current slot, preserving other slots' previews even if old metadata references them. `save_slot_deletion` passed in the full isolated suite on 27 October.
- Park and market story backgrounds have shared day/night splash markers (`parkrain.png`, `marketrain.png`). `story/story_background_weather.gd` follows the drawn background through fit/zoom/pan, reuses outdoor rain/heavy-rain rendering and tint, and reads weather without rolling or saving. Its strict marker-color mode ignores natural yellows and transparent padding; falling rain covers the scene while splashes stay inside the painted regions.
- VN scene characters can opt into per-background layouts using `speaker_placement: "background"` or a manual portrait's `placement: "background"`. `story/story_location_spawns.gd` reuses existing terminal day/night placements and holds future authored location layouts. A portrait's `background_placements` map can supply per-location cutout/sheet rectangles and sprite variants. Missing world placements hide the character instead of reusing an old scale; foreground dialogue portraits retain their fixed-height mode. See the portrait guide's location-placement workflow; new park/market/bar character sheets still need authoring.
- Terminal generics also use `terminalspawns/genericspawns2.png`: six alternate poses retain the second sheet's exact positions and sizes at existing waiting spots. A deterministic day/phase/passenger choice keeps appearances stable across reopening and loading without changing passenger IDs, counts or gameplay RNG. Regenerate both generic sets with `tools/extract_terminal_spawns.py`.
- Home travel uses the right-side MAP button; the old floor exit hotspot and Ride/Store chooser are removed. `home/home_map.gd` hosts the aspect-fitted `map/topdown_map_view.gd`; fixed source rectangles in `map/topdown_map_catalog.gd` follow `assets/map/mapguide.png` without drawing the guide. Home closes the map, Station uses the existing hub departure, and Market/Park/Bar show destination previews with Map/Home navigation; Market also opens Store. Hospital uses `hospitalday.png` for morning/noon and `hospitalnight.png` for night/midnight. The three marked road exits stay locked. Shared `travel_energy_cost()` drives both the minus-lightning cursor badge and arrival charge. Distinct paid destinations ask "Go to X? This will cost 1 energy." through `home/map_travel_confirmation.gd`; Cancel/Escape is free, GO spends once, and insufficient energy keeps John's existing tired response. Current/free/closed/locked destinations and north/south region navigation show no cost badge or paid confirmation. Travel preserves time and passenger offers; Escape returns through Map to Home before the pause menu.
- At the station, the foreground tricycle opens the shared map and the terminal building opens passenger selection. `ui/station_view.gd` uses separate day/night-shared polygons for tricycle (`map`), terminal (`passengers`) and store; the terminal has a subtle custom outline, while the tricycle/store retain their painted highlights. `HomeMap.open("station")` returns Back/Escape/Station to the existing station without rerolling offers; Home travels to the house, and paid destinations reuse normal costs/confirmation. Station input is disabled behind the map, bar music owns the interior mix, and returning restores station traffic ambience. Station navigation and shared map travel passed the full isolated suite, including actual pointer/keyboard input and resource preservation.
- Onboarding now arrives at the station front after the prologue. `ride_selection/station_tutorial.gd` highlights day, money, energy, stress, tricycle condition and gas individually, then the tricycle/map and store entrance; its last step waits for the terminal polygon click (or keyboard accept). Completing it stores `tutorial_station_complete` in existing event values and opens passengers. `selection_tutorial.gd` uses one locked offer for short, separate passenger/route/traffic/fare/fuel/risk/resource-cost highlights (plus a special-rule badge when present); the final passenger click opens normal confirmation. The existing `ride_select_tutorial_shown` flag is now set on completion. No resources, offers or clock changes occur during these explanations. Driving teaches only W/Up, S/Down, D/Right, A/Left, Shift and Q, one matching input at a time; game `_input` handles these before the focused overlay. Home/store tutorials teach local actions without repeating the resource definitions. All overlays reuse `tutorial_overlay_helper.gd`, with shorter responsive panels and viewport-clamped highlights. The full suite covers mouse/keyboard completion, resize bounds, offer/RNG/resource isolation and callback cleanup. Controls practice waits for held controls to release before gameplay resumes, keeping the next horn press and fuel use isolated from rehearsal.
- Map/destination title labels are removed. Bar visits always show `barnight.png` outside; an aspect-fitted building rectangle enters `bar.png` only during night/midnight. Day/noon entry attempts show John's pointerless "It's closed." bubble. Outside/Escape returns to the exterior before the map; entry hover/focus follows the shared pointer/keyboard mode.
- The bar interior always displays Alma through `home/bar_alma_spawn.gd`, independently of passenger offers/bond. Her authored 1672x941 placements are preserved with crops that exclude faint export remnants. Only defaults 1–3 enter the random pool; ten-second checks sometimes change pose or show her phone. After 30 unattended seconds she stays on her phone; after 120 seconds she switches to the old `almaidle2` spot, drawn above the rain. Phone hover or a click restores her last default and resets both idle thresholds. Hovering idle2 keeps her in place for clicking; clicking returns her behind the counter. Before the 30-second threshold, random phone checks last until the next ten-second check or interaction. Leaving the interior resets the visit, hidden/paused scenes freeze timers, and a private RNG leaves gameplay rolls untouched. Default4 remains unused. No runtime checks were run for this feature.
- Benny's `characters/sprites/bennybar.png` has a 30% chance to spawn on each bar entry once his bond reaches 2, using a private RNG. He stays at his authored position, using a tight atlas crop and an alpha-mask button; absent spawns are hidden and disabled. Both Benny and Alma show local, character-anchored `...` placeholder speech when clicked and expose `HomeMap.bar_character_interacted(character_id)` for future dialogue/events. Clicks respect blocking speech, stay inside the bar and do not award bond or start rides. Benny's image was imported through the headless editor; no regression run or interactive playtest was performed.
- The bar interior loops `music/story/bar.mp3` and `ambience/bar_ambience.mp3` through scene-owned `home/bar_audio.gd`. They register as Music and SFX respectively, pause with the scene, and stop on Outside/Map/Home/departure. Home music yields while the bar track is active and returns to its normal phase rules afterward. The bar track is allowed during midnight as an interior exception; rain still ducks its music, and shared rain/night players continue without restarting. No runtime checks were run for this feature.
- Hospital visits show Celina through `home/hospital_celina_spawn.gd` on both day/night backgrounds, with no bond requirement. The four `characters/sprites/celinahosp` exports preserve their authored canvas placement, with tight atlas crops excluding distant faint remnants and cached alpha click masks. Ten-second checks alternate defaults 1/2 or occasionally show Busy (25%); 30 unattended seconds selects Idle. Hover holds the current position so distant poses remain clickable; clicking returns her to reception and shows character-anchored `...` placeholder speech, exposing `HomeMap.hospital_character_interacted("cel")`. Her name follows the existing hidden-name gate. The sprite stays above indoor rain, receives background weather tint, pauses with the scene and resets on departure. No ride, bond or inventory effects are added. No regression suite or interactive playtest was run.
- Day/noon bar clicks are blocked directly on the map with John's pointerless "It's closed. I should try again later." message. Night/midnight clicks still travel normally. The map's local speech layer is shared across the map and destination views.
- `home/hospital_characters.gd` groups Celina with the decorative `celinahosp/hospitaldaycrowd.png` overlay. Morning/noon hospital visits show the full crowd; night/midnight retain only the four seated people on the left. A cropped atlas with transparent right padding preserves the original canvas size, placement and transparency. The crowd receives weather tint and draws in front of Celina/window rain without intercepting input. `home/hospital_audio.gd` loops `audio/ambience/hospital ambience.mp3` during hospital visits in all phases, registered as SFX at -8 dB. It pauses with the scene and stops on Map/Home/departure; shared weather/night audio keeps running. HomeMap coordinates both through `_set_hospital_active`. No regression suite or listening playtest was run.
- Rain masks named `_indoor.png` clip all visible rain to their painted openings. Home uses renamed `houserain_indoor.png`; story/map backgrounds use it for both house phases, `barrain_indoor.png` for the bar interior, and `hospitalrain_indoor.png` for both hospital phases. Outdoor falling rain still covers the scene with masked splashes. Shared CPU/shader strict marker detection accepts both authored lime colors while ignoring transparent padding.
- Indoor rain audio routes only the shared rain player through a 2200 Hz/12 dB low-pass bus with +3 dB gain compensation, with tuning in `audio/rain_audio_profile.gd`. The previous 1200 Hz/24 dB filter plus -6 dB attenuation made the hiss-heavy normal rain nearly inaudible; the gentler filter retains its presence. Reusing the bus reapplies current filter tuning. Home, hospital/bar interiors and open shops use it; map/outdoor views restore the ordinary rain mix. Background classification reuses the `_indoor` marker bindings. Environment changes adjust routing/volume without replacing the stream, seeking, restarting rain or affecting other audio layers. Scene entry resets the environment; the existing authored-story ambience rules remain. Existing rain-audio assertions were updated; offline source-level measurements guided the mix, but no Godot regression or listening playtest was run for this adjustment.
- The top-down map also shows current rain/heavy rain and its matching tint, clipped to the fitted day/night artwork beneath the navigation UI. It reads the existing weather without rolling or saving, and keeps the shared ambient audio running.
- Town map areas follow the updated `mapguide.png`, including the northern road. Days 1–7 show John's construction/check-later message on click; Day 8 onward opens `northmap.png` / `northmapnight.png`. The marked south road and Back/Escape return to town, keeping weather, phase and resources unchanged. The day/guide north canvas is 1671px wide and night is 1672px; hit regions use normalized guide coordinates with the active artwork's fitted size.
- North guide areas now identify Pier, Basketball Court, Construction Site, School, Big Station, Church, Abandoned Building and Back to South. Until individual backgrounds are added, seven destination views crop their exact map areas using the active day/night art, with unmasked falling rain and Map/Home navigation. Map/Escape returns to the north map; the south road returns to town. The guide's unnamed flag-building box remains unassigned.

- Clickable environmental objects use visually unmarked interaction areas with no hover/focus highlights or cursor changes. The first object is the trashcan on `terminalday.png`: successive clicks show John's five pointerless lines from "It's a trashcan" through "Trash can." using the local hub dialogue. The final line repeats; leaving the station scene resets this scene-local progression. Its source rectangle follows the fitted artwork; passengers retain click priority. The hotspot is disabled on night artwork, during tutorials/confirmation and while departing.

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
| Notebook slot cards and shared visual styles | `scripts/ui/save_slot_card.gd`, `scripts/ui/save_notebook_theme.gd` |
| Map travel and bar NPC presentation | `scripts/home/home_map.gd`, `scripts/home/bar_characters.gd`, `scripts/home/bar_alma_spawn.gd` |
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

- Resource rework on 27 October: save v5 persists independent energy, stress and hull, with older-save migration and paid-entry guards. Store goods, smoking consequences, story controls/rewards, collision failure/repair, map travel and home/passenger/store/driving tutorials are aligned with the three-meter model. Added isolated `stress_hull`, `stress_ui`, `stress_travel` targets and updated affected sleep/Isidro/map/result expectations. Focused validations cover state, migration, store repairs, live handling/slots, map costs, UI/tutorials, passenger confirmation, day flow, VN effects/time/save/replay and fatal-story priority; no full suite or interactive audio/gameplay playtest was requested.
- Final resource validation: 23 focused Godot targets passed across the affected areas, including 38 localized payload builds; all six Python fixture/runner tests passed. Fixed outdated energy-warning/fatal-collision assertions to match high stress and hull failure, and verified scripted extra rides also pay entry once. Source/preload/UID and final whitespace checks passed. The existing certificate-store diagnostic and occasional ObjectDB exit warning remain; no unexpected script/engine errors remained in the successful runs. No full regression suite, export or manual listening/playtest was performed.
- Organization/optimization pass on 27 October: `home/bar_characters.gd` owns bar NPC creation, spawning, placement, speech anchors and tint; HomeMap retains travel/audio coordination and its public NPC node references. Benny's atlas/alpha mask is cached across home instances. `ui/save_slot_card.gd` owns card content; `ui/save_notebook_theme.gd` owns typography/widgets and three shared immutable button styles, removing style allocation on slot hover. `story/story_background_camera.gd` owns pan/zoom commands and fitted geometry; StoryPresentation retains forwarding APIs/constants, with camera state/tweens still on the reader for save compatibility. Rain helpers skip unchanged shader/configuration and fitted-geometry updates. Story IDs, save fields, content and traffic tuning were preserved. Final source/diff review was performed; no regression suite, runtime playtest or performance benchmark was run, following the skip-check preference.
- Celina's first encounter is now authored as "Just a Scratch", with Accept/Refuse branches after her existing completed-ride trigger at bond 2. Both endings set `celina_first_encounter_seen` and return to results without granting items or changing the normal fare. Her name stays `???` until a future `celina_name_revealed` event; the automatic ride-count reveal is disabled. Both image beats now show `items/rabbit bandaid.png` as a centered manual item portrait; it remains through the immediate reaction before automatic speaker portraits resume. Tagalog retains `to be translated` text with matching branches/actions/presentation. The old completion index 1 is retained for saved placeholder encounters. No regression run or playtest was performed for this story addition.
- Full-suite review on 27 October: final isolated Godot run passed in 136.1 seconds (137.2 total), including 38 localized payloads and new `character_progress`, `incoming_group` and `terminal_object` checks. All six Python fixture/runner tests passed. The review fixed cross-slot preview removal during save overwrite and updated rain-audio fixtures for midnight passenger-only AFK music. Bond checks confirm per-passenger gains and save/load/catalog isolation; the reported universal +1 was not reproduced. Literal preload paths, script UIDs and final diff checks passed. The existing certificate-store diagnostic and ObjectDB exit warning remain; there was no interactive driving/audio playtest or export. Combined 6x pressure and 1–4-car groups still need a gameplay balance assessment.
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
`ui/station_idle_music.gd` adds music after spending 60 seconds with the passenger
selection open at midnight. A private RNG chooses `music/story/jazz.mp3` or `midnight.mp3`
and selects a different track each time playback finishes while
leaving ambience running. Jazz's base volume is -14 dB and midnight's is 0 dB
to balance their different source levels; both use the Music category. This
idle track is an intentional exception to midnight's usual music silence.
Mouse, keyboard, touch and controller interaction do not reset the visit timer
or stop the track. Pause freezes playback
and the timer. Departure prevents a new idle track, and leaving the scene frees
the player/timer. Closing passenger selection stops the music and resets the
countdown; reopening starts a fresh 60 seconds. Header refreshes preserve the idle
session. No idle music runs on the station street, at other phases, at home or in
the store. `tests/station_idle_music_checks.gd` covers
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
gated/timed playback and the existing text-reveal/SFX helper. Floating character
speech now uses VN voice blips by default, resolving the voice from its stable
character ID or speaker name; Elena's `ely` ID resolves her existing voice profile.
Narration, punctuation-only placeholders and explicitly muted/instant lines stay
silent. Gardo's midnight lines and bar interaction text use the reveal defaults.
No regression run was performed for this voice-default change;
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
header to the current clock. Routine passenger instructions are removed;
tutorials highlight individual resources at the station and trip fields inside.
`terminal_spawn_catalog.gd` owns placements; `terminal_passenger_view.gd` owns
rendering and alpha-aware input; `selection_view.gd` gathers live eligible offers
and formats details. The old card panel and distance controls have been removed.
See [terminal passenger art and behavior](TERMINAL_PASSENGERS.md), including the
lossless extraction command. `ride_selection/station_interface.gd` owns terminal
navigation, header and back control. Closing the screen preserves offers and
the last selected distance. The first passenger tutorial starts on terminal open;
the prologue now stops at the station-front tutorial before that handoff. The
same first-ride eligibility handles older untrained station saves; later visits
use the street normally. Localized intro regression expectations cover station
onboarding, terminal clicks and the unchanged single entry cost.
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
| Story visuals, portraits, gallery capture, screen fades | `scripts/story/story_presentation.gd` |
| Background camera commands and fitted pan/zoom geometry | `scripts/story/story_background_camera.gd` |
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

On a fresh checkout, import assets with the Godot editor before running regressions. The runner refreshes mirrored scripts, scenes and tests in `.godot/refactor_checks/`; assets and imported resources copy only when size or modification time changes, with stale files removed. Copies remain independent of live sources. It checks resolved destination paths before removal, including fixture-root aliases. It preserves fixture `test_user/`, redirects `user://` paths there, and instruments save counts in the copy. It uses headless GL compatibility rendering, with a 30-second focused timeout and a 240-second full-suite timeout; `--timeout SECONDS` overrides either. The full allowance covers the expanded suite's roughly 150-second runtime without adding time to successful checks. It reports preparation and runtime separately, and focused targets report their duration. Success requires exit code 0, no unexpected engine/script errors, and the selected/full PASS marker. Godot output is buffered until the process exits.

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
