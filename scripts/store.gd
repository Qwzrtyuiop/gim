extends Control

const StoreItems := preload("res://scripts/store/store_items.gd")
const StoreTutorial := preload("res://scripts/store/store_tutorial.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const HubNightAmbience := preload("res://scripts/ui/hub_night_ambience.gd")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const DialogueAnchors := preload("res://scripts/ui/hub_dialogue_anchors.gd")
const HomeMap := preload("res://scripts/home/home_map.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")

const GameTuning := preload("res://scripts/config/game_tuning.gd")

const STORE_SCENE := "res://scenes/store.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const STORE_BGM_PATH := "res://assets/audio/music/menus/store.mp3"
const FAIL_FADE_SECONDS := 0.35
const StoreItemCatalog := preload("res://scripts/store/store_item_catalog.gd")
const StoreStreetView := preload("res://scripts/ui/store_street_view.gd")

@onready var money_label: Label = $MoneyLabel
@onready var status_label: Label = $StatusLabel
@onready var item_list: VBoxContainer = $ItemScroll/ItemList
@onready var back_button: BaseButton = $BackButton
@onready var back_label: Label = $BackButton/BackLabel
@onready var ride_button: BaseButton = $RideButton
@onready var fade_overlay: ColorRect = $FadeOverlay

var stats_row_refs: Dictionary = {}
var status_header: PanelContainer
var bgm_player: AudioStreamPlayer
var night_ambience: HubNightAmbience
var store_item_rows: Array[Control] = []
var store_item_labels: Array[RichTextLabel] = []
var store_buy_buttons: Array[BaseButton] = []
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var tutorial_disabled_controls: Dictionary = {}
var street: Control
var shop_overlay: ColorRect
var owner_panel: Panel
var owner_portrait: TextureRect
var active_category := ""
var is_transitioning := false
var hub_dialogue: HubDialogue
var travel_map: HomeMap
var map_button: Button


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/store.tscn")
	PlayerState.ensure_daily_conditions_for_current_day()
	_create_stats_row()
	_create_street()
	_create_hub_dialogue()
	_create_map()
	night_ambience = AmbientAudioManager
	AmbientAudioManager.enter_hub()
	back_button.pressed.connect(_close_shop)
	ButtonGlow.attach(self, back_button)
	_start_store_bgm()
	_build_items()
	PlayerState.money_changed.connect(_on_store_resources_changed)
	PlayerState.energy_changed.connect(_on_store_resources_changed)
	PlayerState.stress_changed.connect(_on_store_resources_changed)
	PlayerState.hull_changed.connect(_on_store_resources_changed)
	PlayerState.gas_changed.connect(_on_store_resources_changed)
	_refresh_header()
	_build_tutorial()
	resized.connect(_layout_store)
	_layout_store()
	if not PlayerState.has_store_tutorial_shown():
		call_deferred("_start_tutorial")


func _input(event: InputEvent) -> void:
	if travel_map != null and travel_map.visible:
		return
	if tutorial_active and _is_any_press(event):
		# The overlay consumes GUI clicks before they reach _unhandled_input.
		# Consume the press here so the final step cannot also buy or navigate.
		get_viewport().set_input_as_handled()
		_advance_tutorial()
	elif hub_dialogue != null and hub_dialogue.handle_input(event):
		get_viewport().set_input_as_handled()
	elif shop_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_active or is_transitioning or _speech_is_blocking() or (travel_map != null and travel_map.visible):
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return


func _create_street() -> void:
	$Background.hide()
	$Shade.hide()
	ride_button.hide()
	street = StoreStreetView.new()
	add_child(street)
	move_child(street, 0)
	street.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	street.action_pressed.connect(_on_street_action)
	shop_overlay = ColorRect.new()
	shop_overlay.name = "ShopOverlay"
	shop_overlay.color = Color(0, 0, 0, 0.55)
	shop_overlay.z_index = 10
	add_child(shop_overlay)
	shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			_close_shop()
	)
	for node in [$Panel, $Title, money_label, $ItemScroll, status_label, back_button]:
		node.reparent(shop_overlay, false)
	shop_overlay.get_node("Panel").mouse_filter = Control.MOUSE_FILTER_STOP
	owner_panel = Panel.new()
	owner_panel.name = "OwnerPanel"
	owner_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	owner_panel.clip_contents = true
	owner_panel.add_theme_stylebox_override("panel", shop_overlay.get_node("Panel").get_theme_stylebox("panel").duplicate())
	shop_overlay.add_child(owner_panel)
	owner_portrait = TextureRect.new()
	owner_portrait.name = "OwnerPortrait"
	owner_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_panel.add_child(owner_portrait)
	back_label.text = "CLOSE"
	back_button.tooltip_text = "Return to the street"
	back_button.custom_minimum_size = Vector2.ZERO
	money_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	shop_overlay.hide()
	fade_overlay.z_index = 300


