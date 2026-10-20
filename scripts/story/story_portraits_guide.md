# Story portraits

Add `portraits` to a story payload (initial defaults) or a dialogue section:

```gdscript
{
	"speaker": "John",
	"text": "Uy, Benny!",
	"portraits": [
		{
			"id": "john",
			"texture": "res://assets/characters/John.png",
			"position": "left",
			"height": 300,
		},
		{
			"id": "benny",
			"texture": "res://assets/characters/Benny.png",
			"position": "right",
			"height": 300,
			"flip_h": true,
		},
	],
}
```

Each entry creates a character image just above the dialogue box, with a black
outline drawn over the art, inside its transparent edges. The outline is 2 displayed pixels thick
regardless of portrait height, and also applies to legacy portraits. Use transparent
PNG art for character cutouts. The source image is not modified.

## Automatic speakers in the authored stories

All authored stories enable `"speaker_portraits": true`. Each dialogue line shows
the speaking character on the left above the text box; narration clears the automatic
portrait. John/John Toda and Benny/Ben share their respective artwork in both
languages. The mapping lives in `story_speaker_portraits.gd`. The Collector
(including Man Outside) uses `assets/characters/placeholder.png`.
Arvin and Dylan intentionally remain portrait-free.

An explicit `portraits` array on a line takes precedence for scenes with several
characters. Set `"speaker_portraits": false` on a line or payload to use only
manual portraits.

Any background inside a `specialCG` folder hides **all** named and legacy
portraits, even when dialogue or actions change the cast. This also applies to
background actions, Texture2D references, and resumed stories. Switching back to
a normal background restores portrait visibility.

## Placement

- `id`: required unique identifier for updating/removing the character.
- `texture`: image path or Texture2D. `path` and `portrait` are accepted aliases.
- `position`: `left`, `center`, or `right`. Defaults to `left`.
- `x`: optional normalized horizontal position within the dialogue box, from
  `0.0` to `1.0`; overrides `position`. Useful for four or more characters.
- `height`: displayed height in pixels, default 320. Aspect ratio is preserved.
- `gap`: pixels above the dialogue box, default 0.
- `offset`: optional `[x, y]` pixels. Negative y lifts the image.
- `flip_h`: mirror horizontally, default false.
- `flip_v`: invert vertically, default false.
- `visible`: temporarily hide the image without removing it.

There is no fixed two-character limit. Later entries draw over earlier ones.
Large images can overlap; use height and x to arrange a crowd. Portraits draw
behind the dialogue box, choices, and screen fade, and do not intercept clicks.
Placement follows the dialogue panel if it moves or resizes.

## Change characters during dialogue

Omitting `portraits` keeps the current cast. Supplying the array replaces the
entire cast. Use `"portraits": []` to clear it.

For individual changes, use actions on sections or choices:

```gdscript
"actions": [
	# Update only these properties, preserving John's image and placement.
	{"type": "set_portrait", "id": "john", "flip_h": true},
	# Add another character; an existing ID updates that character instead.
	{"type": "set_portrait", "id": "alma", "texture": "res://assets/characters/Alma.png", "position": "center"},
	{"type": "clear_portrait", "id": "benny"},
]
```

`{"type": "set_portraits", "portraits": [...]}` replaces the whole cast.
`{"type": "clear_portraits"}` clears the new cast.

Portrait state persists between sections and is saved with the pending story,
including choice-action changes. Memory replays show the same visuals without
writing portrait state into the saved game.

## Existing left/right portrait fields

`left_portrait`, `right_portrait`, and the old `set_portrait` / `clear_portrait`
actions using `side` remain supported. These retain their framed appearance but
now fit above the dialogue panel. To mirror one, use a dictionary:

```gdscript
"left_portrait": {"texture": "res://assets/characters/John.png", "flip_h": true}
```

Or include `flip_h` with the texture in a legacy `set_portrait` action.
The existing `focus` / `speaker_side` dimming applies to these legacy frames.
The new named portraits remain at full brightness.

Use the named array for new scenes. Its clear/replace operations affect only the
named portraits; clear legacy portraits with `left_portrait: null`,
`right_portrait: null`, or the old side-based action.
