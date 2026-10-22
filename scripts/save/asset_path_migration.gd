extends RefCounted

# Compatibility for asset paths stored in saves before the folder cleanup.
const LEGACY_PATHS := {
	"res://assets/background/backgroundfishing.png": "res://assets/story/backgrounds/roads/backgroundfishing.png",
	"res://assets/background/bg1_loop.png": "res://assets/story/backgrounds/roads/bg1_loop.png",
	"res://assets/background/farmloop.png": "res://assets/story/backgrounds/roads/farmloop.png",
	"res://assets/bg/bgresult.png": "res://assets/story/backgrounds/locations/city.png",
	"res://assets/bg/bgstore.png": "res://assets/story/backgrounds/locations/store.png",
	"res://assets/bg/garage normal.png": "res://assets/story/backgrounds/locations/garagenormal.png",
	"res://assets/bg/garagespotlight.png": "res://assets/story/backgrounds/locations/garagespotlight.png",
	"res://assets/bg/inhouse.png": "res://assets/story/backgrounds/locations/inhouse.png",
	"res://assets/bg/rideselectbg.png": "res://assets/story/backgrounds/locations/station.png",
	"res://assets/bg/rideselectbg_night.jpeg": "res://assets/story/backgrounds/locations/station_night.png",
	"res://assets/bg/rideselectbg_night.png": "res://assets/story/backgrounds/locations/station_night.png",
	"res://assets/bg/storydoor.png": "res://assets/story/backgrounds/locations/storydoor.png",
	"res://assets/bg/storydoorzoom.png": "res://assets/story/backgrounds/locations/storydoorzoom.png",
	"res://assets/menu/buttons.png": "res://assets/ui/source_sheets/main_menu_buttons.png",
	"res://assets/menu/buttons/gallery_inactive.png": "res://assets/ui/buttons/main_menu/gallery_inactive.png",
	"res://assets/menu/buttons/quit_active.png": "res://assets/ui/buttons/main_menu/quit_active.png",
	"res://assets/menu/buttons/quit_inactive.png": "res://assets/ui/buttons/main_menu/quit_inactive.png",
	"res://assets/menu/buttons/start_active.png": "res://assets/ui/buttons/main_menu/start_active.png",
	"res://assets/menu/buttons/start_inactive.png": "res://assets/ui/buttons/main_menu/start_inactive.png",
	"res://assets/menu/logo.png": "res://assets/ui/branding/logo.png",
	"res://assets/sfx/car beep.mp3": "res://assets/audio/sfx/driving/car_horn.mp3",
	"res://assets/sfx/crash.mp3": "res://assets/audio/sfx/driving/crash.mp3",
	"res://assets/sfx/engineloop.mp3": "res://assets/audio/sfx/driving/engine_loop.mp3",
	"res://assets/sfx/rain.mp3": "res://assets/audio/ambience/rain.mp3",
	"res://assets/specialCG/BennyCg2.jpeg": "res://assets/story/specialCG/BennyCg2.jpeg",
	"res://assets/specialCG/almaCg1.jpeg": "res://assets/story/specialCG/almaCg1.jpeg",
	"res://assets/specialCG/almaCg2.jpeg": "res://assets/story/specialCG/almaCg2.jpeg",
	"res://assets/specialCG/bennyCg1.jpeg": "res://assets/story/specialCG/bennyCg1.jpeg",
	"res://assets/specialCG/tropaCg.png": "res://assets/story/specialCG/tropaCg.png",
	"res://assets/stagebgm/chill_normal_day_noon.mp3": "res://assets/audio/music/driving/chill_normal_day_noon.mp3",
	"res://assets/stagebgm/morning_chill.mp3": "res://assets/audio/music/driving/morning_chill.mp3",
	"res://assets/stagebgm/night_chill.mp3": "res://assets/audio/music/driving/night_chill.mp3",
	"res://assets/stagebgm/normal3.mp3": "res://assets/audio/music/driving/normal3.mp3",
	"res://assets/stagebgm/normalstage1.mp3": "res://assets/audio/music/driving/normalstage1.mp3",
	"res://assets/stagebgm/normalstage2.mp3": "res://assets/audio/music/driving/normalstage2.mp3",
	"res://assets/stagebgm/rainloop.mp3": "res://assets/audio/ambience/rain_loop.mp3",
	"res://assets/stagebgm/speeder.mp3": "res://assets/audio/music/driving/speeder.mp3",
	"res://assets/stagebgm/speeder2.mp3": "res://assets/audio/music/driving/speeder2.mp3",
	"res://assets/stagebgm/speederbusy.mp3": "res://assets/audio/music/driving/speederbusy.mp3",
	"res://assets/stagebgm/speederbusy2.mp3": "res://assets/audio/music/driving/speederbusy2.mp3",
	"res://assets/stagebgm/speederbusy3.mp3": "res://assets/audio/music/driving/speederbusy3.mp3",
	"res://assets/stagebgm/speederbusy4.mp3": "res://assets/audio/music/driving/speederbusy4.mp3",
	"res://assets/stagebgm/store.mp3": "res://assets/audio/music/menus/store.mp3",
	"res://assets/stagebgm/traffic_jam.mp3": "res://assets/audio/music/driving/traffic_jam.mp3",
	"res://assets/story/backgrounds/backgroundfishing.png": "res://assets/story/backgrounds/roads/backgroundfishing.png",
	"res://assets/story/backgrounds/bar.jpeg": "res://assets/story/backgrounds/locations/bar.jpeg",
	"res://assets/story/backgrounds/bg1_loop.png": "res://assets/story/backgrounds/roads/bg1_loop.png",
	"res://assets/story/backgrounds/city.png": "res://assets/story/backgrounds/locations/city.png",
	"res://assets/story/backgrounds/farmloop.png": "res://assets/story/backgrounds/roads/farmloop.png",
	"res://assets/story/backgrounds/garagenormal.png": "res://assets/story/backgrounds/locations/garagenormal.png",
	"res://assets/story/backgrounds/garagenormal.svg": "res://assets/story/backgrounds/locations/garagenormal.png",
	"res://assets/story/backgrounds/garagespotlight.png": "res://assets/story/backgrounds/locations/garagespotlight.png",
	"res://assets/story/backgrounds/inhouse.png": "res://assets/story/backgrounds/locations/inhouse.png",
	"res://assets/story/backgrounds/inhouse.svg": "res://assets/story/backgrounds/locations/inhouse.png",
	"res://assets/story/backgrounds/inhouse_night.png": "res://assets/story/backgrounds/locations/inhouse_night.png",
	"res://assets/story/backgrounds/lowanglehouse.jpeg": "res://assets/story/backgrounds/locations/lowanglehouse.png",
	"res://assets/story/backgrounds/lowanglehouse.png": "res://assets/story/backgrounds/locations/lowanglehouse.png",
	"res://assets/story/backgrounds/station.png": "res://assets/story/backgrounds/locations/station.png",
	"res://assets/story/backgrounds/station_night.jpeg": "res://assets/story/backgrounds/locations/station_night.png",
	"res://assets/story/backgrounds/station_night.png": "res://assets/story/backgrounds/locations/station_night.png",
	"res://assets/story/backgrounds/store.png": "res://assets/story/backgrounds/locations/store.png",
	"res://assets/story/backgrounds/storydoor.png": "res://assets/story/backgrounds/locations/storydoor.png",
	"res://assets/story/backgrounds/storydoorzoom.png": "res://assets/story/backgrounds/locations/storydoorzoom.png",
	"res://assets/story/music/alarm sfx.mp3": "res://assets/audio/sfx/story/alarm.mp3",
	"res://assets/story/music/bar.mp3": "res://assets/audio/music/story/bar.mp3",
	"res://assets/story/music/barsfx.mp3": "res://assets/audio/ambience/bar_ambience.mp3",
	"res://assets/story/music/city_ambience.mp3": "res://assets/audio/ambience/city_ambience.mp3",
	"res://assets/story/music/drum.mp3": "res://assets/audio/music/story/drum.mp3",
	"res://assets/story/music/mind.mp3": "res://assets/audio/music/story/mind.mp3",
	"res://assets/story/music/peace.mp3": "res://assets/audio/music/story/peace.mp3",
	"res://assets/story/music/running.mp3": "res://assets/audio/sfx/story/running.mp3",
	"res://assets/story/music/truth.mp3": "res://assets/audio/music/story/truth.mp3",
	"res://assets/story/music/windbreeze.mp3": "res://assets/audio/ambience/wind_breeze.mp3",
	"res://assets/story/sfx/door_open.mp3": "res://assets/audio/sfx/story/door_open.mp3",
	"res://assets/story/sfx/hit.mp3": "res://assets/audio/sfx/story/hit.mp3",
	"res://assets/story/sfx/knock.mp3": "res://assets/audio/sfx/story/knock.mp3",
	"res://assets/tutorial/tutorial.png": "res://assets/ui/tutorial/tutorial.png",
	"res://assets/ui/breakbuttons.png": "res://assets/ui/source_sheets/hub_buttons.png",
	"res://assets/ui/breakbuttons/rest.png": "res://assets/ui/buttons/hub/rest.png",
	"res://assets/ui/breakbuttons/ride.png": "res://assets/ui/buttons/hub/ride.png",
	"res://assets/ui/breakbuttons/store.png": "res://assets/ui/buttons/hub/store.png",
	"res://assets/ui/button_generic.png": "res://assets/ui/buttons/button_generic.png",
	"res://assets/ui/fx/ui_hover.mp3": "res://assets/audio/sfx/ui/ui_hover.mp3",
	"res://assets/ui/fx/ui_press.mp3": "res://assets/audio/sfx/ui/ui_press.mp3",
	"res://assets/ui/ui_frame.png": "res://assets/ui/frames/ui_frame.png",
}


static func migrate(value: Variant) -> Variant:
	if value is String or value is StringName:
		return LEGACY_PATHS.get(str(value), value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[migrate(key)] = migrate(value[key])
		return result
	if value is Array:
		var result: Array = value.duplicate()
		for index in range(result.size()):
			result[index] = migrate(result[index])
		return result
	if value is PackedStringArray:
		var result: PackedStringArray = value.duplicate()
		for index in range(result.size()):
			result[index] = str(migrate(result[index]))
		return result
	return value
