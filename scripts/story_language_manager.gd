extends Node

signal language_changed(language: String)

const SETTINGS_PATH := "user://story_language.cfg"
const LANGUAGE_ENGLISH := "english"
const LANGUAGE_TAGALOG := "tagalog"
const LANGUAGES := [LANGUAGE_ENGLISH, LANGUAGE_TAGALOG]

var language := LANGUAGE_ENGLISH


func _ready() -> void:
	_load_settings()


func get_language() -> String:
	return language


func set_language(value: String) -> void:
	var safe_language := _normalize_language(value)
	if safe_language == language:
		return

	language = safe_language
	_save_settings()
	language_changed.emit(language)


func toggle_language() -> void:
	if language == LANGUAGE_ENGLISH:
		set_language(LANGUAGE_TAGALOG)
	else:
		set_language(LANGUAGE_ENGLISH)


func is_tagalog() -> bool:
	return language == LANGUAGE_TAGALOG


func get_language_label() -> String:
	if language == LANGUAGE_TAGALOG:
		return "TAGALOG"
	return "ENGLISH"


func _normalize_language(value: String) -> String:
	var safe_language := str(value).strip_edges().to_lower()
	if safe_language == "tl" or safe_language == "filipino":
		return LANGUAGE_TAGALOG
	if LANGUAGES.has(safe_language):
		return safe_language
	return LANGUAGE_ENGLISH


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		language = LANGUAGE_ENGLISH
		return

	language = _normalize_language(str(config.get_value("story", "language", LANGUAGE_ENGLISH)))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "language", language)
	config.save(SETTINGS_PATH)
