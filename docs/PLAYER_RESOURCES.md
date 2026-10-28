# Player resources

Energy ranges from 0 to 5; stress and hull range from 0 to 10. New games start at 5 energy,
0 stress and 10 hull. Fuel remains independent.

| Resource | Changes | Recovery |
| --- | --- | --- |
| Energy | -1 per new ride/attempt or distinct paid map arrival | Food +1/+2; short rest +2; sleep restores to 5 |
| Stress | +2 at ride entry; collisions add 1/2/3 | Short rest -2; sleep -4; Park arrival -2; food/cigarettes reduce it |
| Hull | Collisions remove 1/2/3 | Mechanic repairs; crash recovery restores to 10 |

Home, Station/Terminal, Market/Store and Passenger Street are free to visit. Opening the map,
navigating north/south, inspecting objects, menus, purchases, and crashes do not
consume energy. Reopening the current destination is free; returning after
visiting somewhere else costs another energy. Closed/blocked visits cost nothing.
At zero energy, paid visits/rides are blocked while Home/Store/Station remain
reachable. Scripted driving legs also pay entry once.

Each distinct Park arrival costs the usual 1 energy and relieves up to 2 stress
in one saved batch. Reopening Park from its map is free and gives no extra relief.
Its hover cursor shows the energy cost and `+2` brain recovery icon. Hospital is
locked until Celina's "Just a Scratch" event sets `celina_first_encounter_seen`;
locked clicks and direct travel attempts spend nothing.

Clicking an interactive character at Hospital, Bar or Park relieves 1 stress,
once per location per day. The usage date is stored in the existing event ledger
with the recovery in one save batch, so revisiting/loading cannot refresh it;
midnight uses the same day. Calm interactions do not consume the daily relief.
The current Hospital/Bar controls are connected; Park's hook awaits authored
character spawns and is separate from its 2-stress arrival recovery.

Stress affects driving immediately and never blocks entry by itself. Penalties
scale with stress; at 10 they are -20% top speed, -25% acceleration, -15% braking,
and -30% lane-change response, with more coasting and vehicle wiggle. Energy has
no handling modifier. Weather, upgrades and passenger/special modifiers apply
before stress. Live saves record handling factors to avoid stacking penalties.

Light collisions add 1 stress and remove 1 hull; heavy impacts use 2/2 and head-on
impacts 3/3. Heavy same-direction impacts start at 45 km/h relative speed.
Existing collision grace prevents repeated damage from a single contact.
Zero hull immediately follows the crash/repair transition, ahead of passenger
story interruptions. The existing bill/day/debt rules remain. Sleep alone never
repairs hull.

The mechanic offers 2 hull for PhP 100, or PhP 50 for the last missing point.
Food retains stable IDs and offers energy recovery, stress relief, or both.
`FOOD_MAX_ENERGY_RESTORE` caps each food purchase at 2 energy; resource caps still
limit actual recovery. Energy-restoring food costs more than stress-only food.
Food and liquor remain purchasable even at full energy or zero stress. Purchases
still charge their normal price and count normally, while recovery stays capped.
Gas and repairs remain blocked when fuel or hull is full; upgrades retain their
maximum-level limits.

| Food | Price (PhP) | Energy restored | Stress reduced |
| --- | ---: | ---: | ---: |
| Turon | 30 | 0 | 1 |
| Snack Bar | 80 | 1 | 0 |
| Lugaw | 75 | 0 | 3 |
| Pancit | 120 | 1 | 2 |
| Budget Meal | 150 | 2 | 0 |
| Lomi | 180 | 2 | 4 |

Inside the bar at night or midnight, SHOP sells Beer (PhP 120, up to 3 stress
relief), Rum (PhP 220, up to 6) and Whiskey (PhP 350, up to 10). Drinks are
consumed immediately, restore no energy and cost more per stress point than
ordinary food. Actual relief stops at zero stress, but drinks can still be bought
while calm. Unaffordable purchases do not charge money. They use the shared
batched purchase/counter/save path.

After Celina's hospital introduction, clicking her opens medicine and first aid
with the `celinashop` portrait. Basic first aid costs PhP 150, restores up to 1
energy and reduces up to 3 stress, once per calendar day (midnight shares the day).
It can still be bought at full resources, consuming that day's claim.
Beta blockers cost PhP 180 and immediately queue 3 points of stress protection for
the next ride. Protection absorbs ride-entry and collision stress, then expires
when that ride ends, fails, retries or is abandoned. Doses cannot stack. The brain
icon has a yellow border while protection remains. Existing event values persist
daily first aid and pending/active protection; new runs reset both. Tuning lives in
`GameTuning.HOSPITAL_ITEMS` / `BETA_BLOCKER_STRESS_SHIELD_POINTS`.

Smoker unlock adds 2 stress instead of reducing the fixed energy cap.

`PlayerState` owns resource values/signals/APIs; tuning and inventory live in
`scripts/config/game_tuning.gd`. Save version 5 stores all three meters. Versions
1-4 retain their old energy (clamped to 5), derive stress from the old depletion
ratio and start with full hull, except pending repairs which retain zero hull.
Version-5 saves also clamp loaded energy to 5 without changing stress or hull.
Content IDs and completed effects remain stable. Legacy energy story commands
still affect energy; new `add_stress`, `relieve_stress`, `damage_hull` and
`repair_hull` commands are suppressed during gallery replay.

UI uses the existing lightning for energy, a generated
[tricycle-and-wrench icon](../assets/ui/icons/tricycle_condition.png) with `x/10`
for integrity, and the new
[brain icon](../assets/ui/icons/stress_brain.png) for stress. The brain was made
with the built-in imagegen tool using this prompt brief: transparent pixel-art
pink brain, dark brown outline, readable at 22x22, no text, frame or lightning.
Live hubs use `ui/hub_status_header.gd`, a semitransparent black top bar with
day/phase, money and all four resource values/icons. The former ID code/UID is
archived in `scripts/archive/ui/`; its artwork is in `assets/archive/ui/id_card/`.
Driving uses a compact footer HUD, and results retain receipt statistics.
Passenger selection, hover information and confirmation show per-ride
energy/stress changes from shared tuning without routine passenger prompts.

Focused regression targets: `stress_hull`, `stress_ui`, `stress_travel`.
Use the isolated Python runner documented in [project context](PROJECT_CONTEXT.md).
