# Asset directory

Edit the active file in its category below. The scripts and scenes use these
paths; archived copies are not used by the game.

| Folder | Contents |
| --- | --- |
| `story/backgrounds/locations/` | Home, station, store, city, bar, and other scene backgrounds |
| `story/backgrounds/roads/` | Scrolling road backgrounds for gameplay and menus |
| `story/specialCG/` | Full-scene illustrations; character portraits are hidden on these backgrounds |
| `characters/` | Character portraits, generic portraits, and placeholders |
| `vehicles/` | Player, traffic, and parked vehicle sprites |
| `weather/` | Rain overlays and other weather graphics |
| `audio/music/driving/` | Ride music by traffic/time variant |
| `audio/music/story/` | Story music and home music |
| `audio/music/menus/` | Menu music, currently the store track |
| `audio/ambience/` | City/bar atmosphere, wind, and rain loops |
| `audio/sfx/driving/` | Engine, horn, and crash effects |
| `audio/sfx/story/` | Knock, door, impact, alarm, and running effects |
| `audio/sfx/ui/` | Button hover and press sounds |
| `ui/branding/` | Game logo |
| `ui/buttons/main_menu/` | Main-menu button states |
| `ui/buttons/hub/` | Rest, Store, and Ride buttons |
| `ui/buttons/` | Shared generic button |
| `ui/frames/` | Shared UI frame |
| `ui/icons/` | Energy and gas icons |
| `ui/tutorial/` | Driving tutorial artwork |
| `ui/source_sheets/` | Original combined button sheets retained for editing |
| `fonts/` | Game fonts |
| `archive/` | Old variants, placeholders, and duplicate source art; excluded from Godot imports |

Godot's adjacent `.import` files contain resource IDs and import settings. Keep
them with their assets when moving files in the editor. The 2026-10 folder
cleanup preserved those IDs and the original asset contents.

Older saves are translated by `scripts/save/asset_path_migration.gd`, including
pending-story backgrounds/audio and gallery dictionary keys. Do not remove
those aliases while older saves are supported. New content should use only
the active paths above.
