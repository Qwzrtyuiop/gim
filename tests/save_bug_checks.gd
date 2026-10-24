extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SaveResource := preload("res://scripts/save/game_save_resource.gd")


static func run() -> void:
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
	print("PASS: latest snapshot reload, checked save replacement, failed replacement cleanup and preserved existing files")
