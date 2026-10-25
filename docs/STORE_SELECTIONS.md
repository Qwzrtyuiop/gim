# Store street selection

The store street uses `locations/store.png` in morning/noon and
`locations/storenight.png` at night, following the live game clock. Both images
and the supplied `store_select.png` sheet use a **1698 × 926** canvas.

`scripts/ui/store_street_view.gd` keeps one set of normalized rectangles for both
phases. Each full rectangle is clickable, including the transparent interior of
the border drawn in the selector image. The supplied green border appears only
for the hovered item or intentionally focused keyboard/controller item. These
are rectangle selections, so the background objects do not enlarge.

| Action | Source rectangle (x, y, width, height) |
| --- | --- |
| `tricycle` — Lito's parts/gas | 203, 352, 653, 470 |
| `food` — food/energy counter | 1089, 409, 448, 236 |
| `home` — left exit | 1, 353, 89, 495 |
| `station` — right exit | 1592, 410, 103, 453 |

The rectangles scale together with the letterboxed image. Changing the phase
swaps only the background. Picking does not scan the selector alpha or maintain
another nighttime layout. Pointer departure clears a clicked/focused rectangle's
highlight; Tab/arrows/controller navigation can still highlight focus. Closing a
shop or tutorial does not restore stale hover state. Existing shop categories,
prices, owner portraits, speech, resource costs and navigation remain in their
screen-specific helpers.

When replacing the art, keep all three images aligned at the same resolution,
update `ART_SIZE` and `REGIONS` if necessary, then reimport the images in Godot.
The previous `storewithselect.png` had already been deleted by the author and is
no longer referenced by the game.

`tests/store_select_checks.gd` covers both phases, full-interior clicks, all four
actions, resizing, focus/pointer isolation, real shop entry/purchase/tutorial rules
and archived-image save paths. Run the isolated regression command in
[project context](PROJECT_CONTEXT.md); do not run the regression scene directly.

Superseded images were moved to `locations/check/unused/`, with source bytes and
import UIDs retained. Its README lists the seven files and compatibility paths.
Active backgrounds and sheets still used to regenerate house/terminal sprites
remain in their runtime/source locations.
