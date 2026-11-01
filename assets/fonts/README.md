# Game font

All game text uses `game_font.tres`, including the project-wide GUI default.
It wraps Jersey 10 Regular by the Soft Type Project authors.
Its compact pixel shapes keep dialogue, menus and status information consistent.

At the 1280×720 design size, ordinary interface text uses about 20 px,
VN dialogue 22 px, speaker names 26 px, and smaller hints 16–18 px.
Use a 1 px outline for body text. Notebook and minigame canvases apply their
own layout scale, so fit their labels to the authored writing areas instead
of copying the old Press Start sizes or using a global font transform.

Source: <https://github.com/google/fonts/tree/main/ofl/jersey10>

The unmodified font is distributed under SIL Open Font License 1.1.
See `Jersey10-OFL.txt` for the full license and copyright notice.

The previous fonts remain in this folder as unused assets for older references.