func _layout_store() -> void:
	status_header.layout_in(size)
	_layout_map_button()
	var margin := size.x * 0.04
	var gap := size.x * 0.025
	var available_width := size.x - margin * 2 - gap
	var owner_width := available_width * 0.28
	owner_panel.position = Vector2(margin, HubStatusHeader.CONTENT_TOP)
	owner_panel.size = Vector2(owner_width, maxf(48.0, size.y - HubStatusHeader.CONTENT_TOP - 32.0))
	owner_portrait.position = Vector2(12, 12)
	owner_portrait.size = owner_panel.size - Vector2(24, 24)
	var panel_rect := Rect2(margin + owner_width + gap, HubStatusHeader.CONTENT_TOP, available_width - owner_width, size.y - HubStatusHeader.CONTENT_TOP - 32)
	var title := shop_overlay.get_node("Title") as Label
	title.label_settings.font_size = 16 if size.x >= 1100 else 12
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.label_settings.font_size = 11
	money_label.label_settings.font_size = 11
	var placements := {
		"Panel": panel_rect,
		"Title": Rect2(panel_rect.position + Vector2(132, 14), Vector2(panel_rect.size.x - 264, 42)),
		"MoneyLabel": Rect2(panel_rect.position + Vector2(24, 62), Vector2(panel_rect.size.x - 48, 36)),
		"ItemScroll": Rect2(panel_rect.position + Vector2(24, 110), panel_rect.size - Vector2(48, 166)),
		"StatusLabel": Rect2(panel_rect.position + Vector2(24, panel_rect.size.y - 50), Vector2(panel_rect.size.x - 48, 44)),
		"BackButton": Rect2(panel_rect.position + Vector2(panel_rect.size.x - 132, 0), Vector2(120, 74)),
	}
	for node_name: String in placements:
		var control := shop_overlay.get_node(node_name) as Control
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.position = placements[node_name].position
		control.size = placements[node_name].size
	if tutorial_active:
		_show_tutorial_step(tutorial_step_index)


func _on_street_action(action: String) -> void:
	if tutorial_active or shop_overlay.visible or is_transitioning or _speech_is_blocking() or (travel_map != null and travel_map.visible):
		return
	match action:
		"home", "map": _open_map()
		"station": _ride()
		"tricycle", "food": _open_shop(action)


func _open_shop(category: String) -> void:
	if _speech_is_blocking() or (travel_map != null and travel_map.visible):
		return
	if PlayerState.is_midnight():
		show_message("It's closed.", {
			"target": category,
			"speaker": "John Toda",
			"show_tail": false,
			"duration": 2.5,
			"blocking": false,
		})
		return
	hub_dialogue.clear()
	active_category = category
	for index in range(store_item_rows.size()):
		var item: Dictionary = StoreItemCatalog.ITEMS[index]
		store_item_rows[index].visible = (item["type"] in ["upgrade", "gas", "repair"]) if category == "tricycle" else item["type"] == "stress_relief"
	shop_overlay.get_node("Title").text = "LITO'S AUTO SUPPLY" if category == "tricycle" else "MANG EDDIE'S"
	_refresh_owner_portrait()
	(shop_overlay.get_node("ItemScroll") as ScrollContainer).scroll_vertical = 0
	status_label.text = "Choose an item."
	StoreItems.refresh_items(self)
	_refresh_header()
	street.set_enabled(false)
	shop_overlay.show()
	_layout_map_button()
	_refresh_store_bgm()
	AmbientAudioManager.set_rain_indoors(true)
	_layout_store()
	back_button.grab_focus()
	_show_shop_greeting()


func _refresh_owner_portrait() -> void:
	owner_portrait.texture = null
	var config: Dictionary = GameTuning.STORE_OWNER_PORTRAITS.get(active_category, {})
	owner_portrait.flip_h = bool(config.get("flip_h", false))
	var path := str(config.get("path", "")).strip_edges()
	if not path.is_empty() and ResourceLoader.exists(path):
		owner_portrait.texture = load(path) as Texture2D
	owner_portrait.visible = owner_portrait.texture != null


