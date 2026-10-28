# Store street selection

The store street uses `locations/store.png` in morning/noon,
`locations/storenight.png` at night and `locations/storemidnight.png` at midnight,
following the live game clock. Day/night art and the supplied `store_select.png`
sheet use a **1698 × 926** canvas. The 1697 × 927 midnight image fits the same
logical canvas, preserving the shared exit positions without editing the source.

`scripts/ui/store_street_view.gd` keeps one set of normalized rectangles for all
phases. Each available rectangle is clickable, including the transparent interior of
the border drawn in the selector image. The supplied green border appears only
for the hovered item or intentionally focused keyboard/controller item. These
are rectangle selections, so the background objects do not enlarge.

| Action | Source rectangle (x, y, width, height) |
| --- | --- |
| `tricycle` — Lito's parts/gas | 203, 352, 653, 470 |
| `food` — food/energy counter | 1089, 409, 448, 236 |
| `map` — left exit | 1, 353, 89, 495 |
| `station` — right exit | 1592, 410, 103, 453 |

The rectangles scale together with the letterboxed image. Changing the phase
swaps the background and shop availability. Picking does not scan the selector alpha or maintain
another nighttime layout. Pointer departure clears a clicked/focused rectangle's
highlight; Tab/arrows/controller navigation can still highlight focus. Closing a
shop or tutorial does not restore stale hover state. Existing shop categories,
prices, owner portraits, speech, resource costs and navigation remain in their
screen-specific helpers.

At midnight, Lito's and Mang Eddie's are closed but remain selectable with mouse,
keyboard or controller. Clicking either shows John's floating "It's closed."
message at that shop, without opening its panel or blocking navigation.
Map and Station remain available, using the same exit rectangles. Shop entry
and purchase handlers also reject stale callbacks at midnight, and refreshing
an already-open shop closes its overlay. Unseen shop tutorials wait until the
shops reopen, so they cannot block midnight navigation or be marked completed.
Ordinary night and daytime keep both shops open.

A bottom-left MAP button opens town navigation from Store. The left exit also
opens Map; choose Home there. Back/Escape returns to Store, while travel keeps
locked passenger offers, resources and the clock. Map input is blocked during
shop overlays, tutorials and blocking dialogue.

When replacing the art, keep the backgrounds and selector aligned to the shared canvas,
update `ART_SIZE` and `REGIONS` if necessary, then reimport the images in Godot.
The previous `storewithselect.png` had already been deleted by the author and is
no longer referenced by the game.

`tests/store_select_checks.gd` covers both phases, full-interior clicks, all four
actions, resizing, focus/pointer isolation, midnight closure and exit transitions,
real shop entry/purchase/tutorial rules
and archived-image save paths. Run the isolated regression command in
[project context](PROJECT_CONTEXT.md); do not run the regression scene directly.

Superseded images were moved to `locations/check/unused/`, with source bytes and
import UIDs retained. Its README lists the seven files and compatibility paths.
Active backgrounds and sheets still used to regenerate house/terminal sprites
remain in their runtime/source locations.
