# Terminal passenger selection

Click the station tricycle to enter the terminal. All currently locked passenger
offers appear together, including short, medium and long trips. Hover or keyboard
focus shows a passenger's trip details. Clicking opens a confirmation with the
same trip summary; Confirm uses the existing story trigger and ride-entry path.
Fresh lineups roll a total from two passengers up to the nine available slots;
individual distance pools can be empty. Scripted riders reserve their places
before random filling. The opening tutorial uses two or three short-trip riders,
and low fuel keeps at least one short-trip offer. Only retained passengers are
marked seen. Reopening the terminal, visiting the store, or saving/loading keeps
the same locked lineup, including older saves with fewer passengers.
Cancel, Escape or a backdrop click returns to the same passengers without saving,
changing the selected distance, charging resources or consuming a story event.
Generic passengers use the faceless sprites from
`terminalspawns/genericspawns.png` and `genericspawns2.png` in both day and night
scenes. The second sheet supplies six alternate poses for existing waiting spots,
each retaining its own authored size and position. A stable day/phase and passenger
hash chooses between available poses; reopening or loading does not reroll them
or consume gameplay randomness. Named passengers keep their authored spots;
generics fill unused spots in a stable order. A full
nine-offer lineup can use an extra standing position at the far left. Missing
future character art still uses an empty outlined box.

Hovered or keyboard-focused passengers render once above the other passengers,
enlarged by 6% from their feet. This replaces the resting image; no offset copies
are drawn behind it. Their ground positions and clickable areas stay fixed.

Mouse input highlights only the object or passenger under the pointer. Automatic
button focus when opening or closing the terminal does not leave an outline,
enlargement or information panel visible. Tab, arrow keys and controller
navigation show keyboard focus; moving or clicking the mouse returns to pointer
hover. The same rule applies to the station tricycle and store entrance.

The terminal uses the same bordered `HubStatusHeader` as the station, including
the money label, energy and fuel icons, energy capacity and fuel percentage.
Its day/time previews the selected trip while the resource values remain live.
Passenger instructions sit below the header; closing the terminal restores the
station's current day/time display.

Trip previews use a padded card with a passenger heading, route/time, traffic,
optional Rush/Careful/Special badge and three aligned columns for estimated fare,
fuel and color-coded risk. The confirmation uses this same component. Underlying
passengers and navigation are disabled while it is open. Cancel receives initial
keyboard focus; the confirmed offer and clock are checked again before departure.

After the day's night trip ends, the clock reads **Midnight** and the terminal
opens with no passengers. The player can still visit the station and store street,
where both shops are shuttered but Home and Station exits remain available;
sleeping at home opens the next morning's offers. This also applies to failed
night trips and existing saves with a dated night result. A night reserved by a
story cannot be used for another trip either. Closed terminals preserve their
cached pools, ignore seeded riders, and reject stale confirmations or queued
passenger-story departures. The underlying story/weather phase remains `night`.
Home, store and station loop `ambience/night.mp3` during night and midnight;
opening the passenger overlay keeps the station's existing loop. Midnight stops
home/station/store music, including inside terminal and shop overlays. The
completed night ride's results omit the carried driving track while
retaining rain ambience.

During night and midnight, the station and terminal also share a continuous
`ambience/cars.mp3` loop over the night bed. Opening/closing the terminal does not
restart it. Home, store and station roll a 25% chance for dogs every five seconds;
successful rolls play one of eight 2-2.95 second bark excerpts from
`ambience/night_dogs.mp3`. The separate ambience RNG leaves passenger and traffic
randomness unchanged. All layers use SFX volume and pause together. Shared rain,
night ambience and dog cadence survive travel between home, store and station;
only station traffic and local music change with location. Rides/results reuse
the rain/night players, and menus, sleep and story scenes stop the shared mix.
Mix levels, excerpt offsets, interval and
chance live in `scripts/ui/hub_night_ambience.gd`.