func _close_shop() -> void:
	if _speech_is_blocking():
		return
	hub_dialogue.clear()
	shop_overlay.hide()
	AmbientAudioManager.set_rain_indoors(false)
	back_button.release_focus()
	for button in store_buy_buttons:
		button.release_focus()
	active_category = ""
	street.set_enabled(not tutorial_active and not is_transitioning)
	_layout_map_button()
	if is_instance_valid(bgm_player):
		_refresh_store_bgm()


func _build_items() -> void:
	StoreItems.build_items(self)


func _on_store_resources_changed(_value) -> void:
	StoreItems.refresh_items(self)


func _buy_item(item: Dictionary, label: RichTextLabel, tier_container: HBoxContainer, button: Button) -> void:
	if PlayerState.is_midnight() or tutorial_active or not shop_overlay.visible or is_transitioning or _speech_is_blocking():
		return
	await StoreItems.buy_item(self, item, label, tier_container, button)
	if not is_transitioning and shop_overlay.visible and not PlayerState.is_run_failed():
		_show_shop_feedback(status_label.text)


func _refresh_header() -> void:
	_refresh_stats_row()
	street.set_night(PlayerState.get_current_time_of_day() == "night")
	street.set_midnight(PlayerState.is_midnight())
	street.set_weather(PlayerState.get_current_weather())
	if PlayerState.is_midnight():
		if tutorial_active:
			StoreTutorial.end_tutorial(self)
		if shop_overlay.visible:
			hub_dialogue.clear()
			_close_shop()
	night_ambience.refresh()
	_refresh_store_bgm()
	money_label.text = "Gas Price: %s / %s%%" % [
		PlayerState.get_gas_price_text(),
		String.num(PlayerState.GAS_CAN_PERCENT).trim_suffix(".0"),
	]
	if active_category == "food":
		money_label.text = "Food and stress relief"


func _start_store_bgm() -> void:
	_refresh_store_bgm()


func _refresh_store_bgm() -> void:
	var path: String = HubMusicManager.background_path()
	if path != HubMusicManager.RAINY_NIGHT_PATH and shop_overlay.visible and active_category == "tricycle":
		path = STORE_BGM_PATH
	var bar_active: bool = travel_map != null and travel_map.bar_audio != null and travel_map.bar_audio.active
	bgm_player = HubMusicManager.request_track(
		path,
		RainAudioProfile.music_duck_db(PlayerState.get_current_weather()),
		PlayerState.is_midnight() or bar_active,
	)


func _ride() -> void:
	if is_transitioning or _speech_is_blocking() or (travel_map != null and travel_map.visible):
		return
	hub_dialogue.clear()
	is_transitioning = true
	street.set_enabled(false)
	map_button.hide()
	PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
	PlayerState.set_pending_pickup_location("station")
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _go_home() -> void:
	_open_map()


func _create_map() -> void:
	map_button = Button.new()
	map_button.name = "StoreMapButton"
	map_button.text = "MAP"
	DashboardTheme.apply_button(map_button)
	map_button.pressed.connect(_open_map)
	add_child(map_button)
	UIAudioManager.attach_button(map_button)
	travel_map = HomeMap.new()
	travel_map.name = "StoreMap"
	add_child(travel_map)
	travel_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_map.closed.connect(_close_map)
	travel_map.destination_requested.connect(_map_departure)
	travel_map.bar_music_changed.connect(_refresh_store_bgm)
	shop_overlay.visibility_changed.connect(_layout_map_button)
	_layout_map_button()


func _open_map() -> void:
	if is_transitioning or tutorial_active or shop_overlay.visible or travel_map.visible or _speech_is_blocking():
		return
	hub_dialogue.clear()
	street.set_enabled(false)
	map_button.hide()
	status_header.hide()
	travel_map.open("store")
	AmbientAudioManager.enter_hub(false)
	_refresh_store_bgm()


func _close_map() -> void:
	street.set_enabled(not is_transitioning and not tutorial_active and not shop_overlay.visible)
	status_header.refresh()
	status_header.show()
	_layout_map_button()
	if not is_transitioning and map_button.visible:
		map_button.grab_focus()
	AmbientAudioManager.enter_hub(false)
	_refresh_store_bgm()


func _map_departure(scene_path: String) -> void:
	if is_transitioning:
		return
	hub_dialogue.clear()
	is_transitioning = true
	street.set_enabled(false)
	map_button.hide()
	# The map has already chosen the pickup area; keep its locked offers.
	PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
	get_tree().change_scene_to_file(scene_path)


