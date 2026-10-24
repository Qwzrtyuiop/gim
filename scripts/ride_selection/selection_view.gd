extends RefCounted

# Owns ride-selection presentation: cards, portraits, stats, controls, and music.

const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const RIDE_SELECT_DAY_BACKGROUND := preload("res://assets/story/backgrounds/locations/station.png")
const RIDE_SELECT_NIGHT_BACKGROUND := preload("res://assets/story/backgrounds/locations/station_night.png")
const GENERIC_PORTRAIT := preload("res://assets/characters/blankface.png")
const UNIQUE_CHARACTER_PORTRAITS := {
	"alma": preload("res://assets/characters/Alma.png"),
	"benny": preload("res://assets/characters/Benny.png"),
	"cel": preload("res://assets/characters/Celina.png"),
	"dante": preload("res://assets/characters/Dante.png"),
	"ely": preload("res://assets/characters/Elena.png"),
	"faye": preload("res://assets/characters/Magda.png"),
	"gardo": preload("res://assets/characters/Gardo.png"),
	"hana": preload("res://assets/characters/Hana.png"),
	"ito": preload("res://assets/characters/Isidro.png"),
	"jessa": preload("res://assets/characters/Jessa.png"),
}
const LOCKED_DISTANCE_MODULATE := Color(0.45, 0.45, 0.45, 1.0)
const RIDE_SELECT_BGM_PATH := "res://assets/audio/music/driving/normalstage1.mp3"
const RISK_DISTANCE_SCORES := {
	"short": 1,
	"medium": 2,
	"long": 3,
}
const RISK_TIME_SCORES := {
	"morning": 1,
	"noon": 2,
	"night": 3,
}
const RISK_TRAFFIC_SCORES := {
	"chill": 1,
	"normal": 2,
	"traffic-jam": 2,
	"trafficjam": 2,
	"speeders": 3,
	"speeder": 3,
	"busy": 4,
}

var screen
var stats_row_refs: Dictionary = {}
var portrait_images: Array[TextureRect] = []
var card_special_labels: Array[Label] = []
var bgm_player: AudioStreamPlayer
var store_button: TextureButton


func _init(selection_screen) -> void:
	screen = selection_screen


