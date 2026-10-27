extends AudioStreamPlayer

# Reusable layers; the persistent audio service shares them across locations.
const NIGHT_STREAM := preload("res://assets/audio/ambience/night.mp3")
const DOGS_STREAM := preload("res://assets/audio/ambience/night_dogs.mp3")
const CARS_STREAM := preload("res://assets/audio/ambience/cars.mp3")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const BASE_VOLUME_DB := -12.0
const DOG_VOLUME_DB := -28.0
const CARS_VOLUME_DB := -22.0
const DOG_CHECK_INTERVAL := 5.0
const DOG_PLAY_CHANCE := 0.25
# Quiet boundaries in the original recording keep each bark burst under 3s.
const DOG_BURSTS := [
	Vector2(0.50, 2.50),
	Vector2(13.80, 16.60),
	Vector2(21.10, 23.90),
	Vector2(49.25, 52.20),
	Vector2(55.50, 57.50),
	Vector2(72.60, 74.80),
	Vector2(87.40, 89.60),
	Vector2(101.00, 103.20),
]

var traffic_enabled := false
var auto_refresh := true
var dogs_player: AudioStreamPlayer
var cars_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var rain_indoors := false
var _rain_path := ""
var dog_check_timer: Timer
var dog_stop_timer: Timer
var _rng := RandomNumberGenerator.new()
var _night_enabled := false
var _dogs_enabled := false


func _ready() -> void:
	name = "HubNightAmbience"
	bus = &"Master"
	var loop := NIGHT_STREAM.duplicate() as AudioStreamMP3
	loop.loop = true
	stream = loop
	AudioSettingsManager.register_player(self, "sfx", BASE_VOLUME_DB)
	_rng.randomize()
	dogs_player = _make_layer("NightDogs", DOGS_STREAM, false, DOG_VOLUME_DB)
	cars_player = _make_layer("NightCars", CARS_STREAM, true, CARS_VOLUME_DB)
	rain_player = _make_layer("RainAmbience", RainAudioProfile.NORMAL_STREAM, true, RainAudioProfile.NORMAL_VOLUME_DB)
	set_rain_indoors(rain_indoors)
	dog_check_timer = Timer.new()
	dog_check_timer.name = "DogCheckTimer"
	dog_check_timer.wait_time = DOG_CHECK_INTERVAL
	dog_check_timer.timeout.connect(_on_dog_check)
	add_child(dog_check_timer)
	dog_stop_timer = Timer.new()
	dog_stop_timer.name = "DogStopTimer"
	dog_stop_timer.one_shot = true
	dog_stop_timer.timeout.connect(_stop_dogs)
	add_child(dog_stop_timer)
	if auto_refresh:
		refresh()


func refresh() -> void:
	refresh_for(PlayerState.get_current_weather(), PlayerState.get_current_time_of_day() == "night", traffic_enabled)


func refresh_for(weather: String, night: bool, traffic: bool, dogs := true) -> void:
	traffic_enabled = traffic
	_night_enabled = night
	_dogs_enabled = night and dogs
	_refresh_rain(weather)
	if night:
		if not playing:
			play()
	else:
		stop()
	if _dogs_enabled:
		if dog_check_timer.is_stopped():
			dog_check_timer.start()
	else:
		_stop_dogs()
		dog_check_timer.stop()
	if night and traffic_enabled:
		if not cars_player.playing:
			cars_player.play()
	else:
		cars_player.stop()


func set_rain_indoors(value: bool) -> void:
	rain_indoors = value
	if rain_player == null:
		return
	var rain_bus: StringName = RainAudioProfile.indoor_bus() if value else &"Master"
	if rain_player.bus != rain_bus:
		rain_player.bus = rain_bus
	if not _rain_path.is_empty():
		var weather := "heavy rain" if _rain_path == RainAudioProfile.HEAVY_PATH else "rain"
		AudioSettingsManager.set_player_base_db(rain_player, RainAudioProfile.volume_db(weather, rain_indoors))


func _refresh_rain(weather: String) -> void:
	var source := RainAudioProfile.stream_for(weather)
	if source == null:
		rain_player.stop()
		_rain_path = ""
		return
	var path := RainAudioProfile.path_for(weather)
	if _rain_path != path:
		rain_player.stop()
		var loop := source.duplicate() as AudioStreamMP3
		loop.loop = true
		rain_player.stream = loop
		_rain_path = path
	AudioSettingsManager.set_player_base_db(rain_player, RainAudioProfile.volume_db(weather, rain_indoors))
	if not rain_player.playing:
		rain_player.play()


func _make_layer(player_name: String, source: AudioStreamMP3, loop_enabled: bool, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	var layer_stream := source.duplicate() as AudioStreamMP3
	layer_stream.loop = loop_enabled
	player.stream = layer_stream
	add_child(player)
	AudioSettingsManager.register_player(player, "sfx", base_db)
	return player


func _on_dog_check() -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	if auto_refresh and PlayerState.get_current_time_of_day() != "night":
		refresh()
		return
	if not _night_enabled or not _dogs_enabled:
		return
	# Use a separate RNG so ambience never changes passenger or traffic rolls.
	var should_play := _rng.randf() < DOG_PLAY_CHANCE
	if not should_play or dogs_player.playing:
		return
	var burst: Vector2 = DOG_BURSTS[_rng.randi_range(0, DOG_BURSTS.size() - 1)]
	dogs_player.play(burst.x)
	dog_stop_timer.start(burst.y - burst.x)


func _stop_dogs() -> void:
	dogs_player.stop()
	dog_stop_timer.stop()