func _layout_map_button() -> void:
	if map_button == null:
		return
	map_button.position = Vector2(20.0, size.y - DashboardTheme.BUTTON_SIZE.y - 16.0)
	map_button.size = DashboardTheme.BUTTON_SIZE
	map_button.visible = not is_transitioning and not shop_overlay.visible and (travel_map == null or not travel_map.visible)


func _item_cost(item: Dictionary) -> int:
	return StoreItems.item_cost(self, item)


func _create_stats_row() -> void:
	status_header = HubStatusHeader.new()
	add_child(status_header)
	stats_row_refs = status_header.stats_refs


func _selection_transition_mode() -> String:
	var pending_selection := PlayerState.get_pending_trip_selection()
	return PlayerState.normalize_transition_mode(str(pending_selection.get("transition_mode", PlayerState.TRANSITION_RIDE)))


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	status_header.refresh()


func _build_tutorial() -> void:
	StoreTutorial.build_tutorial(self)


func _start_tutorial() -> void:
	StoreTutorial.start_tutorial(self)


func _advance_tutorial() -> void:
	StoreTutorial.advance_tutorial(self)


func _show_tutorial_step(step_index: int) -> void:
	StoreTutorial.show_tutorial_step(self, step_index)


func _is_any_press(event: InputEvent) -> bool:
	return StoreTutorial.is_any_press(self, event)


func _fade_to_scene(scene_path: String) -> void:
	hub_dialogue.clear()
	is_transitioning = true
	street.set_enabled(false)
	map_button.hide()
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FAIL_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _create_hub_dialogue() -> void:
	hub_dialogue = HubDialogue.new()
	hub_dialogue.name = "HubDialogue"
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.set_gate(func() -> bool:
		return not tutorial_active and not is_transitioning and (travel_map == null or not travel_map.visible)
	)
	hub_dialogue.register_target("lito", _store_message_target.bind("tricycle"))
	hub_dialogue.register_target("eddie", _store_message_target.bind("food"))
	hub_dialogue.register_target("shopkeeper", _active_shop_message_target)
	for action in ["map", "station", "tricycle", "food"]:
		hub_dialogue.register_target(action, _street_message_target.bind(action))


func _store_message_target(category: String) -> Rect2:
	return DialogueAnchors.store_owner(self, category)


func _active_shop_message_target() -> Rect2:
	return _store_message_target(active_category) if not active_category.is_empty() else Rect2()


func _street_message_target(action: String) -> Rect2:
	if shop_overlay.visible:
		return Rect2()
	return DialogueAnchors.image_region(street, street.REGIONS.get(action, Rect2()))


func _show_shop_greeting() -> void:
	var greeting := {
		"english": "Need gas, parts, or repairs? Take a look.",
		"tagalog": "Kailangan mo ng gasolina, piyesa, o pagkukumpuni? Tingin ka lang.",
	} if active_category == "tricycle" else {
		"english": "Take a break. What would you like?",
		"tagalog": "Pahinga ka muna. Ano ang sa iyo?",
	}
	show_message(greeting, {
		"target": "shopkeeper",
		"speaker": "Lito" if active_category == "tricycle" else "Shopkeeper",
		"duration": 4.0,
	})


func _show_shop_feedback(text: String) -> void:
	show_message(text, {
		"target": "shopkeeper",
		"speaker": "Lito" if active_category == "tricycle" else "Shopkeeper",
		"duration": 3.0,
	})


func show_message(text: Variant, options: Dictionary = {}) -> bool:
	return hub_dialogue.say(text, _store_message_options(options)) if hub_dialogue != null else false


func show_messages(lines: Array, options: Dictionary = {}) -> bool:
	if hub_dialogue == null:
		return false
	var prepared: Array = []
	for value in lines:
		var line := options.duplicate(true)
		if value is String:
			line["text"] = value
		elif value is Dictionary:
			line.merge(value, true)
		else:
			return false
		prepared.append(_store_message_options(line))
	return hub_dialogue.play(prepared)


func _store_message_options(options: Dictionary) -> Dictionary:
	var adjusted := options.duplicate(true)
	var target := str(adjusted.get("target", ""))
	var matches_owner := target == "shopkeeper" or (target == "lito" and active_category == "tricycle") or (target == "eddie" and active_category == "food")
	if shop_overlay != null and shop_overlay.visible and matches_owner:
		if not adjusted.has("side"):
			adjusted["side"] = "below"
		if not adjusted.has("width"):
			adjusted["width"] = minf(380, owner_panel.size.x + 24)
	return adjusted


func _speech_is_blocking() -> bool:
	return hub_dialogue != null and hub_dialogue.blocks_input()