func prepare_controls() -> void:
	for label in [screen.card_a_label, screen.card_b_label, screen.card_c_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for button in [screen.back_button, screen.short_button, screen.medium_button, screen.long_button]:
		if screen._is_forced_first_day_ride() and button in [screen.medium_button, screen.long_button]:
			ButtonGlow.attach(screen, button, LOCKED_DISTANCE_MODULATE, LOCKED_DISTANCE_MODULATE)
		else:
			ButtonGlow.attach(screen, button)
	for button in [screen.short_button, screen.medium_button, screen.long_button]:
		for child in button.get_children():
			if child is Label:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_background() -> void:
	var next_time := PlayerState.get_next_stage_time(screen._transition_mode())
	screen.background.texture = RIDE_SELECT_NIGHT_BACKGROUND if next_time == "night" else RIDE_SELECT_DAY_BACKGROUND


func refresh_subtitle() -> void:
	var transition_mode: String = screen._transition_mode()
	var energy_bonus := PlayerState.get_transition_energy_bonus(transition_mode)
	var next_time := PlayerState.get_next_stage_time(transition_mode).capitalize()
	var bonus_text := " Recovery: +%d energy." % energy_bonus if energy_bonus > 0 else ""
	var route_phrase := "Choose a %s route for the %s trip.%s" if transition_mode == PlayerState.TRANSITION_CURRENT_STAGE else "Choose a %s route for the next %s trip.%s"
	screen.subtitle_label.text = route_phrase % [
		screen.selected_distance.capitalize(),
		next_time,
		bonus_text,
	]


func refresh_distance_buttons() -> void:
	for button_data in [
		{"button": screen.short_button, "id": "short"},
		{"button": screen.medium_button, "id": "medium"},
		{"button": screen.long_button, "id": "long"},
	]:
		var button := button_data["button"] as BaseButton
		var button_id: String = str(button_data["id"])
		var is_selected: bool = button_id == screen.selected_distance
		var is_locked: bool = screen._is_forced_first_day_ride() and button_id != "short"
		button.disabled = is_selected or is_locked
		button.tooltip_text = "Please select a short ride." if is_locked else ""
		if is_locked:
			ButtonGlow.set_state(screen, button, false, LOCKED_DISTANCE_MODULATE, LOCKED_DISTANCE_MODULATE)
		else:
			ButtonGlow.set_state(screen, button, is_selected)


func refresh_character_cards() -> void:
	var card_nodes := [
		{"panel": screen.card_a, "label": screen.card_a_label, "portrait": portrait_images[0], "special_label": card_special_labels[0]},
		{"panel": screen.card_b, "label": screen.card_b_label, "portrait": portrait_images[1], "special_label": card_special_labels[1]},
		{"panel": screen.card_c, "label": screen.card_c_label, "portrait": portrait_images[2], "special_label": card_special_labels[2]},
	]

	for index in range(card_nodes.size()):
		var character: Dictionary = screen.displayed_characters[index]
		var panel := card_nodes[index]["panel"] as Panel
		var label := card_nodes[index]["label"] as Label
		var portrait := card_nodes[index]["portrait"] as TextureRect
		var special_label := card_nodes[index]["special_label"] as Label
		if character.is_empty():
			panel.modulate = Color(0.92, 0.92, 0.92, 0.52)
			label.text = "EMPTY SLOT\nNo one available yet."
			if special_label != null:
				special_label.visible = false
			if portrait != null:
				portrait.visible = false
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			continue

		var preview_stage_type: String = screen.passenger_pool.preview_stage_type(character)
		var stage_special_display := _card_special_badge_text(str(character.get("stage_special_type", "")))
		panel.modulate = Color.WHITE
		label.text = "%s\nStage Information:\n%s\nEstimated Earnings:\nPhP %d\nGas Est: ~%.1f%%\nRisk: %s" % [
			PlayerState.get_character_display_name(str(character.get("id", ""))).to_upper(),
			preview_stage_type,
			PlayerState.estimate_stage_earnings(preview_stage_type, str(character.get("id", ""))),
			PlayerState.estimate_stage_gas_usage(preview_stage_type),
			_risk_label_for_stage_type(preview_stage_type),
		]
		if special_label != null:
			special_label.text = stage_special_display
			special_label.visible = not stage_special_display.is_empty()
		if portrait != null:
			portrait.texture = _portrait_for_character(character)
			portrait.visible = true
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	layout_card_special_labels()


func create_card_special_labels() -> void:
	card_special_labels.clear()
	for card_panel in [screen.card_a, screen.card_b, screen.card_c]:
		var special_label := Label.new()
		special_label.visible = false
		special_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		special_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		special_label.size = Vector2(120.0, 24.0)
		special_label.add_theme_font_override("font", UI_FONT)
		special_label.add_theme_font_size_override("font_size", 10)
		special_label.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84, 1.0))
		special_label.add_theme_color_override("font_outline_color", Color(0.24, 0.08, 0.02, 0.95))
		special_label.add_theme_constant_override("outline_size", 2)
		special_label.z_index = 3
		screen.get_node("Panel").add_child(special_label)
		card_special_labels.append(special_label)
	layout_card_special_labels()


func layout_card_special_labels() -> void:
	if card_special_labels.size() < 3:
		return
	var card_panels: Array[Panel] = [screen.card_a, screen.card_b, screen.card_c]
	for index in range(card_panels.size()):
		var card_panel: Panel = card_panels[index]
		var special_label: Label = card_special_labels[index]
		if card_panel == null or special_label == null:
			continue
		special_label.position = Vector2(
			card_panel.position.x + (card_panel.size.x - special_label.size.x) * 0.5,
			card_panel.position.y - special_label.size.y - 6.0
		)


