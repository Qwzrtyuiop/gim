extends Control

signal confirmed
signal cancelled

const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PANEL_WIDTH := 580.0

var panel: PanelContainer
var heading_label: Label
var cost_label: Label
var confirm_button: Button
var cancel_button: Button
var _submitted := false


func _init() -> void:
	hide()


func _ready() -> void:
	name = "MapTravelConfirmation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.012, 0.008, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b150e")
	style.border_color = Color("c4a16a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)
	heading_label = _label(16, Color("faefd5"))
	cost_label = _label(12, Color("d7bc8c"))
	content.add_child(heading_label)
	content.add_child(cost_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	content.add_child(actions)
	cancel_button = _button("CANCEL", actions)
	confirm_button = _button("GO", actions)
	cancel_button.pressed.connect(_cancel)
	confirm_button.pressed.connect(_confirm)
	for direction in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		cancel_button.set_focus_neighbor(direction, cancel_button.get_path_to(confirm_button))
		confirm_button.set_focus_neighbor(direction, confirm_button.get_path_to(cancel_button))
	cancel_button.focus_next = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_previous = cancel_button.focus_next
	confirm_button.focus_next = confirm_button.get_path_to(cancel_button)
	confirm_button.focus_previous = confirm_button.focus_next
	resized.connect(_layout)
	dismiss()


func present(destination_name: String, energy_cost: int) -> void:
	_submitted = false
	heading_label.text = "Go to %s?" % destination_name
	cost_label.text = "This will cost %d energy." % energy_cost
	confirm_button.disabled = false
	cancel_button.disabled = false
	show()
	_layout()
	call_deferred("_focus_cancel")


func dismiss() -> void:
	hide()
	if confirm_button != null:
		confirm_button.disabled = true
		cancel_button.disabled = true
		confirm_button.release_focus()
		cancel_button.release_focus()


func _focus_cancel() -> void:
	if is_visible_in_tree() and not _submitted:
		cancel_button.grab_focus()


func _confirm() -> void:
	if not is_visible_in_tree() or _submitted:
		return
	_submitted = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	confirmed.emit()


func _cancel() -> void:
	if not is_visible_in_tree() or _submitted:
		return
	_submitted = true
	cancelled.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_cancel()


func _layout() -> void:
	var minimum := panel.get_combined_minimum_size()
	var logical_size := Vector2(maxf(PANEL_WIDTH, minimum.x), minimum.y)
	var available := (size - Vector2(40, 40)).max(Vector2.ONE)
	var ratio := minf(1.0, minf(available.x / logical_size.x, available.y / logical_size.y))
	panel.size = logical_size
	panel.scale = Vector2.ONE * ratio
	panel.position = (size - logical_size * ratio) * 0.5


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	DashboardTheme.apply_button(button)
	button.custom_minimum_size = DashboardTheme.BUTTON_SIZE
	parent.add_child(button)
	UIAudioManager.attach_button(button)
	return button
