extends RefCounted

const NORMAL_PATH := "res://assets/audio/ambience/rain.mp3"
const HEAVY_PATH := "res://assets/audio/ambience/rain_loop.mp3"
const NORMAL_STREAM := preload(NORMAL_PATH)
const HEAVY_STREAM := preload(HEAVY_PATH)
const NORMAL_VOLUME_DB := -3.0
const HEAVY_VOLUME_DB := -6.0
const NORMAL_MUSIC_DUCK_DB := -8.0
const HEAVY_MUSIC_DUCK_DB := -12.0


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


static func volume_db(weather: String) -> float:
	match _normalized(weather):
		"rain": return NORMAL_VOLUME_DB
		"heavy rain": return HEAVY_VOLUME_DB
	return 0.0


static func music_duck_db(weather: String) -> float:
	match _normalized(weather):
		"rain": return NORMAL_MUSIC_DUCK_DB
		"heavy rain": return HEAVY_MUSIC_DUCK_DB
	return 0.0


static func _normalized(weather: String) -> String:
	return weather.strip_edges().to_lower().replace("-", " ").replace("_", " ")