func _card_special_badge_text(stage_special_type: String) -> String:
	match PlayerState.normalize_stage_special_type(stage_special_type):
		PlayerState.STAGE_SPECIAL_TYPE_URGENT:
			return "RUSH"
		PlayerState.STAGE_SPECIAL_TYPE_CAREFUL:
			return "CAREFUL"
		PlayerState.STAGE_SPECIAL_TYPE_SPECIAL:
			return "SPECIAL"
	return ""


func start_ride_select_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "RideSelectBGMPlayer"
	bgm_player.stream = load(RIDE_SELECT_BGM_PATH)
	bgm_player.autoplay = false
	bgm_player.bus = &"Master"
	screen.add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func create_portrait_images() -> void:
	portrait_images = []
	for panel in [screen.portrait_a_panel, screen.portrait_b_panel, screen.portrait_c_panel]:
		portrait_images.append(_ensure_portrait_image(panel))


func _ensure_portrait_image(panel: Panel) -> TextureRect:
	if panel == null:
		return null

	panel.clip_contents = true

	var portrait := panel.get_node_or_null("PortraitImage") as TextureRect
	if portrait == null:
		portrait = TextureRect.new()
		portrait.name = "PortraitImage"
		portrait.anchor_right = 1.0
		portrait.anchor_bottom = 1.0
		portrait.offset_left = 0.0
		portrait.offset_top = 0.0
		portrait.offset_right = 0.0
		portrait.offset_bottom = 0.0
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(portrait)

	portrait.texture = GENERIC_PORTRAIT
	return portrait


func _portrait_for_character(character: Dictionary) -> Texture2D:
	var character_id: String = str(character.get("id", "")).strip_edges().to_lower()
	return UNIQUE_CHARACTER_PORTRAITS.get(character_id, GENERIC_PORTRAIT)


func _risk_label_for_stage_type(stage_type: String) -> String:
	var score: int = _risk_score_for_stage_type(stage_type)
	if score <= 5:
		return "LOW"
	if score <= 7:
		return "MODERATE"
	return "HIGH"


func _risk_score_for_stage_type(stage_type: String) -> int:
	var parts: PackedStringArray = stage_type.split("-")
	if parts.size() < 3:
		return 3

	var difficulty: String = str(parts[0]).strip_edges().to_lower()
	var time_of_day: String = str(parts[1]).strip_edges().to_lower()
	var traffic: String = ""
	for index in range(2, parts.size()):
		if not traffic.is_empty():
			traffic += "-"
		traffic += str(parts[index]).strip_edges().to_lower()

	return (
		int(RISK_DISTANCE_SCORES.get(difficulty, 1))
		+ int(RISK_TIME_SCORES.get(time_of_day, 1))
		+ int(RISK_TRAFFIC_SCORES.get(traffic, 2))
	)


func create_store_button() -> void:
	# Keep shopping available now that home navigation uses room objects.
	store_button = screen.back_button.duplicate(0) as TextureButton
	store_button.name = "StoreButton"
	store_button.visible = true
	store_button.tooltip_text = "Store: upgrades, energy and gas"
	(store_button.get_node("BackLabel") as Label).text = "STORE"
	screen.get_node("Panel").add_child(store_button)
	screen.back_button.offset_left = 330.0
	screen.back_button.offset_right = 550.0
	store_button.offset_left = 608.0
	store_button.offset_right = 828.0
	store_button.pressed.connect(screen._open_store)
	ButtonGlow.attach(screen, store_button)


func refresh_action_button() -> void:
	screen.back_button.visible = screen._allow_back()
	screen.back_label.text = "BACK"


func create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 10,
		"font_color": Color(0.30, 0.19, 0.10, 1.0),
		"outline_color": Color(0.98, 0.94, 0.83, 0.86),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.layout_mode = 1
	stats_row.offset_left = 90.0
	stats_row.offset_top = 118.0
	stats_row.offset_right = 1064.0
	stats_row.offset_bottom = 144.0
	screen.get_node("Panel").add_child(stats_row)


func refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)
