extends RefCounted

# Defaults for story text and original retro dialogue blips. Speeds are graphemes/second.
const DEFAULTS := {
	"enabled": true,
	"characters_per_second": 36.0,
	"punctuation_pause": 0.12,
	"sound_enabled": true,
	"voice_pitch": 1.0,
	"voice_volume_db": -22.0,
	"voice_every": 2,
	"voice_interval": 0.045,
}
const SPEAKER_ALIASES := {
	"john toda": "john",
	"ben": "benny",
	"man outside": "collector",
}
const SPEAKER_VOICES := {
	"john": {"voice_pitch": 0.9},
	"benny": {"voice_pitch": 1.15},
	"elena": {"voice_pitch": 1.3},
	"jessa": {"voice_pitch": 1.45},
	"collector": {"voice_pitch": 0.7},
}


static func resolve(payload: Dictionary, line: Dictionary, speaker: String) -> Dictionary:
	var settings: Dictionary = DEFAULTS.duplicate(true)
	# Narration scrolls without talking unless the author explicitly enables sound.
	settings.sound_enabled = not speaker.strip_edges().is_empty()
	var key := speaker.strip_edges().to_lower()
	key = str(SPEAKER_ALIASES.get(key, key))
	settings.merge(SPEAKER_VOICES.get(key, {}), true)
	_apply(settings, payload.get("typewriter", {}))
	var voices: Variant = payload.get("voices", {})
	if voices is Dictionary:
		var original_key := speaker.strip_edges().to_lower()
		_apply(settings, voices.get(original_key, voices.get(key, {})))
	_apply(settings, line.get("typewriter", {}))
	settings.characters_per_second = _number(settings.get("characters_per_second"), 36.0, 1.0, 240.0)
	settings.punctuation_pause = _number(settings.get("punctuation_pause"), 0.12, 0.0, 1.0)
	settings.voice_pitch = _number(settings.get("voice_pitch"), 1.0, 0.25, 4.0)
	settings.voice_volume_db = _number(settings.get("voice_volume_db"), -22.0, -80.0, 0.0)
	settings.voice_every = int(_number(settings.get("voice_every"), 2.0, 1.0, 12.0))
	settings.voice_interval = _number(settings.get("voice_interval"), 0.045, 0.025, 1.0)
	settings.enabled = settings.get("enabled", true) if settings.get("enabled", true) is bool else true
	settings.sound_enabled = settings.get("sound_enabled", true) if settings.get("sound_enabled", true) is bool else true
	return settings


static func _apply(settings: Dictionary, value: Variant) -> void:
	if value is bool:
		settings.enabled = value
	elif value is Dictionary:
		settings.merge(value, true)


static func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)
