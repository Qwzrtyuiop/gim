extends RefCounted

const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const ImageOutline := preload("res://scripts/story/story_portrait_outline.gd")
const HouseCalendar := preload("res://scripts/ui/house_calendar.gd")
const HouseRadio := preload("res://scripts/ui/house_radio.gd")
const HouseRest := preload("res://scripts/ui/house_rest.gd")
const RIDE_BUTTON_TEXTURE := preload("res://assets/ui/buttons/hub/ride.png")
const STORE_BUTTON_TEXTURE := preload("res://assets/ui/buttons/hub/store.png")
const CALENDAR_TEXTURE := preload("res://assets/ui/frames/calendar.png")

# Builds home status and the calendar, radio, destination, and rest panels.


static func create_hud(owner) -> void:
	owner.status_header = HubStatusHeader.new()
	owner.add_child(owner.status_header)
	owner.header_label = owner.status_header.day_label
	owner.stats_row_refs = owner.status_header.stats_refs


static func label(owner, font_size: int) -> Label:
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", owner.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func create_info_overlay(owner) -> void:
	owner.info_overlay = ColorRect.new()
	owner.info_overlay.name = "HouseInfoOverlay"
	owner.info_overlay.color = Color(0, 0, 0, 0.55)
	owner.info_overlay.z_index = 50
	owner.info_overlay.hide()
	owner.add_child(owner.info_overlay)
	owner.info_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.info_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			owner.get_viewport().set_input_as_handled()
			close_info(owner)
	)
	owner.calendar_background = TextureRect.new()
	owner.calendar_background.name = "CalendarBackground"
	owner.calendar_background.texture = CALENDAR_TEXTURE
	owner.calendar_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner.calendar_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner.calendar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.calendar_background.rotation_degrees = 90
	owner.calendar_background.hide()
	owner.info_overlay.add_child(owner.calendar_background)
	ImageOutline.apply_to(owner.calendar_background)
	owner.info_panel = PanelContainer.new()
	owner.info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.085, 0.065, 0.97)
	style.border_color = Color(0.78, 0.61, 0.34)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	owner.info_panel_style = style
	owner.info_panel.add_theme_stylebox_override("panel", style)
	owner.info_overlay.add_child(owner.info_panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	owner.info_panel.add_child(content)
	owner.info_title = label(owner, 20)
	content.add_child(owner.info_title)
	owner.info_body = label(owner, 14)
	owner.info_body.custom_minimum_size.x = 600
	owner.info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner.info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owner.info_body.add_theme_constant_override("line_spacing", 12)
	content.add_child(owner.info_body)
	owner.info_close = Button.new()
	owner.info_close.text = "CLOSE"
	owner.info_close.custom_minimum_size.y = 46
	owner.info_close.add_theme_font_override("font", owner.UI_FONT)
	owner.info_close.add_theme_font_size_override("font_size", 14)
	owner.info_close.pressed.connect(owner._close_info)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)
	owner.info_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(owner.info_close)
	for destination in [["Ride", owner.RIDE_SELECTION_SCENE, RIDE_BUTTON_TEXTURE], ["Shop", owner.STORE_SCENE, STORE_BUTTON_TEXTURE]]:
		var button = TextureButton.new()
		button.tooltip_text = destination[0]
		button.texture_normal = destination[2]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size.y = 150
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(owner._choose_outside_destination.bind(destination[1]))
		button.hide()
		actions.add_child(button)
		ButtonGlow.attach(owner, button)
		owner.outside_buttons.append(button)
	owner.calendar_content = HouseCalendar.new()
	owner.calendar_content.hide()
	owner.info_overlay.add_child(owner.calendar_content)
	owner.calendar_content.closed.connect(owner._close_info)
	owner.radio_content = HouseRadio.new()
	owner.radio_content.hide()
	owner.info_overlay.add_child(owner.radio_content)
	owner.radio_content.closed.connect(owner._close_info)
	owner.rest_content = HouseRest.new()
	owner.rest_content.hide()
	owner.info_overlay.add_child(owner.rest_content)
	owner.rest_content.closed.connect(owner._close_info)
	owner.rest_content.confirmed.connect(owner._confirm_rest)
	owner.rest_confirm = owner.rest_content.confirm_button


