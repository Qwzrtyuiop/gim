# Gradual dialogue and retro talking sounds

VN lines now reveal gradually by default, with a short original retro blip while
a character speaks. Narration reveals silently. Press Enter, Space, or left-click
while text is appearing to reveal the complete line and silence the blips. That
press does not advance or select an option. After the line and its authored actions
finish, the next press advances or the choices become available.

Pausing freezes reveal and audio. Spaces and punctuation do not produce blips;
punctuation adds a short reading pause. Wrapped text keeps its final layout while
revealing. Unicode grapheme boundaries keep combining accents and emoji intact.

## Defaults and speaker voices

Edit [`scripts/config/story_dialogue_settings.gd`](../config/story_dialogue_settings.gd)
and restart the game. Defaults are 36 visible characters per second, 0.12 seconds
of punctuation pause, and a blip every second voiced character. A minimum sound
interval prevents bursts on slow frames. Named-speaker profiles have different
pitches; John/John Toda and Benny/Ben share their respective profiles.

The generated blip is original, not sampled from another game. It uses its own
audio player registered in the SFX category, leaving music and looping story
ambience alone. Existing SFX/master volume and mute controls apply to it.

## Per-story and per-line controls

Set `typewriter` on a payload or line. `false` gives instant, silent text; `true`
enables reveal. A dictionary overrides selected defaults:

```gdscript
{
	"speaker": "John Toda",
	"text": "May pasahero pa kaya?",
	"typewriter": {
		"characters_per_second": 32,
		"voice_pitch": 0.85,
		"voice_volume_db": -24,
	},
}
```

| Setting | Meaning |
| --- | --- |
| `enabled` | Whether text reveals gradually |
| `characters_per_second` | Reveal speed, clamped to 1–240 |
| `punctuation_pause` | Added delay after punctuation/newline, 0–1 seconds |
| `sound_enabled` | Enable/disable blips while retaining reveal |
| `voice_pitch` | Pitch/playback-rate multiplier, 0.25–4; 1 is the normal blip |
| `voice_volume_db` | Base blip volume, −80–0 dB, before the SFX volume setting |
| `voice_every` | Blip on the first voiced character and then every N, 1–12 |
| `voice_interval` | Minimum interval between blips, 0.025–1 seconds |
| `voice_stream` | Optional audio resource/path replacing the generated sound |

A custom clip should be very short. Its loop setting is disabled on a copy, so
the source sound remains unchanged. Missing/invalid clips use the generated blip.
Higher `voice_pitch` also plays that clip faster; this is a simple retro playback
effect, not time-preserving pitch correction.

Payloads may supply `voices` dictionaries keyed by lowercase speaker identity:

```gdscript
"typewriter": {
	"characters_per_second": 38,
},
"voices": {
	"benny": {
		"voice_pitch": 1.2,
		"voice_every": 3,
	},
},
```

Settings resolve in this order: global defaults and speaker profile, payload
`typewriter`, payload `voices` for the speaker, then line `typewriter`. Voice
identity uses the original speaker, not the masked display name. An empty speaker
is silent unless `sound_enabled` is explicitly set true. Nothing changes speaker
names, portrait casting, story IDs or saved section indices.

The existing `set_dialogue` action also reveals its replacement text. It accepts
an optional `typewriter` override; absent that, the current line/payload settings
apply. Hiding dialogue, skipping, replacing it, or leaving the scene stops voice.

## Actions, checkpoints and testing

Line actions still run in their original order while text is appearing. Their
effects are not tied to each letter, and the reveal skip does not skip actions,
fades or authored waits. Choices and Continue wait for reveal, actions and
`pause_after` to complete. No save is written per character.

Exiting mid-reveal saves the existing action cursor and presentation checkpoint.
On reload, reached dialogue appears fully and silently, and only uncompleted
actions resume. Previously completed rewards cannot run again. Memory replays
use the same reveal presentation while continuing to suppress persistent effects.
The save format stays at version 4.

The isolated regression runner gives older behavior-only fixtures instant text
through `testing/instant_story_text`. Dedicated playback checks explicitly enable
real reveal and test partial visibility, graphemes, punctuation, first/second press,
pause, choices, interruption/reload, audio cadence and mute. This setting is never
added to the production project.

Implementation uses Godot's [Label visibility controls](https://docs.godotengine.org/en/4.6/classes/class_label.html#class-label-property-visible-characters)
and [TextServer character boundaries](https://docs.godotengine.org/en/4.6/classes/class_textserver.html#class-textserver-method-string-get-character-breaks).
