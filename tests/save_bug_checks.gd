extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SaveResource := preload("res://scripts/save/game_save_resource.gd")
const AssetPathMigration := preload("res://scripts/save/asset_path_migration.gd")


static func run() -> void:
	_test_station_art_migration()
	PlayerState.reset()
	var path := "res://test_user/latest_snapshot.tres"
	PlayerState.money = 111
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	var held_resource = ResourceLoader.load(path)
	assert(held_resource.data.money == 111)
	PlayerState.money = 222
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	PlayerState.money = 0
	assert(Codec.load_from_path(PlayerState, path))
	assert(PlayerState.money == 222, "Reload must read current disk data despite a held cached resource")
	assert(held_resource.data.money == 111, "Loading a new snapshot must not mutate held resource copies")
	assert(not FileAccess.file_exists("res://test_user/latest_snapshot.tmp.tres"))

	# Replacing a nonempty directory must fail without destroying its contents.
	var blocked_path := "res://test_user/blocked_destination.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	var marker := FileAccess.open(blocked_path.path_join("keep.txt"), FileAccess.WRITE)
	marker.store_string("keep")
	marker.close()
	var staged := SaveResource.new()
	staged.version = PlayerState.SAVE_VERSION
	staged.data = {"money": 333}
	assert(Codec.write_snapshot(staged, blocked_path) != OK)
	assert(FileAccess.file_exists(blocked_path.path_join("keep.txt")))
	assert(not FileAccess.file_exists("res://test_user/blocked_destination.tmp.tres"))
	assert(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE).data.money == 222)
	PlayerState.reset()
	print("PASS: station art save migration, latest snapshot reload, checked save replacement, failed replacement cleanup and preserved existing files")


static func _test_station_art_migration() -> void:
	var old_day := "res://assets/story/backgrounds/locations/station.png"
	var old_night := "res://assets/story/backgrounds/locations/station_night.png"
	var new_day := "res://assets/story/backgrounds/locations/Updated_day.png"
	var new_night := "res://assets/story/backgrounds/locations/Updated_night.png"
	# A saved reader can hold paths in both nested presentation and gallery keys.
	PlayerState.reset()
	PlayerState.pending_story = {
		"background": old_day,
		"composition": [{"background": old_night}],
		"_portrait_state": {"background": old_night},
	}
	PlayerState.unlocked_gallery_images = {old_day: true, old_night: true}
	var path := "res://test_user/station_art_migration.tres"
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	PlayerState.pending_story.clear()
	PlayerState.unlocked_gallery_images.clear()
	assert(Codec.load_from_path(PlayerState, path))
	assert(PlayerState.pending_story.background == new_day)
	assert(PlayerState.pending_story.composition[0].background == new_night)
	assert(PlayerState.pending_story._portrait_state.background == new_night)
	assert(PlayerState.unlocked_gallery_images.has(new_day) and PlayerState.unlocked_gallery_images.has(new_night))
	assert(not PlayerState.unlocked_gallery_images.has(old_day) and not PlayerState.unlocked_gallery_images.has(old_night))
	for legacy: String in AssetPathMigration.LEGACY_PATHS:
		if not ("station" in legacy or "rideselectbg" in legacy):
			continue
		var migrated: String = AssetPathMigration.migrate(legacy)
		assert(ResourceLoader.exists(migrated), "Every legacy station path must resolve to the replacement art in one migration pass")
		assert(migrated.get_file().begins_with("Updated_"), "Every station generation must migrate directly to the current art")
		assert(AssetPathMigration.migrate(migrated) == migrated)
