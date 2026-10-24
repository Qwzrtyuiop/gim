extends Node

# Animates existing Label visibility; gameplay effects stay in the story's action cursor.
signal finished

const Settings := preload("res://scripts/config/story_dialogue_settings.gd")
const DialogueVoice := preload("res://scripts/story/story_dialogue_voice.gd")

var label: Label
var voice: Node
var active := false
var settings: Dictionary = {}
var boundaries := PackedInt32Array()
var next_character := 0
var elapsed := 0.0
var next_delay := 0.0


func setup(body_label: Label) -> void:
	label = body_label
	voice = DialogueVoice.new()
	voice.name = "DialogueVoice"
	add_child(voice)
	voice.setup()
	# Shape the whole line first so words do not jump to another line while typing.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	set_process(false)


func start(payload: Dictionary, line: Dictionary, speaker: String) -> void:
	cancel()
	settings = Settings.resolve(payload, line, speaker)
	boundaries = TextServerManager.get_primary_interface().string_get_character_breaks(label.text)
	# Behavior-focused regressions opt out explicitly; this is never set by gameplay.
	var instant_test := bool(ProjectSettings.get_setting("testing/instant_story_text", false))
	if not settings.enabled or instant_test or boundaries.is_empty() or not label.is_visible_in_tree():
		label.visible_characters = -1
		return
	next_character = 0
	elapsed = 0.0
	next_delay = 1.0 / float(settings.characters_per_second)
	label.visible_characters = 0
	voice.configure(settings)
	active = true
	set_process(true)


func _process(delta: float) -> void:
	if not active:
		return
	if not label.is_visible_in_tree():
		finish_now()
		return
	voice.tick(delta)
	elapsed += maxf(0.0, delta)
	while active and elapsed >= next_delay:
		elapsed -= next_delay
		var start_index := 0 if next_character == 0 else int(boundaries[next_character - 1])
		var end_index := int(boundaries[next_character])
		var character := label.text.substr(start_index, end_index - start_index)
		label.visible_characters = end_index
		voice.play_character(character)
		next_character += 1
		if next_character >= boundaries.size():
			active = false
			set_process(false)
			label.visible_characters = -1
			finished.emit()
			return
		next_delay = 1.0 / float(settings.characters_per_second)
		if character in [".", ",", "!", "?", ";", ":", "…", "。", "，", "！", "？", "\n"]:
			next_delay += float(settings.punctuation_pause)


func wait_until_finished() -> void:
	if active:
		await finished


func finish_now() -> bool:
	if not active:
		return false
	active = false
	set_process(false)
	label.visible_characters = -1
	voice.stop()
	finished.emit()
	return true


func cancel() -> void:
	# Replacing/hiding text must not release a waiting old line into its next scene.
	active = false
	set_process(false)
	if is_instance_valid(label):
		label.visible_characters = -1
	if is_instance_valid(voice):
		voice.stop()
