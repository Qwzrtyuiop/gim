extends RefCounted

const DialogueVoice := preload("res://scripts/story/story_dialogue_voice.gd")


static func run(host: Node) -> void:
	var voice := DialogueVoice.new()
	host.add_child(voice)
	voice.setup()
	assert(voice.player.get_parent() == voice)
	assert(voice.player.get_meta("audio_category") == "sfx")
	assert(voice.player.stream is AudioStreamWAV)
	var blip := voice.player.stream as AudioStreamWAV
	assert(blip.get_length() > 0.02 and blip.get_length() < 0.05)
	assert(blip.data.size() > 0 and blip.data != PackedByteArray())
	assert(blip.data.decode_s16(0) == 0 and absi(blip.data.decode_s16(blip.data.size() - 2)) < 50, "Both sample ends should fade to silence")
	assert(DialogueVoice.is_voiced_character("漢") and DialogueVoice.is_voiced_character("2"))
	voice.setup()
	assert(voice.get_child_count() == 1, "Repeated setup must not add overlapping voice players")

	voice.configure({"voice_every": 1, "voice_interval": 0.045, "voice_pitch": 1.3, "voice_volume_db": -24.0})
	assert(is_equal_approx(voice.player.pitch_scale, 1.3) and AudioSettingsManager.get_player_base_db(voice.player) == -24.0)
	for character in [" ", "\n", ".", "!", "…", "—", ",", "\"", "🙂"]:
		assert(not voice.play_character(character), "Whitespace and punctuation must not talk")
	assert(voice.play_character("ñ"), "Letters with accents must talk")
	assert(not voice.play_character("B"), "One frame cannot produce a catch-up burst")
	voice.tick(0.02)
	assert(not voice.play_character("B"), "Blips must respect their minimum interval")
	voice.tick(0.03)
	assert(voice.play_character("B"))
	for repeat in range(100):
		voice.tick(0.1)
		assert(voice.play_character("a"), "Short blips must safely retrigger without generator buffer errors")
	voice.stop()
	assert(not voice.player.playing)

	voice.configure({"voice_every": 2})
	assert(voice.play_character("A"))
	voice.tick(1.0)
	assert(not voice.play_character("B"))
	assert(voice.play_character("C"), "Voice cadence must count eligible letters rather than punctuation")
	voice.stop()
	voice.configure({"sound_enabled": false})
	assert(not voice.play_character("A") and not voice.player.playing)
	voice.configure({"voice_pitch": NAN, "voice_volume_db": INF, "voice_interval": -1.0, "voice_every": 0})
	assert(voice.voice_pitch == 1.0 and voice.voice_interval > 0.0 and voice.voice_every == 1)

	var previous_sfx: float = AudioSettingsManager.category_volumes.sfx
	var previous_master: float = AudioSettingsManager.category_volumes.master
	# Keep preference files untouched while checking the same live category values.
	AudioSettingsManager.category_volumes.sfx = 0.0
	assert(not voice.play_character("A"))
	AudioSettingsManager.category_volumes.sfx = previous_sfx
	AudioSettingsManager.category_volumes.master = 0.0
	assert(not voice.play_character("B"))
	AudioSettingsManager.category_volumes.master = previous_master
	voice.stop()
	voice.process_mode = Node.PROCESS_MODE_DISABLED
	assert(not voice.play_character("A"), "Disabled/paused dialogue must not emit new audio")
	voice.process_mode = Node.PROCESS_MODE_INHERIT

	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = blip.mix_rate
	clip.data = blip.data
	clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
	voice.configure({"voice_stream": clip})
	assert(voice.player.stream != clip and voice.player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	assert(clip.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Configuring voice must not mutate a shared source clip")
	voice.free()
	print("PASS: original dialogue blip audio, Unicode/punctuation cadence, pitch/volume, rate limits, mute/pause and isolated nonlooping clips")