static func layout_ui(owner) -> void:
	if owner.header_label == null:
		return
	owner.status_header.layout_in(owner.size)
	var content_origin = Vector2(0, HubStatusHeader.CONTENT_TOP)
	var content_size = owner.size - content_origin - Vector2(0, 16)
	if owner.info_action == "calendar":
		var aspect = float(CALENDAR_TEXTURE.get_height()) / CALENDAR_TEXTURE.get_width()
		var height = minf(content_size.y, (owner.size.x - 48) / aspect)
		var calendar_size = Vector2(height * aspect, height)
		owner.calendar_background.size = Vector2(calendar_size.y, calendar_size.x)
		owner.calendar_background.position = content_origin + (content_size - calendar_size) * 0.5 + Vector2(calendar_size.x, 0)
		owner.calendar_content.position = content_origin + (content_size - calendar_size) * 0.5
		owner.calendar_content.scale = calendar_size / HouseCalendar.DESIGN_SIZE
	elif owner.info_action == "radio":
		var radio_scale = minf(1.15, minf((owner.size.x - 48) / HouseRadio.DESIGN_SIZE.x, content_size.y / HouseRadio.DESIGN_SIZE.y))
		owner.radio_content.scale = Vector2.ONE * radio_scale
		owner.radio_content.position = content_origin + (content_size - HouseRadio.DESIGN_SIZE * radio_scale) * 0.5
	elif owner.info_action == "rest":
		var rest_scale = minf(1.0, minf((owner.size.x - 48) / HouseRest.DESIGN_SIZE.x, content_size.y / HouseRest.DESIGN_SIZE.y))
		owner.rest_content.scale = Vector2.ONE * rest_scale
		owner.rest_content.position = content_origin + (content_size - HouseRest.DESIGN_SIZE * rest_scale) * 0.5
	else:
		owner.info_panel.add_theme_stylebox_override("panel", owner.info_panel_style)
		owner.info_body.custom_minimum_size.x = minf(700, owner.size.x - 48) - 48
		owner.info_panel.size = Vector2(minf(700, owner.size.x - 48), minf(380 if owner.info_action == "outside" else 420, content_size.y))
		# Destination artwork has a minimum height; fit the complete popup below
		# the dashboard when a short viewport cannot accommodate that minimum.
		var panel_scale = minf(1.0, content_size.y / maxf(1.0, owner.info_panel.size.y))
		owner.info_panel.scale = Vector2.ONE * panel_scale
	owner.info_panel.position = content_origin + (content_size - owner.info_panel.size * owner.info_panel.scale) * 0.5
	if owner.tutorial_active:
		owner._show_tutorial_step(owner.tutorial_step_index)


static func render_day_start(owner) -> void:
	var current_time = PlayerState.get_current_time_of_day()
	owner.house.set_night(current_time == "night")
	owner.status_header.refresh()
	var rest_note = "Rest: recover +2 energy and move to noon."
	if current_time == "noon":
		rest_note = "Rest: recover +2 energy and move to night."
	elif current_time == "night":
		rest_note = "Sleep: recover +3 energy and start the next day at home."
	owner.house.buttons["rest"].tooltip_text = rest_note


static func show_info(owner, action: String) -> void:
	owner.info_action = action
	owner.calendar_background.visible = action == "calendar"
	owner.calendar_content.visible = action == "calendar"
	owner.radio_content.visible = action == "radio"
	owner.rest_content.visible = action == "rest"
	owner.info_panel.visible = action not in ["calendar", "radio", "rest"]
	owner.info_close.visible = action != "outside"
	for button in owner.outside_buttons:
		button.visible = action == "outside"
	owner.rest_confirm.visible = action == "rest"
	owner.info_close.text = "NO" if action == "rest" else "CLOSE"
	if action == "outside":
		owner.info_title.text = "GO OUTSIDE"
		owner.info_body.text = "Where would you like to go?\n\nPress Esc or click outside to stay home."
	elif action == "rest":
		owner.rest_content.refresh()
	elif action == "radio":
		owner.radio_content.refresh()
	elif action == "calendar":
		owner.calendar_content.refresh()
	owner.house.set_enabled(false)
	owner.info_overlay.show()
	layout_ui(owner)
	if action == "calendar":
		owner.calendar_content.close_button.grab_focus()
	elif action == "radio":
		owner.radio_content.close_button.grab_focus()
	elif action == "outside":
		owner.outside_buttons[0].grab_focus()
	elif action == "rest":
		owner.rest_content.cancel_button.grab_focus()
	else:
		owner.info_close.grab_focus()


static func close_info(owner) -> void:
	owner.info_overlay.hide()
	owner.calendar_content.close_button.release_focus()
	owner.radio_content.close_button.release_focus()
	owner.info_close.release_focus()
	owner.rest_confirm.release_focus()
	owner.rest_content.cancel_button.release_focus()
	for button in owner.outside_buttons:
		button.release_focus()
	owner.info_action = ""
	owner.house.set_enabled(not owner.is_transitioning and not owner.tutorial_active)
