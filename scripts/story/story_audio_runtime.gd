extends RefCounted

# Story music, SFX, restoration, and volume transitions.

const StoryConditions := preload("res://scripts/story/story_conditions.gd")
const DEFAULT_MUSIC_FADE_SECONDS := 0.35


static func setup(owner) -> void:
	owner.bgm_player.autoplay = false
	owner.bgm_player.bus = &"Master"
	owner.sfx_player.autoplay = false
	owner.sfx_player.bus = &"Master"
	AudioSettingsManager.register_player(owner.bgm_player, "music")
	AudioSettingsManager.register_player(owner.sfx_player, "sfx")


static func restore_story_music_state(owner, resume_index: int) -> void:
	var last_music_action: Dictionary = {}
	var should_stop_music := false

	var payload_music_action := build_payload_music_action(owner)
	if not payload_music_action.is_empty():
		last_music_action = payload_music_action

	var capped_index := clampi(resume_index, 0, owner.story_lines.size())
	for line_index in range(capped_index):
		var line_data: Dictionary = owner.story_lines[line_index]
		if not StoryConditions.matches_story_conditions(line_data):
			continue
		var raw_actions: Array = line_data.get("actions", line_data.get("triggers", []))
		for action_data_variant in raw_actions:
			if not action_data_variant is Dictionary:
				continue
			var action_data: Dictionary = (action_data_variant as Dictionary).duplicate(true)
			if not StoryConditions.matches_story_conditions(action_data):
				continue
			var action_type := str(action_data.get("type", action_data.get("action", ""))).to_lower()
			match action_type:
				"play_music", "music_play":
					last_music_action = action_data
					should_stop_music = false
				"stop_music", "music_stop":
					last_music_action.clear()
					should_stop_music = true

	if should_stop_music:
		owner.bgm_player.stop()
		return

	if not last_music_action.is_empty():
		var restore_action := last_music_action.duplicate(true)
		restore_action["fade_in"] = 0.0
		restore_action["fade_out"] = 0.0
		restore_action["restart"] = true
		await play_music_action(owner, restore_action)


static func build_payload_music_action(owner) -> Dictionary:
	var payload_bgm = owner.story_payload.get("bgm", owner.story_payload.get("music", null))
	if payload_bgm == null:
		return {}
	if payload_bgm is Dictionary:
		return (payload_bgm as Dictionary).duplicate(true)

	var path := str(payload_bgm).strip_edges()
	if path.is_empty():
		return {}
	return {
		"type": "play_music",
		"path": path,
		"loop": bool(owner.story_payload.get("music_loop", owner.story_payload.get("bgm_loop", true))),
		"fade_in": float(owner.story_payload.get("music_fade_in", owner.story_payload.get("bgm_fade_in", DEFAULT_MUSIC_FADE_SECONDS))),
		"volume_db": float(owner.story_payload.get("music_volume_db", owner.story_payload.get("bgm_volume_db", 0.0))),
	}


static func resolve_audio_stream(stream_ref) -> AudioStream:
	if stream_ref is AudioStream:
		return stream_ref as AudioStream

	var stream_path := str(stream_ref)
	if stream_path.is_empty():
		return null
	if not ResourceLoader.exists(stream_path):
		return null

	var resource := load(stream_path)
	if resource is AudioStream:
		return resource as AudioStream
	return null


static func play_music_action(owner, action_data: Dictionary) -> void:
	var stream_ref = action_data.get("stream", action_data.get("path", action_data.get("music", null)))
	var stream := resolve_audio_stream(stream_ref)
	if stream == null:
		return
	owner.active_music_action = action_data.duplicate(true)

	var loop_enabled := bool(action_data.get("loop", action_data.get("loops", true)))
	var fade_in_duration := music_fade_in_duration(action_data)
	var fade_out_duration := float(action_data.get("fade_out", action_data.get("out_fade", fade_in_duration)))
	var target_volume_db := float(action_data.get("volume_db", 0.0))
	var effective_target_volume_db := AudioSettingsManager.resolve_effective_volume_db("music", target_volume_db)
	var restart := bool(action_data.get("restart", true))
	var configured_stream = configure_audio_stream_loop(stream, loop_enabled)
	var current_music_ref := str(owner.bgm_player.get_meta("music_ref", ""))
	var next_music_ref := music_ref_key(stream_ref, configured_stream)
	var current_loop_enabled := bool(owner.bgm_player.get_meta("loop_enabled", true))
	var should_swap_stream: bool = current_music_ref != next_music_ref or current_loop_enabled != loop_enabled or owner.bgm_player.stream == null
	var should_restart: bool = restart or should_swap_stream or not owner.bgm_player.playing

	if owner.bgm_player.playing and should_swap_stream and fade_out_duration > 0.0:
		await fade_audio_player_volume(owner, owner.bgm_player, fade_out_duration, owner.bgm_player.volume_db, AudioSettingsManager.SILENCE_DB)
		owner.bgm_player.stop()

	# Reassigning even the same track stops AudioStreamPlayer. Preserve playback
	# when a branch restates its music with restart=false.
	if should_swap_stream:
		owner.bgm_player.stream = configured_stream
	owner.bgm_player.set_meta("music_ref", next_music_ref)
	owner.bgm_player.set_meta("loop_enabled", loop_enabled)
	AudioSettingsManager.set_player_base_db(owner.bgm_player, target_volume_db)
	if should_restart:
		owner.bgm_player.volume_db = AudioSettingsManager.SILENCE_DB if fade_in_duration > 0.0 else effective_target_volume_db
		owner.bgm_player.play()
	if fade_in_duration > 0.0:
		await fade_audio_player_volume(owner, owner.bgm_player, fade_in_duration, owner.bgm_player.volume_db, effective_target_volume_db)
	else:
		AudioSettingsManager.apply_player_volume(owner.bgm_player)


