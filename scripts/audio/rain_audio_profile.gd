extends RefCounted

const NORMAL_PATH := "res://assets/audio/ambience/rain.mp3"
const HEAVY_PATH := "res://assets/audio/ambience/rain_loop.mp3"
const NORMAL_STREAM := preload(NORMAL_PATH)
const HEAVY_STREAM := preload(HEAVY_PATH)
const NORMAL_VOLUME_DB := -3.0
const HEAVY_VOLUME_DB := -6.0
const NORMAL_MUSIC_DUCK_DB := -8.0
const HEAVY_MUSIC_DUCK_DB := -12.0
const INDOOR_BUS := &"RainIndoor"
const INDOOR_CUTOFF_HZ := 2200.0
const INDOOR_FILTER_DB := AudioEffectFilter.FILTER_12DB
# Filtering removes much of the rain's hiss; compensate so it remains audible.
const INDOOR_VOLUME_OFFSET_DB := 3.0


static func stream_for(weather: String) -> AudioStreamMP3:
	match _normalized(weather):
		"rain": return NORMAL_STREAM
		"heavy rain": return HEAVY_STREAM
	return null


static func path_for(weather: String) -> String:
	match _normalized(weather):
		"rain": return NORMAL_PATH
		"heavy rain": return HEAVY_PATH
	return ""


static func volume_db(weather: String, indoors := false) -> float:
	var offset := INDOOR_VOLUME_OFFSET_DB if indoors else 0.0
	match _normalized(weather):
		"rain": return NORMAL_VOLUME_DB + offset
		"heavy rain": return HEAVY_VOLUME_DB + offset
	return 0.0


static func indoor_bus() -> StringName:
	var index := AudioServer.get_bus_index(INDOOR_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, INDOOR_BUS)
	AudioServer.set_bus_send(index, &"Master")
	var filter: AudioEffectLowPassFilter
	if AudioServer.get_bus_effect_count(index) > 0:
		filter = AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
	if filter == null:
		filter = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(index, filter, 0)
	# Reapply tuning when reusing the bus, including after a script reload.
	filter.cutoff_hz = INDOOR_CUTOFF_HZ
	filter.db = INDOOR_FILTER_DB
	AudioServer.set_bus_effect_enabled(index, 0, true)
	return INDOOR_BUS


static func music_duck_db(weather: String) -> float:
	match _normalized(weather):
		"rain": return NORMAL_MUSIC_DUCK_DB
		"heavy rain": return HEAVY_MUSIC_DUCK_DB
	return 0.0


static func _normalized(weather: String) -> String:
	return weather.strip_edges().to_lower().replace("-", " ").replace("_", " ")
