extends RefCounted

const BACKGROUND_INHOUSE := "res://assets/story/backgrounds/locations/inhouse.png"
const BACKGROUND_INHOUSE_NIGHT := "res://assets/story/backgrounds/locations/inhouse_night.png"
const BACKGROUND_BAR := "res://assets/story/backgrounds/locations/bar.png"
const BACKGROUND_BAR_EXTERIOR_NIGHT := "res://assets/story/backgrounds/locations/barnight.png"
const BACKGROUND_GARAGE_NORMAL := "res://assets/story/backgrounds/locations/garagenormal.png"
const BACKGROUND_STATION := "res://assets/story/backgrounds/locations/Updated_day.png"
const BACKGROUND_TERMINAL := "res://assets/story/backgrounds/locations/terminalday.png"
const BACKGROUND_TERMINAL_NIGHT := "res://assets/story/backgrounds/locations/terminalnight.png"
const BACKGROUND_ALLEY := "res://assets/story/backgrounds/locations/Alley.png"
const BACKGROUND_CITY := "res://assets/story/backgrounds/locations/city.png"
const BACKGROUND_STORYDOOR := "res://assets/story/backgrounds/locations/storydoor.png"
const BACKGROUND_STORYDOOR_ZOOM := "res://assets/story/backgrounds/locations/storydoorzoom.png"
const BACKGROUND_LOWANGLE_HOUSE := "res://assets/story/backgrounds/locations/lowanglehouse.png"
const BACKGROUND_STORE := "res://assets/story/backgrounds/locations/store.png"
const BACKGROUND_STREET_DAY := "res://assets/story/backgrounds/locations/streetday.png"
const BACKGROUND_STREET_NIGHT := "res://assets/story/backgrounds/locations/streetnight.png"
const BACKGROUND_PARK_DAY := "res://assets/story/backgrounds/locations/park.png"
const BACKGROUND_PARK_NIGHT := "res://assets/story/backgrounds/locations/parknight.png"
const BACKGROUND_MARKET_DAY := "res://assets/story/backgrounds/locations/market.png"
const BACKGROUND_MARKET_NIGHT := "res://assets/story/backgrounds/locations/marketnight.png"
const BACKGROUND_ROAD_1 := "res://assets/story/backgrounds/roads/bg1_loop.png"
const CG_TROPA := "res://assets/story/specialCG/tropaCg.png"
const ITEM_JESSA_WALLET := "res://assets/story/items/jessawallet.png"
const ITEM_HANA_ID := "res://assets/story/items/hanaid.png"
const ITEM_HANA_NOTEBOOK := "res://assets/story/items/hananotebook.png"
const ITEM_RABBIT_BANDAID := "res://assets/story/items/rabbit bandaid.png"
const SPRITE_GARDO_MIDNIGHT := "res://assets/characters/sprites/terminal/midnight/gardo.tres"

const MUSIC_CITY_AMBIENCE := "res://assets/audio/ambience/city_ambience.mp3"
const MUSIC_BAR := "res://assets/audio/music/story/bar.mp3"
const MUSIC_BAR_SFX := "res://assets/audio/ambience/bar_ambience.mp3"
const MUSIC_DRUM := "res://assets/audio/music/story/drum.mp3"
const MUSIC_ALARM_SFX := "res://assets/audio/sfx/story/alarm.mp3"
const MUSIC_RUNNING_SFX := "res://assets/audio/sfx/story/running.mp3"
const MUSIC_WIND_BREEZE_SFX := "res://assets/audio/ambience/wind_breeze.mp3"
const MUSIC_MORNING_CHILL := "res://assets/audio/music/driving/morning_chill.mp3"
const MUSIC_FUNNY := "res://assets/audio/music/story/funny.mp3"
const MUSIC_MIND := "res://assets/audio/music/story/mind.mp3"
const MUSIC_MURDER := "res://assets/audio/music/story/murder.mp3"

const SFX_KNOCK := "res://assets/audio/sfx/story/knock.mp3"
const SFX_DOOR_OPEN := "res://assets/audio/sfx/story/door_open.mp3"
const SFX_HIT := "res://assets/audio/sfx/story/hit.mp3"
const SFX_ENGINE := "res://assets/audio/sfx/driving/engine_loop.mp3"

# Shared presentation used by Day 2, station stories, and random ride events.
# Payload normalization copies these dictionaries before the reader uses them.
const STATION_MUSIC := {
	"type": "play_music",
	"path": MUSIC_CITY_AMBIENCE,
	"loop": true,
	"fade_in": 0.55,
	"volume_db": -9.0,
}

const DRIVING_CHILL_MUSIC := {
	"type": "play_music",
	"path": MUSIC_MORNING_CHILL,
	"loop": true,
	"fade_in": 0.0,
	"fade_out": 0.0,
	"volume_db": -9.0,
	"restart": false,
}


static func street_background(time_of_day: String) -> String:
	return BACKGROUND_STREET_NIGHT if time_of_day.strip_edges().to_lower() in ["night", "midnight"] else BACKGROUND_STREET_DAY
