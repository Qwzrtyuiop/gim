extends Control

# Shared location shop modal. Subclasses supply their catalog and presentation;
# HomeMap owns the visit, input priority and music.
signal closed

const StoreItems := preload("res://scripts/store/store_items.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const CONTENT_SIZE := Vector2(1180, 600)

var can_shop: Callable
var shop_overlay: Control
var active_category := ""
var tutorial_active := false
var is_transitioning := false
var store_item_rows: Array[Control] = []
var store_item_labels: Array[RichTextLabel] = []
var store_buy_buttons: Array[BaseButton] = []
var content_root: Control
var panel: Panel
var owner_panel: Panel
var owner_portrait: TextureRect
var title_label: Label
var money_label: Label
var status_label: Label
var item_scroll: ScrollContainer
var item_list: VBoxContainer
var back_button: Button
var _buying := false


func _init() -> void:
	hide()


func _ready() -> void:
	name = _shop_node_name()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	shop_overlay = self
	_build_interface()
	StoreItems.build_items(self)
	PlayerState.money_changed.connect(_on_resources_changed)
	PlayerState.stress_changed.connect(_on_resources_changed)
	PlayerState.energy_changed.connect(_on_resources_changed)
	PlayerState.stress_shield_changed.connect(_on_resources_changed)
	resized.connect(_layout)
	_refresh_header()
	_layout()


func open() -> bool:
	if not is_inside_tree() or is_transitioning or not _shopping_allowed():
		return false
	StoreItems.refresh_items(self)
	_refresh_header()
	status_label.text = _shop_prompt()
	item_scroll.scroll_vertical = 0
	show()
	_layout()
	back_button.grab_focus()
	return true


func close() -> void:
	if not visible:
		return
	hide()
	back_button.release_focus()
	for button: BaseButton in store_buy_buttons:
		button.release_focus()
	closed.emit()


func _shopping_allowed() -> bool:
	return not can_shop.is_valid() or bool(can_shop.call())


func _buy_item(item: Dictionary, label: RichTextLabel, tiers: HBoxContainer, button: Button) -> void:
	if _buying or not is_visible_in_tree() or is_transitioning or tutorial_active or not _shopping_allowed():
		return
	_buying = true
	await StoreItems.buy_item(self, item, label, tiers, button)
	_buying = false


func _on_resources_changed(_value) -> void:
	StoreItems.refresh_items(self)
	_refresh_header()


func _refresh_header() -> void:
	money_label.text = _shop_header()


func _shop_node_name() -> String:
	return "LocationShop"


func _shop_title() -> String:
	return "SHOP"


func _shop_prompt() -> String:
	return "Choose an item."


func _shop_portrait() -> Texture2D:
	return null


func _shop_header() -> String:
	return "Money: PhP %d    Stress: %d/%d" % [PlayerState.money, PlayerState.stress, PlayerState.max_stress]


func _fade_to_scene(scene_path: String) -> void:
	# Compatibility with StoreItems' existing run-failure handoff.
	is_transitioning = true
	for button: BaseButton in store_buy_buttons:
		button.disabled = true
	back_button.disabled = true
	get_tree().change_scene_to_file(scene_path)


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	content_root = Control.new()
	content_root.name = "Content"
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_root)
	owner_panel = _panel("OwnerPanel", Rect2(0, 0, 300, 600))
	owner_panel.clip_contents = true
	owner_portrait = TextureRect.new()
	owner_portrait.name = "OwnerPortrait"
	owner_portrait.texture = _shop_portrait()
	owner_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_panel.add_child(owner_portrait)
	owner_portrait.position = Vector2(12, 12)
	owner_portrait.size = Vector2(276, 576)
	panel = _panel("Panel", Rect2(328, 0, 852, 600))
	title_label = _label("Title", _shop_title(), 20)
	title_label.position = Vector2(352, 16)
	title_label.size = Vector2(620, 44)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label = _label("MoneyLabel", "", 12)
	money_label.position = Vector2(352, 76)
	money_label.size = Vector2(804, 32)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_scroll = ScrollContainer.new()
	item_scroll.name = "ItemScroll"
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.follow_focus = true
	content_root.add_child(item_scroll)
	item_scroll.position = Vector2(352, 124)
	item_scroll.size = Vector2(804, 380)
	item_list = VBoxContainer.new()
	item_list.name = "ItemList"
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 12)
	item_scroll.add_child(item_list)
	status_label = _label("StatusLabel", _shop_prompt(), 12)
	status_label.position = Vector2(352, 524)
	status_label.size = Vector2(804, 52)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = Button.new()
	back_button.name = "CloseButton"
	back_button.text = "CLOSE"
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	StoreItems.apply_button_font(self, back_button)
	StoreItems.apply_store_buy_button_style(self, back_button)
	content_root.add_child(back_button)
	back_button.position = Vector2(996, 14)
	back_button.size = Vector2(160, 46)
	back_button.pressed.connect(close)
	UIAudioManager.attach_button(back_button)


func _panel(node_name: String, rect: Rect2) -> Panel:
	var control := Panel.new()
	control.name = node_name
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.90, 0.82, 0.92)
	style.border_color = Color(0.38, 0.23, 0.13, 0.90)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	control.add_theme_stylebox_override("panel", style)
	content_root.add_child(control)
	control.position = rect.position
	control.size = rect.size
	return control


func _label(node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.10, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.98, 0.94, 0.82, 0.95))
	label.add_theme_constant_override("outline_size", 1)
	content_root.add_child(label)
	return label


func _layout() -> void:
	if content_root == null:
		return
	var available := (size - Vector2(40, 40)).max(Vector2.ONE)
	var fit := minf(1.0, minf(available.x / CONTENT_SIZE.x, available.y / CONTENT_SIZE.y))
	content_root.size = CONTENT_SIZE
	content_root.scale = Vector2.ONE * fit
	content_root.position = (size - CONTENT_SIZE * fit) * 0.5


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		close()
