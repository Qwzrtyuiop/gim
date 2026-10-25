extends Control

# Presentation only. The coordinator owns selection validation and departure.
signal confirmed
signal cancelled

const PassengerTripCard := preload("res://scripts/ride_selection/passenger_trip_card.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PANEL_WIDTH := 700.0
const VIEWPORT_MARGIN := 24.0

var card: PassengerTripCard
var panel: PanelContainer
var confirm_button: Button
var cancel_button: Button
var heading_label: Label
var note_label: Label
var _built := false
var _submitted := false


func _init() -> void:
	hide()


func _ready() -> void:
	_build()
	resized.connect(_layout)
	if visible:
		_layout()
	else:
		dismiss()


func present(summary: Dictionary) -> void:
	_build()
	_submitted = false
	card.set_summary(summary)
	confirm_button.disabled = false
	cancel_button.disabled = false
	show()
	_layout()
	call_deferred("_focus_cancel")


func dismiss() -> void:
	hide()
	if not _built:
		return
	confirm_button.disabled = true
	cancel_button.disabled = true
	confirm_button.release_focus()
	cancel_button.release_focus()


func _focus_cancel() -> void:
	if is_visible_in_tree() and not _submitted:
		cancel_button.grab_focus()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "ConfirmationBackdrop"
	backdrop.color = Color(0.015, 0.012, 0.008, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	panel = PanelContainer.new()
	panel.name = "PassengerConfirmationPanel"
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
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	add_child(panel)
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
	heading_label = _label(16, Color("faefd5"))
	heading_label.text = "TAKE THIS PASSENGER?"
	content.add_child(heading_label)
	card = PassengerTripCard.new()
	card.name = "ConfirmedTripSummary"
	content.add_child(card)
	note_label = _label(10, Color("b8ab92"))
	note_label.text = "Confirm to continue with this passenger."
	content.add_child(note_label)
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_STOP
	actions.add_theme_constant_override("separation", 16)
	actions.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions)
	cancel_button = _button("CANCEL", false)
	cancel_button.name = "CancelPassenger"
	actions.add_child(cancel_button)
	confirm_button = _button("CONFIRM", true)
	confirm_button.name = "ConfirmPassenger"
	actions.add_child(confirm_button)
	cancel_button.pressed.connect(_on_cancelled)
	confirm_button.pressed.connect(_on_confirmed)
	for button in [cancel_button, confirm_button]:
		UIAudioManager.attach_button(button)
	cancel_button.focus_next = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_previous = cancel_button.get_path_to(confirm_button)
	confirm_button.focus_next = confirm_button.get_path_to(cancel_button)
	confirm_button.focus_previous = confirm_button.get_path_to(cancel_button)
	for direction in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		cancel_button.set_focus_neighbor(direction, cancel_button.get_path_to(confirm_button))
		confirm_button.set_focus_neighbor(direction, confirm_button.get_path_to(cancel_button))


func _on_confirmed() -> void:
	if not is_visible_in_tree() or _submitted:
		return
	_submitted = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	confirmed.emit()


func _on_cancelled() -> void:
	if not is_visible_in_tree() or _submitted:
		return
	_submitted = true
	cancelled.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_cancelled()


func _layout() -> void:
	if not _built:
		return
	var minimum := panel.get_combined_minimum_size()
	var logical_size := Vector2(maxf(PANEL_WIDTH, minimum.x), minimum.y)
	var available := (size - Vector2.ONE * VIEWPORT_MARGIN * 2.0).max(Vector2.ONE)
	var ratio := minf(1.0, minf(available.x / logical_size.x, available.y / logical_size.y))
	panel.size = logical_size
	panel.scale = Vector2.ONE * ratio
	panel.position = (size - logical_size * ratio) * 0.5


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 46)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("22180c") if primary else Color("eadfc7"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d7b477") if primary else Color("292016")
	normal.border_color = Color("e8c98f") if primary else Color("8c7653")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("edcc94") if primary else Color("493822")
	hover.border_color = Color("ffdf9a")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button
