# Story payload contract

For gameplay-changing events, see [story game controls](story_game_controls_guide.md)
and [the gameplay event template](payloads/templates/gameplay_event_template.gd).
These add time skips, resources/upgrades/debt/weather effects, gameplay conditions,
locked choices, story chaining, and post-dialogue destinations.

For stories that start when clicking a passenger card, see
[passenger events](passenger_events_guide.md). These can return to the same
selection, start the clicked ride after dialogue, or skip a phase.

For gradual text and talking blips, see [dialogue playback](story_dialogue_playback_guide.md).
Text reveals by default. Payload/line `typewriter` settings control speed, sound
and pitch; `typewriter: false` keeps a line instant. Checkpoints restore reached
dialogue fully and silently while preserving the action cursor.

For character expressions/outfits, see [sprite variants](story_portraits_guide.md#character-sprite-variants).
Use a speaking line's `sprite`, payload `character_sprites`, or the ordered
`set_character_sprite` action. Choices can switch sprites through actions too.

Start with `payloads/templates/story_payload_template.gd`. Every authored story
uses a single `build()` returning `StoryPayload.normalize({...})`, with the full
composition written directly in that file. Intro builders also accept the next
scene and stage descriptor as arguments. Register the English and Tagalog builders
in `story_payload_catalog.gd`.

Use tabs, one dictionary field per line, trailing commas, and this field order:

1. Metadata: ID, title, portrait setting, optional scene/stage settings, background,
   music, optional ambience, then composition.
2. Lines: speaker and optional display name, text, presentation settings,
   conditions, actions, choices, timing after the line, then jumps.
3. Actions: type first, followed by the action's parameters.

Each composition entry has a zero-based section comment. Branch targets use named
constants at the top of the file, such as `CHASE` or `TELL_TRUTH`, with matching
comments at their destinations. When inserting sections, update both the constants
and comments. A `STORY_END` target equals the composition length.

English and Tagalog use the same authoring format: keep speaker, text, and that
line's actions together. Use a full line dictionary for translated dialogue;
avoid separate text arrays indexed into another language's composition.

All stories use the same output structure:

```gdscript
extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const HELP := 1
const LEAVE := 2
const STORY_END := 3


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "my_story",
		"chapter_title": "My Story",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"speaker": "John Toda",
				"text": "Should I help?",
				"choices": [
					{
						"text": "Help",
						"next_index": HELP,
					},
					{
						"text": "Leave",
						"next_index": LEAVE,
					},
				],
			},
			# 1 — HELP
			{
				"text": "I help.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "my_story_helped",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 — LEAVE
			{
				"text": "I leave.",
				"next_index": STORY_END,
			},
		],
	})
```

- `composition` is an ordered array. Each normalized line has `speaker`, `text`,
  `actions`, and `choices`; omitted arrays become empty. Narration has an empty speaker.
- `actions` contain dictionaries with a `type`. Choices also accept `actions`.
  See `story_action_runner.gd` for supported actions. Presentation actions run in
  memories; persistent actions such as rewards, achievements, and turn skips do not.
- `next_index` is zero-based. The composition length means story completion.
  Existing saves store section indices, so preserve each language's section order
  when editing existing stories. Some older translations have different section
  counts; their existing numbering is preserved. For new translations, keep the
  same branches, conditions, actions, and presentation as the source language.
- Conditions, camera, portraits, dialogue overrides, and story-specific metadata
  remain available. Normalization preserves them and does not rearrange branches.
- A line's optional `choice_details` shows a compact information card above its
  choices. Keep button text short; put costs, rewards and duration in that card.
  Disabled choices can explain their requirement through `locked_reason` tooltips.
- Resource paths and shared audio defaults live in `story_constants.gd`.
  Use `STATION_MUSIC` for Day 2 and station/random events, and
  `DRIVING_CHILL_MUSIC` for Elena's ride. Custom music and SFX settings use the
  same expanded dictionary style. Empty `music` means silence.
- Legacy `sections`/`lines`, `triggers`, choice `effects`, and `action` keys remain
  accepted when old saves are loaded; use canonical names in new content.
- Do not author `_checkpoint` or `_portrait_state`. The reader records the reached
  background, portraits, dialogue, camera, overlays, music, and looping SFX.
  Loading a completed checkpoint does not repeat that line's rewards or penalties.
  Music and looping SFX restart from the beginning of the saved track; one-shot SFX
  are not replayed. Older saves without a checkpoint use the legacy restore path
  once, then receive a checkpoint after the next completed step.
- Exiting during an animated step saves its action cursor. On resume, remaining
  actions continue; completed money, energy, and achievement actions do not repeat.
- Escape-menu manual saves can also capture dialogue reveal, choice prompts and
  unfinished action waits. Their checkpoint is copied into the selected slot;
  the live story's batch, action cursor and pending checkpoint remain unchanged.
  Reached text loads fully revealed and silently using the same resume contract.
- Each completed line, or choice plus its destination line, flushes one save.
  Keep state changes behind PlayerState APIs so they participate in batching.

Run `StoryPayload.validate(payload)` to check IDs and jump bounds. The regression
suite checks every registered story in both languages, including English fallbacks.
The existing Day 7 Tagalog placeholder and Bayanihan English fallback remain as authored.

## Regression checks

```powershell
python tests/run_refactor_checks.py --godot "<path to Godot console executable>" --check payloads
```

Run only when requested, after importing the project in Godot. Use `--list` for
other focused targets, or `--full` for an explicitly requested complete run.
The runner copies the project and import
cache into `.godot/refactor_checks`, redirects save/settings paths inside that copy,
and instruments save counts there. It does not modify real player saves or settings.
Checks cover payloads, live passenger progress/name rules, traffic lane membership,
collision-cache invalidation, following behavior, save batching, and branch resume.
