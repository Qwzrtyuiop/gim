# House selectable items

Home uses the updated `inhouse.png` and `inhouse_night.png` backgrounds on a
shared **1698 × 926** canvas. `locations/houseselect.png` is the canonical
transparent placement/selection sheet for the radio, calendar and sleeping
curtain. The identical supplied `house selectables.png` copy is archived in
`locations/check/unused/`; the game uses `locations/houseselect.png`.

Each item has one source rectangle and one cached alpha mask, shared by day and
night. Transparent parts of the cutout are not rectangular hit areas. The small
two-source-pixel picking tolerance helps with the radio antenna. Changing lighting
only changes the textures; it does not rebuild or recheck a separate hitbox set.

Hovering or deliberately focusing an item draws its isolated selection 6% larger,
above the background, anchored at the bottom center. The input shape stays at its
resting size. Pointer departure clears the visual highlight even when a clicked
button retains keyboard focus. Tab/arrows/controller navigation still highlights
the focused item. Disabling or hiding the room clears those highlights.

The selector contains day-colored artwork. Day hover textures preserve its visible
pixels exactly. Night textures use the matching night background colors while
retaining the supplied yellow outline. Both phases have identical alpha shapes.
The supplied images remain unchanged.

| Item / action ID | Source rectangle (x, y, width, height) | Action |
| --- | --- | --- |
| `radio` | 79, 474, 138, 137 | News/weather radio |
| `calendar` | 799, 392, 65, 114 | Calendar and debt |
| `rest` | 1488, 228, 107, 545 | Rest/Sleep confirmation |
| `ride` | Existing normalized floor polygon | Go outside: Ride or Shop |

There is no exit sprite in the supplied sheet. The bottom-right floor exit keeps
its existing polygon, with a subtle highlight when hovered/focused. All four
actions retain their tutorial, modal and resource behavior. Local speech follows
the current item bounds, including hover enlargement and letterboxing.

## Updating the artwork

Keep both backgrounds and the transparent sheet aligned at the same resolution.
The sheet must contain three separated alpha components, ordered left to right:
radio, calendar, curtain. Then run:

```powershell
python tools/extract_house_selectables.py
python tools/extract_house_selectables.py --check
```

The tool writes `locations/houseselectables/{masks,day,night}/`. It preserves
source positions, verifies reconstruction of every visible selection pixel and
checks equal phase alpha. `--check` also checks the source rectangles in
`scripts/ui/house_selectable_catalog.gd`. If the placement changes, update its
`ENTRIES` rectangles and normalized `REGIONS` together. Import the updated images
in Godot after regenerating them.

`house_selectable_catalog.gd` owns shared placement/art/mask caching;
`house_view.gd` owns rendering, letterboxing and input. The existing home
coordinator and helpers own actions, tutorials and speech.

The isolated regression runner in [project context](PROJECT_CONTEXT.md) includes
`tests/house_select_checks.gd`: phase-shared masks, transparent-area input,
pointer/keyboard behavior, resizing, real home interactions, tutorial gating and
speech anchors. Never launch the regression scene against real saves.
