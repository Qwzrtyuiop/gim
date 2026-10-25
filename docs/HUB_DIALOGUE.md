# Speech in home, station and store

These screens expose `show_message(text, options)` and `show_messages(lines,
options)`. Speech appears in a small balloon beside a target while the current
menu stays open. It uses the existing text-reveal/audio helper without opening a
VN scene, consuming story triggers, advancing time, charging resources or saving.

## Show a message

From the station screen, after opening the terminal:

```gdscript
show_message({
	"english": "Can you take me to the market?",
	"tagalog": "Puwede mo ba akong ihatid sa palengke?",
}, {
	"target": "benny",
	"character_id": "benny",
	"duration": 4.0,
})
```

`character_id` uses the live display-name rules, so Jessa remains `???` until her
name is revealed. Use the stable saved IDs (`ely` for Elena, `faye` for Magda).
For a shop owner or another speaker outside the passenger catalog, supply
`"speaker": "Lito"` instead. Speaker and text can each be a string or an
`{english, tagalog}` dictionary; missing translations fall back to English.

`duration` counts seconds **after** the text finishes appearing. Omit it, or use
zero, to keep the message until clicked. The first click completes revealing text;
the next advances or closes it. X cancels the entire conversation. Clicking a
balloon cannot click a passenger or buy an item behind it.

## Conversations and input

```gdscript
show_messages([
	{
		"target": "benny",
		"character_id": "benny",
		"text": "Sandali lang, John.",
	},
	{
		"target": "benny",
		"character_id": "benny",
		"text": "Sa palengke tayo ngayon.",
	},
], {
	"blocking": true,
})
```

Normal speech lets the menu work outside the balloon and leaves keyboard focus
where it was. `blocking: true` holds menu actions until the conversation ends:
Enter or a click outside the balloon advances it; Escape cancels it. Scroll inside
a long balloon to read it. X and the text area remain usable in both modes.
`closable: false` hides X and prevents Escape cancellation; advancing still works.
Normal, nonblocking speech leaves Escape available for the menu/pause screen.

`show_message` and `show_messages` replace the current queue. To append instead:

```gdscript
hub_dialogue.queue_messages([
	{
		"target": "benny",
		"character_id": "benny",
		"text": "Salamat!",
	},
])
```

All three methods return `false` for empty/invalid content and preserve the active
conversation in that case. Use `hub_dialogue.advance()` or `hub_dialogue.clear()`
for explicit controls. `is_active()` includes a queue waiting for a visible target;
`blocks_input()` is true only for a blocking message that can currently be shown.

## Targets

| Screen | Built-in target IDs |
| --- | --- |
| Home | `radio`, `calendar`, `rest`, `ride` |
| Station street | `tricycle`, `store` |
| Terminal passengers | Any offered saved character ID, or `passenger:<id>`; includes generics |
| Store | `lito`, `eddie`, `shopkeeper`, `tricycle`, `food`, `home`, `station` |

Terminal targets use the actual current sprite bounds, including hover enlargement
and letterboxing. Store owners use their displayed portraits while their matching
shop is open. `shopkeeper` means the active shop; `lito`/`eddie` can also locate the
counter on the street. The street artwork has no separate shop-owner sprite.
Open-shop speech defaults to a narrow balloon below the owner's head, keeping
purchase controls usable. Authors can override `side` and `width` when needed.
Home currently contains object hotspots; register a future character sprite when
you add one rather than treating a hotspot as a character.
Its built-in item targets follow the shared day/night selector shapes and hover
enlargement; see [house selectable artwork](HOUSE_SELECTABLES.md).

For a new `TextureRect` or other `Control`:

```gdscript
hub_dialogue.register_control("visitor", $VisitorPortrait)
show_message("Tao po!", {"target": "visitor", "speaker": "Visitor"})
```

For a `Sprite2D`, use `hub_dialogue.register_sprite("visitor", $VisitorSprite)`.
Both APIs follow movement/transforms and safely handle hidden or freed targets.
For custom-drawn characters, register a callback that returns their rectangle in
global canvas coordinates:

```gdscript
hub_dialogue.register_target("visitor", func() -> Rect2:
	return visitor_rect_in_canvas if visitor_is_visible else Rect2()
)
```

An unavailable/missing target hides and suspends the current message, reveal and
timer until the target is available again. A missing target never creates speech
at an unrelated character. Without a target, the message appears at the bottom
center. To place a message at a normalized screen point, use
`"position": Vector2(0.5, 0.6)` instead.

## Presentation options

| Option | Default / behavior |
| --- | --- |
| `target` | Registered target ID; overrides `position` |
| `speaker` | Optional speaker caption; accepts localized text |
| `character_id` | Live passenger name, overriding `speaker` |
| `duration` | `0`: wait for click; positive seconds after reveal |
| `blocking` | `false`: other menu controls keep working |
| `closable` | `true`: X / blocking Escape can cancel the queue |
| `typewriter` | `true`: gradually reveal; `false` makes text instant |
| `side` | `auto`, `above`, `below`, `left`, `right`; falls back to fit onscreen |
| `width` | `380` logical pixels, constrained to the available area |
| `font_size` | `12`, constrained to 10–18 |
| `hint` | Optional replacement for the small click/advance caption |

Talking blips are silent by default for hub speech. Opt in using the same
[reveal and voice options](../scripts/story/story_dialogue_playback_guide.md) as VN
text, including speaker pitch and custom short clips:

```gdscript
"typewriter": {
	"characters_per_second": 30,
	"sound_enabled": true,
	"voice_pitch": 1.15,
},
```

The reused audio player is registered as SFX. Music continues normally. Pause
freezes reveal and timers. Text is wrapped before revealing and long messages
scroll within a bounded panel.

## Events, lifetime and ownership

Call these APIs from a menu event handler, a character interaction, a purchase
result or another gameplay helper. Store greetings and purchase/error feedback
are working examples in `scripts/store.gd`. Home and station do not add automatic
story dialogue; their public APIs are ready for authored events.

The dialogue node emits `message_started(line)`, `message_finished(line)` and
`sequence_finished(cancelled)`. A replacement or `clear()` ends the old sequence
with `cancelled == true`; draining all messages emits `false`. Connect gameplay
continuations explicitly and check cancellation when appropriate. These are
presentation signals, not persistent story actions or exactly-once save rewards.

Messages wait behind tutorials, home information panels and passenger confirmation.
Their text and timers resume when those overlays close. Changing between the
station street and terminal, changing/closing shops, resting or leaving a scene
clears its conversation. Speech is transient and is not restored after loading.

`scripts/ui/hub_dialogue.gd` owns queues, reveal, names, timing and input.
`hub_speech_box.gd` owns the balloon and safe layout; `hub_dialogue_anchors.gd`
owns coordinate conversion and built-in target geometry. Screen coordinators
keep their existing gameplay transitions and modal priorities.

Run `tests/run_refactor_checks.py` with the console path in
[project context](PROJECT_CONTEXT.md) to validate safely in the disposable fixture.
Never run the regression scene against live saves.