After spending 60 seconds on the station or terminal screen, a random
`music/story/jazz.mp3` or `midnight.mp3` track replaces normal station music and
loops until leaving the station. Mouse movement and other interaction do not
reset the timer or stop the track. This also works at midnight.
Ambience continues beneath the idle track, and overlays do not restart the idle
clock. Pause freezes the timer and playback; leaving the station frees them.
`scripts/ui/station_idle_music.gd` owns the interval, track balance and private RNG.

## Art and positions

The empty backgrounds are `terminalday.png` and `terminalnight.png` in
`assets/story/backgrounds/locations/`. The transparent placement sheets are
`terminalspawns/dayspawns.png`, `terminalspawns/nightspawns.png`, and
`terminalspawns/genericspawns.png` / `genericspawns2.png`. All use the same
1672x941 canvas. Keep
characters separated on the transparent sheets.

The renderer uses isolated crops from those sheets to retain their exact poses,
flips, sizes, shadows and positions. The separate source sprites in
`assets/characters/sprites/` identify the characters; editing one of those source
sprites also requires updating its placement sheet to change the rendered art.

| Saved ID | Character | Source sprite | Placement sheets |
| --- | --- | --- | --- |
| `alma` | Alma | `almasprite.png` | Day, night |
| `benny` | Benny | `bennysprite.png` | Day |
| `cel` | Celina | `celiasprite.png` | Day, night |
| `dante` | Dante | `dantesprite.png` | Night |
| `ely` | Elena | `elenasprite.png` | Day |
| `faye` | Magda | `magdasprite.png` | Night |
| `gardo` | Gardo | `gardosprite.png` | Day, night |
| `hana` | Hana | `hanasprite.png` | Day, night |
| `ito` | Isidro | `isidrosprite.png` | Day |
| `jessa` | Jessa | `jessasprite.png` | Day, night |
| Existing six `generic_*` IDs | Generic riders | `genericspawns.png`, `genericspawns2.png` | Shared day/night poses and six alternates |

Placement availability and story availability are separate. For example, Jessa
has both poses, but her live schedule remains morning/noon before her first event
is completed. She is absent for the remainder of that event's day, then can appear
on later nights. The saved unpaid-fare history supplies the date, so reloads and
gallery replays cannot restart the absence. Alma and Hana have day placements but are not
eligible at noon. The projected trip phase determines which background and
schedule apply.

To regenerate crops after changing a placement sheet, use Python with Pillow:

```powershell
python tools/extract_terminal_spawns.py
python tools/extract_terminal_spawns.py --check
```

The tool preserves each visible source pixel exactly once, including disconnected
details and shadows. It fails if the expected character components cannot be
identified. Update the matching `DAY_ENTRIES` / `NIGHT_ENTRIES` rectangles in
`scripts/ride_selection/terminal_spawn_catalog.gd` if positions change, along with
`GENERIC_ENTRIES` and `GENERIC_ALTERNATE_ENTRIES` for the generic sheets; `--check`
verifies both the generated images and these rectangles. Import changed assets
in Godot before running the isolated regression suite.

## Ownership and saves

- `passenger_pool.gd` retains offer rolls, distances, seeded riders and traffic.
- `selection_view.gd` gathers eligible locked offers and formats trip details.
- `terminal_spawn_catalog.gd` owns character IDs, textures and source rectangles.
- `terminal_passenger_view.gd` owns rendering, hit testing, hover and focus.
- `passenger_trip_card.gd` owns the shared trip-details layout;
  `passenger_confirmation.gd` owns the confirmation dialog's presentation/input.
- `station_interface.gd` owns street/terminal navigation; `ride_selection.gd`
  coordinates ride and story entry.

Hovering is read-only. Closing, shopping, saving and returning from a passenger
story preserve usable locked offers. Older saved pools whose passengers are all
ineligible at the projected phase are repaired once with fresh eligible offers
while passengers are available,
without spending time or resources. Existing version-4 selection dictionaries
and scene paths remain valid.
