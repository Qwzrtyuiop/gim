# Unused background sources

These files were moved here after checking scene, script, story and tool
references. Their image bytes and import UIDs were preserved.

| Image | Previous location | Reason |
| --- | --- | --- |
| `station_day.png` | `locations/` | Replaced by `Updated_day.png` |
| `station_day_select.png` | `locations/` | Replaced by `Updated_day_select.png` |
| `stationnewnight.png` | `locations/` | Replaced by `Updated_night.png` |
| `stationnight_select.png` | `locations/` | Replaced by `Updated_night_select.png` |
| `stationselect.png` | `locations/` | Older station selection artwork |
| `garagespotlight.png` | `locations/` | No current scene/story uses it |
| `house selectables.png` | `backgrounds/` | Identical duplicate of `locations/houseselect.png` |

Existing station save-path migrations still resolve directly to the current
station artwork. Old garage-spotlight paths resolve here so historical saved
background/gallery references remain loadable. Regeneration sources still used
by tools (house/terminal placement sheets and character sprites) remain active.
Images already deleted by the author were not restored.
