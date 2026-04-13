extends Node

signal category_volume_changed(category: String, value: float)

const SETTINGS_PATH := "user://audio_settings.cfg"
const DEFAULT_VOLUMES := {
	"master": 1.0,
	"music": 0.5,
	"sfx": 1.0,
	"ui": 1.0,
}
const SILENCE_DB := -80.0

var category_volumes: Dictionary = DEFAULT_VOLUMES.duplicate(true)
var registered_players: Array[WeakRef] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_master_volume()


func register_player(player: AudioStreamPlayer, category: String, base_db := 0.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_meta("audio_category", category)
	player.set_meta("audio_base_db", float(base_db))
	registered_players.append(weakref(player))
	_apply_volume_to_player(player)


func set_player_base_db(player: AudioStreamPlayer, base_db: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_meta("audio_base_db", float(base_db))
	_apply_volume_to_player(player)


func get_player_base_db(player: AudioStreamPlayer) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	return float(player.get_meta("audio_base_db", 0.0))


func get_category_volume(category: String) -> float:
	return clampf(float(category_volumes.get(category, 1.0)), 0.0, 1.0)


func set_category_volume(category: String, value: float) -> void:
	var safe_category := str(category).to_lower()
	if not DEFAULT_VOLUMES.has(safe_category):
		return

	var safe_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(get_category_volume(safe_category), safe_value):
		return

	category_volumes[safe_category] = safe_value
	_save_settings()
	if safe_category == "master":
		_apply_master_volume()
	_apply_registered_player_volumes()
	category_volume_changed.emit(safe_category, safe_value)


func resolve_effective_volume_db(category: String, base_db := 0.0) -> float:
	return float(base_db) + _linear_to_db_safe(get_category_volume(category))


func apply_player_volume(player: AudioStreamPlayer) -> void:
	_apply_volume_to_player(player)


func _apply_registered_player_volumes() -> void:
	var live_refs: Array[WeakRef] = []
	for player_ref in registered_players:
		var player = player_ref.get_ref() as AudioStreamPlayer
		if player == null or not is_instance_valid(player):
			continue
		live_refs.append(player_ref)
		_apply_volume_to_player(player)
	registered_players = live_refs


func _apply_volume_to_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	var category := str(player.get_meta("audio_category", "sfx")).to_lower()
	var base_db := float(player.get_meta("audio_base_db", 0.0))
	player.volume_db = resolve_effective_volume_db(category, base_db)


func _apply_master_volume() -> void:
	AudioServer.set_bus_volume_db(0, _linear_to_db_safe(get_category_volume("master")))


func _linear_to_db_safe(value: float) -> float:
	if value <= 0.0:
		return SILENCE_DB
	return linear_to_db(value)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		category_volumes = DEFAULT_VOLUMES.duplicate(true)
		return

	for category in DEFAULT_VOLUMES.keys():
		category_volumes[category] = clampf(
			float(config.get_value("audio", category, DEFAULT_VOLUMES[category])),
			0.0,
			1.0
		)


func _save_settings() -> void:
	var config := ConfigFile.new()
	for category in DEFAULT_VOLUMES.keys():
		config.set_value("audio", category, get_category_volume(category))
	config.save(SETTINGS_PATH)
