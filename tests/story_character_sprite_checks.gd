extends RefCounted

const Sprites := preload("res://scripts/story/story_character_sprites.gd")
const Speakers := preload("res://scripts/story/story_speaker_portraits.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Actions := preload("res://scripts/story/story_action_runner.gd")
const MAGDA_DEFAULT := "res://assets/characters/Magda.png"
const MAGDA_ALT := "res://assets/characters/Magda_alt.png"
const JOHN_DEFAULT := "res://assets/characters/John.png"
const Constants := preload("res://scripts/story/story_constants.gd")


static func run(host: Node) -> void:
	_test_registry()
	await _test_speakers_and_choices(host)
	await _test_named_cast(host)
	await _test_checkpoint_and_initial_defaults(host)
	await _test_replay_isolation(host)
	PlayerState.reset()
	print("PASS: character sprite aliases/variants, remembered speaker and choice changes, named cast placement, CG hiding, checkpoint reload and replay isolation")


static func _test_registry() -> void:
	assert(Sprites.canonical_character_id(" Magda ") == "faye")
	assert(Sprites.canonical_character_id("FAYE") == "faye")
	assert(Sprites.canonical_character_id("John Toda") == "john")
	assert(Sprites.texture_path("magda") == MAGDA_DEFAULT)
	assert(Sprites.texture_path("faye", "alt") == MAGDA_ALT)
	assert(Sprites.is_valid("magda", "alt"))
	assert(not Sprites.is_valid("magda", "not_registered"))
	assert(Sprites.texture_path("unknown", "default").is_empty())
	assert(Speakers.for_speaker("Magda", "alt")[0].texture == MAGDA_ALT)
	assert(Speakers.for_speaker("Ben")[0].texture == Speakers.for_speaker("Benny")[0].texture)
	assert(Speakers.for_speaker("Arvin").is_empty() and Speakers.for_speaker("Dylan").is_empty())
	assert(not Actions.is_persistent_story_action({"type": "set_character_sprite"}), "Sprite changes must also run in memories")


static func _reader(host: Node, payload: Dictionary = {}, replay := false):
	if not payload.is_empty():
		if replay:
			PlayerState.set_pending_memory_replay(Payload.normalize(payload))
		else:
			PlayerState.set_pending_story(Payload.normalize(payload))
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(0.5).timeout
	assert(not reader.is_input_locked)
	return reader


static func _speaker_texture(reader) -> String:
	assert(reader.portrait_layer.images.has("speaker"))
	return reader.portrait_layer.images["speaker"].texture.resource_path


static func _test_speakers_and_choices(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "sprite_speaker_fixture",
		"speaker_portraits": true,
		"composition": [
			{"speaker": "Magda", "text": "Alternate", "sprite": "alt"},
			{"speaker": "John Toda", "text": "John"},
			{"text": "Narration"},
			{"speaker": "Faye", "text": "Still alternate"},
			{
				"speaker": "Magda",
				"text": "Default",
				"sprite": "default",
				"choices": [
					{
						"text": "Change sprite",
						"actions": [{"type": "set_character_sprite", "character_id": "magda", "sprite": "alt"}],
						"next_index": 5,
					},
				],
			},
			{"speaker": "Magda", "text": "Changed by choice"},
			{"speaker": "Magda", "text": "Invalid variant keeps the current sprite", "sprite": "not_registered"},
		],
	})
	assert(_speaker_texture(reader) == MAGDA_ALT)
	await reader._advance_story()
	assert(_speaker_texture(reader) == JOHN_DEFAULT)
	await reader._advance_story()
	assert(reader.portrait_layer.entries.is_empty(), "Narration still hides the automatic speaker")
	await reader._advance_story()
	assert(_speaker_texture(reader) == MAGDA_ALT, "A speaker change cannot reset a remembered sprite")
	await reader._advance_story()
	assert(_speaker_texture(reader) == MAGDA_DEFAULT)
	await reader._choose_branch(reader.story_lines[4].choices[0])
	assert(_speaker_texture(reader) == MAGDA_ALT and reader.character_sprites.faye == "alt")
	var choices: Dictionary = reader.character_sprites.duplicate(true)
	await reader._run_story_action({"type": "set_character_sprite", "character_id": "magda", "sprite": "not_registered"})
	assert(_speaker_texture(reader) == MAGDA_ALT and reader.character_sprites == choices, "Rejected actions leave the displayed sprite and remembered choices unchanged")
	await reader._advance_story()
	assert(_speaker_texture(reader) == MAGDA_ALT, "Unknown variants must not blank or reset an existing sprite")
	reader.free()