static func music_fade_in_duration(action_data: Dictionary) -> float:
	if action_data.has("fade_in"):
		return float(action_data["fade_in"])
	if action_data.has("fade"):
		return float(action_data["fade"])
	if action_data.has("fade_out") or action_data.has("out_fade"):
		return 0.0
	return DEFAULT_MUSIC_FADE_SECONDS


static func stop_music_action(owner, action_data: Dictionary) -> void:
	owner.active_music_action.clear()
	if not owner.bgm_player.playing:
		return

	var fade_out_duration := float(action_data.get("fade_out", action_data.get("fade", DEFAULT_MUSIC_FADE_SECONDS)))
	if fade_out_duration > 0.0:
		await fade_audio_player_volume(owner, owner.bgm_player, fade_out_duration, owner.bgm_player.volume_db, AudioSettingsManager.SILENCE_DB)
	owner.bgm_player.stop()


static func play_sfx_action(owner, action_data: Dictionary) -> void:
	var stream_ref = action_data.get("stream", action_data.get("path", action_data.get("sfx", null)))
	var stream := resolve_audio_stream(stream_ref)
	if stream != null:
		owner.sfx_player.stream = configure_audio_stream_loop(stream, bool(action_data["loop"])) if action_data.has("loop") else stream
		var loops := false
		if owner.sfx_player.stream is AudioStreamWAV:
			loops = owner.sfx_player.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
		elif owner.sfx_player.stream is AudioStreamMP3 or owner.sfx_player.stream is AudioStreamOggVorbis:
			loops = owner.sfx_player.stream.loop
		owner.active_loop_sfx_action = action_data.duplicate(true) if loops else {}
		AudioSettingsManager.set_player_base_db(owner.sfx_player, float(action_data.get("volume_db", 0.0)))
		owner.sfx_player.play()
		return

	if bool(action_data.get("fallback_beep", true)):
		DisplayServer.beep()


static func stop_sfx_action(owner) -> void:
	owner.active_loop_sfx_action.clear()
	owner.sfx_player.stop()


static func configure_audio_stream_loop(stream: AudioStream, loop_enabled: bool) -> AudioStream:
	if stream == null:
		return null

	var configured_stream := stream.duplicate(true)
	if configured_stream == null:
		configured_stream = stream

	if configured_stream != null:
		var property_names: Dictionary = {}
		for property_info in configured_stream.get_property_list():
			property_names[str(property_info.get("name", ""))] = true
		for property_name in ["loop", "loop_enabled"]:
			if property_names.has(property_name):
				configured_stream.set(property_name, loop_enabled)
				break

	return configured_stream


static func music_ref_key(stream_ref, stream: AudioStream) -> String:
	if stream_ref is String:
		return str(stream_ref)
	if stream != null and not str(stream.resource_path).is_empty():
		return str(stream.resource_path)
	return str(stream_ref)


static func fade_audio_player_volume(owner, player: AudioStreamPlayer, duration: float, from_db: float, to_db: float) -> void:
	if player == null:
		return
	if owner.bgm_fade_tween:
		owner.bgm_fade_tween.kill()
	player.volume_db = from_db
	owner.bgm_fade_tween = owner.create_tween()
	owner.bgm_fade_tween.tween_property(player, "volume_db", to_db, duration)
	await owner.bgm_fade_tween.finished
	owner.bgm_fade_tween = null
