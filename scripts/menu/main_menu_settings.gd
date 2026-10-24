extends RefCounted

const AudioSettingsPanel := preload("res://scripts/ui/audio_settings_panel.gd")
const GENERIC_BUTTON_TEXTURE := preload("res://assets/ui/buttons/button_generic.png")
const MAIN_MENU_BGM_PATH := "res://assets/audio/music/story/peace.mp3"

# Builds menu audio/language controls and starts menu music.


static func build_audio_panel(owner) -> void:
	owner.audio_panel_refs = AudioSettingsPanel.create(
		owner,
		owner,
		owner.UI_FONT,
		Vector2(26.0, 84.0),
		Vector2(356.0, 222.0),
		"AUDIO SETTINGS"
	)
	var audio_panel = owner.audio_panel_refs.get("panel") as Panel
	if audio_panel:
		audio_panel.visible = false

	owner.audio_toggle_button = TextureButton.new()
	owner.audio_toggle_button.z_index = 10
	owner.audio_toggle_button.texture_normal = GENERIC_BUTTON_TEXTURE
	owner.audio_toggle_button.texture_pressed = GENERIC_BUTTON_TEXTURE
	owner.audio_toggle_button.texture_hover = GENERIC_BUTTON_TEXTURE
	owner.audio_toggle_button.texture_focused = GENERIC_BUTTON_TEXTURE
	owner.audio_toggle_button.ignore_texture_size = true
	owner.audio_toggle_button.stretch_mode = TextureButton.STRETCH_SCALE
	owner.audio_toggle_button.position = Vector2(26.0, 22.0)
	owner.audio_toggle_button.size = Vector2(240.0, 48.0)
	owner.audio_toggle_button.tooltip_text = "Toggle Audio Settings"
	owner.add_child(owner.audio_toggle_button)

	owner.audio_toggle_label = Label.new()
	owner.audio_toggle_label.anchor_right = 1.0
	owner.audio_toggle_label.anchor_bottom = 1.0
	owner.audio_toggle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.audio_toggle_label.text = "AUDIO"
	owner.audio_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner.audio_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner.audio_toggle_label.add_theme_font_override("font", owner.UI_FONT)
	owner.audio_toggle_label.add_theme_font_size_override("font_size", 14)
	owner.audio_toggle_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	owner.audio_toggle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	owner.audio_toggle_label.add_theme_constant_override("outline_size", 1)
	owner.audio_toggle_button.add_child(owner.audio_toggle_label)
	owner.ButtonGlow.attach(owner, owner.audio_toggle_button)
	owner.audio_toggle_button.pressed.connect(owner._toggle_audio_panel)


static func build_language_button(owner) -> void:
	owner.language_toggle_button = TextureButton.new()
	owner.language_toggle_button.z_index = 10
	owner.language_toggle_button.texture_normal = GENERIC_BUTTON_TEXTURE
	owner.language_toggle_button.texture_pressed = GENERIC_BUTTON_TEXTURE
	owner.language_toggle_button.texture_hover = GENERIC_BUTTON_TEXTURE
	owner.language_toggle_button.texture_focused = GENERIC_BUTTON_TEXTURE
	owner.language_toggle_button.ignore_texture_size = true
	owner.language_toggle_button.stretch_mode = TextureButton.STRETCH_SCALE
	owner.language_toggle_button.position = Vector2(26.0, 602.0)
	owner.language_toggle_button.size = Vector2(300.0, 48.0)
	owner.language_toggle_button.tooltip_text = "Toggle Story Language"
	owner.add_child(owner.language_toggle_button)

	owner.language_toggle_label = Label.new()
	owner.language_toggle_label.anchor_right = 1.0
	owner.language_toggle_label.anchor_bottom = 1.0
	owner.language_toggle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.language_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner.language_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner.language_toggle_label.add_theme_font_override("font", owner.UI_FONT)
	owner.language_toggle_label.add_theme_font_size_override("font_size", 14)
	owner.language_toggle_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	owner.language_toggle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	owner.language_toggle_label.add_theme_constant_override("outline_size", 1)
	owner.language_toggle_button.add_child(owner.language_toggle_label)
	owner.ButtonGlow.attach(owner, owner.language_toggle_button)
	owner.language_toggle_button.pressed.connect(owner._toggle_story_language)
	refresh_language_toggle_label(owner)


static func toggle_audio_panel(owner) -> void:
	var audio_panel = owner.audio_panel_refs.get("panel") as Panel
	if audio_panel == null:
		return
	audio_panel.visible = not audio_panel.visible
	owner.audio_toggle_label.text = "AUDIO  -" if audio_panel.visible else "AUDIO"


static func toggle_story_language(owner) -> void:
	StoryLanguageManager.toggle_language()
	refresh_language_toggle_label(owner)


static func refresh_language_toggle_label(owner) -> void:
	if owner.language_toggle_label == null:
		return
	owner.language_toggle_label.text = "LANG: %s" % StoryLanguageManager.get_language_label()


static func start_main_menu_bgm(owner) -> void:
	owner.bgm_player = AudioStreamPlayer.new()
	owner.bgm_player.name = "MainMenuBGMPlayer"
	owner.bgm_player.stream = load(MAIN_MENU_BGM_PATH)
	owner.bgm_player.autoplay = false
	owner.bgm_player.bus = &"Master"
	owner.add_child(owner.bgm_player)
	AudioSettingsManager.register_player(owner.bgm_player, "music")
	owner.bgm_player.play()