static func _test_named_cast(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "sprite_named_fixture",
		"background": Constants.BACKGROUND_STATION,
		"portraits": [
			{"id": "magda_cast", "character_id": "Magda", "sprite": "default", "position": "right", "height": 270, "flip_h": true},
			{"id": "john_cast", "texture": JOHN_DEFAULT, "position": "left", "height": 290},
			{"id": "magda_path", "character_id": "magda", "path": MAGDA_DEFAULT, "position": "center", "height": 240},
			{"id": "magda_portrait", "character_id": "magda", "portrait": MAGDA_DEFAULT, "position": "left", "height": 220},
		],
		"composition": [{"text": "A manual cast"}, {"text": "Save the changed cast"}],
	})
	var john: Dictionary = reader.portrait_layer.entries[1].duplicate(true)
	# An explicitly supplied image must survive updates that only change placement.
	await reader._run_story_action({"type": "set_portrait", "id": "magda_cast", "texture": JOHN_DEFAULT})
	await reader._run_story_action({"type": "set_portrait", "id": "magda_cast", "position": "center", "height": 260, "flip_h": false})
	assert(reader.portrait_layer.images.magda_cast.texture.resource_path == JOHN_DEFAULT, "Placement-only updates cannot replace custom artwork with the registry default")
	assert(reader.portrait_layer.entries[0].position == "center" and not reader.portrait_layer.images.magda_cast.flip_h)
	await reader._run_story_action({"type": "set_portrait", "id": "magda_cast", "position": "right", "height": 270, "flip_h": true})
	await reader._run_story_action({"type": "set_character_sprite", "character_id": "faye", "sprite": "alt"})
	var magda: Dictionary = reader.portrait_layer.entries[0]
	assert(reader.portrait_layer.images.magda_cast.texture.resource_path == MAGDA_ALT)
	assert(magda.position == "right" and magda.height == 270 and magda.flip_h)
	assert(reader.portrait_layer.images.magda_cast.flip_h)
	assert(reader.portrait_layer.entries[1] == john, "Changing one character cannot alter other portraits")
	for id in ["magda_path", "magda_portrait"]:
		assert(reader.portrait_layer.images[id].texture.resource_path == MAGDA_ALT, "A sprite switch replaces either texture alias")
	for entry: Dictionary in reader.portrait_layer.entries:
		assert(not entry.has("path") and not entry.has("portrait"), "Stale aliases cannot override a changed texture during reload")
	await reader._advance_story()
	Codec.save_to_path(PlayerState, "res://test_user/character_sprite_aliases.tres", PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/character_sprite_aliases.tres"))
	reader = await _reader(host)
	for id in ["magda_cast", "magda_path", "magda_portrait"]:
		assert(reader.portrait_layer.images[id].texture.resource_path == MAGDA_ALT, "Checkpoint restore cannot revive an old path/portrait texture alias")
	await reader._run_story_action({"type": "set_background", "background": "res://assets/story/specialCG/tropaCg.png"})
	await reader._run_story_action({"type": "set_character_sprite", "character_id": "Magda", "sprite": "default"})
	assert(not reader.portrait_layer.visible, "Sprite changes cannot reveal portraits over special CGs")
	assert(reader.portrait_layer.images.magda_cast.texture.resource_path == MAGDA_DEFAULT)
	await reader._run_story_action({"type": "set_background", "background": Constants.BACKGROUND_STATION})
	assert(reader.portrait_layer.visible)
	reader.free()


static func _test_checkpoint_and_initial_defaults(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "sprite_checkpoint_fixture",
		"speaker_portraits": true,
		"character_sprites": {"magda": "alt"},
		"composition": [
			{"speaker": "John", "text": "Checkpoint while another character speaks"},
			{"speaker": "Magda", "text": "Alternate persists after loading"},
		],
	})
	assert(_speaker_texture(reader) == JOHN_DEFAULT and reader.character_sprites.faye == "alt")
	var pending := PlayerState.get_pending_story()
	assert(pending._checkpoint.character_sprites.faye == "alt")
	assert(pending._portrait_state.character_sprites.faye == "alt")
	Codec.save_to_path(PlayerState, "res://test_user/character_sprite_checkpoint.tres", PlayerState.SAVE_VERSION)
	# Older checkpoints lack this key; the surrounding portrait state still owns
	# the remembered choices. Remove payload defaults to test that fallback alone.
	var old_pending := pending.duplicate(true)
	old_pending._checkpoint.erase("character_sprites")
	old_pending.erase("character_sprites")
	PlayerState.set_pending_story(old_pending)
	Codec.save_to_path(PlayerState, "res://test_user/character_sprite_old_checkpoint.tres", PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/character_sprite_checkpoint.tres"))
	reader = await _reader(host)
	assert(_speaker_texture(reader) == JOHN_DEFAULT)
	await reader._advance_story()
	assert(_speaker_texture(reader) == MAGDA_ALT, "Reloading must restore hidden characters' remembered sprite choices")
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/character_sprite_old_checkpoint.tres"))
	reader = await _reader(host)
	assert(_speaker_texture(reader) == JOHN_DEFAULT and reader.character_sprites.faye == "alt")
	await reader._advance_story()
	assert(_speaker_texture(reader) == MAGDA_ALT, "An older checkpoint must retain the portrait state's remembered variant")
	reader.free()
	PlayerState.reset()
	reader = await _reader(host, {
		"story_id": "sprite_fresh_fixture",
		"speaker_portraits": true,
		"composition": [{"speaker": "Magda", "text": "A new story uses her default"}],
	})
	assert(_speaker_texture(reader) == MAGDA_DEFAULT, "Scene-local choices cannot leak into unrelated stories")
	reader.free()


static func _test_replay_isolation(host: Node) -> void:
	PlayerState.reset()
	var live := Payload.normalize({
		"story_id": "sprite_live_fixture",
		"composition": [{"text": "Live progress"}],
		"_portrait_state": {"character_sprites": {"faye": "default"}},
	})
	PlayerState.set_pending_story(live)
	var reader = await _reader(host, {
		"story_id": "sprite_memory_fixture",
		"replay": true,
		"speaker_portraits": true,
		"composition": [{"speaker": "Magda", "text": "Memory variant", "sprite": "alt"}],
	}, true)
	assert(_speaker_texture(reader) == MAGDA_ALT and PlayerState.get_pending_story() == live)
	await reader._run_story_action({"type": "set_character_sprite", "character_id": "magda", "sprite": "default"})
	assert(_speaker_texture(reader) == MAGDA_DEFAULT, "Visual sprite actions must run during memories")
	PlayerState.save_progress()
	assert(PlayerState.get_pending_story() == live)
	reader.free()
	assert(PlayerState.pending_memory_replay.is_empty())
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	assert(PlayerState.get_pending_story() == live, "Memory sprites cannot overwrite live story state on disk")
