extends Control

const StoreItems := preload("res://scripts/store/store_items.gd")
const StoreTutorial := preload("res://scripts/store/store_tutorial.gd")

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
var store_item_rows: Array[Control] = []
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


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/store.tscn")
	PlayerState.ensure_daily_conditions_for_current_day()
	_create_stats_row()
	_create_street()
	back_button.pressed.connect(_close_shop)
	ButtonGlow.attach(self, back_button)
	_start_store_bgm()
	_build_items()
	_refresh_header()
	_build_tutorial()
	resized.connect(_layout_store)
	_layout_store()
	if not PlayerState.has_store_tutorial_shown():
		call_deferred("_start_tutorial")


func _input(event: InputEvent) -> void:
	if tutorial_active and _is_any_press(event):
		# The overlay consumes GUI clicks before they reach _unhandled_input.
		# Consume the press here so the final step cannot also buy or navigate.
		get_viewport().set_input_as_handled()
		_advance_tutorial()
	elif shop_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_active or is_transitioning:
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
	var margin := size.x * 0.04
	var gap := size.x * 0.025
	var available_width := size.x - margin * 2 - gap
	var owner_width := available_width * 0.28
	owner_panel.position = Vector2(margin, HubStatusHeader.CONTENT_TOP)
	owner_panel.size = Vector2(owner_width, size.y - HubStatusHeader.CONTENT_TOP - 32)
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
	if tutorial_active or shop_overlay.visible or is_transitioning:
		return
	match action:
		"home": _go_home()
		"station": _ride()
		"tricycle", "food": _open_shop(action)


func _open_shop(category: String) -> void:
	active_category = category
	for index in range(store_item_rows.size()):
		var item: Dictionary = StoreItemCatalog.ITEMS[index]
		store_item_rows[index].visible = (item["type"] in ["upgrade", "gas"]) if category == "tricycle" else item["type"] == "energy"
	shop_overlay.get_node("Title").text = "LITO'S AUTO SUPPLY" if category == "tricycle" else "MANG EDDIE'S"
	_refresh_owner_portrait()
	(shop_overlay.get_node("ItemScroll") as ScrollContainer).scroll_vertical = 0
	status_label.text = "Choose an item."
	_refresh_header()
	street.set_enabled(false)
	shop_overlay.show()
	_layout_store()
	back_button.grab_focus()


func _refresh_owner_portrait() -> void:
	owner_portrait.texture = null
	var config: Dictionary = GameTuning.STORE_OWNER_PORTRAITS.get(active_category, {})
	owner_portrait.flip_h = bool(config.get("flip_h", false))
	var path := str(config.get("path", "")).strip_edges()
	if not path.is_empty() and ResourceLoader.exists(path):
		owner_portrait.texture = load(path) as Texture2D
	owner_portrait.visible = owner_portrait.texture != null


func _close_shop() -> void:
	shop_overlay.hide()
	back_button.release_focus()
	for button in store_buy_buttons:
		button.release_focus()
	active_category = ""
	street.set_enabled(not tutorial_active and not is_transitioning)


func _build_items() -> void:
	StoreItems.build_items(self)


func _buy_item(item: Dictionary, label: RichTextLabel, tier_container: HBoxContainer, button: Button) -> void:
	await StoreItems.buy_item(self, item, label, tier_container, button)


func _refresh_header() -> void:
	_refresh_stats_row()
	money_label.text = "Gas Price: %s / %s%%" % [
		PlayerState.get_gas_price_text(),
		String.num(PlayerState.GAS_CAN_PERCENT).trim_suffix(".0"),
	]
	if active_category == "food":
		money_label.text = "Food and energy"


func _start_store_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "StoreBGMPlayer"
	bgm_player.stream = load(STORE_BGM_PATH)
	bgm_player.bus = "Master"
	bgm_player.autoplay = false
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func _ride() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	street.set_enabled(false)
	PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _go_home() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	street.set_enabled(false)
	# Visiting home does not consume the current time slot or reroll its passengers.
	PlayerState.set_pending_trip_selection(HOME_SCENE, PlayerState.get_home_ride_transition_mode())
	get_tree().change_scene_to_file(HOME_SCENE)


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
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FAIL_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
