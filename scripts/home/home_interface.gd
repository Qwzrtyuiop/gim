extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const ImageOutline := preload("res://scripts/story/story_portrait_outline.gd")
const HouseCalendar := preload("res://scripts/ui/house_calendar.gd")
const HouseRadio := preload("res://scripts/ui/house_radio.gd")
const HouseRest := preload("res://scripts/ui/house_rest.gd")
const CALENDAR_TEXTURE := preload("res://assets/ui/frames/calendar.png")

# Builds home status and the calendar, radio, and rest panels.


static func create_hud(owner) -> void:
	owner.status_header = HubStatusHeader.new()
	owner.add_child(owner.status_header)
	owner.header_label = owner.status_header.day_label
	owner.stats_row_refs = owner.status_header.stats_refs
	owner.map_button = Button.new()
	owner.map_button.name = "HomeMapButton"
	owner.map_button.text = "MAP"
	DashboardTheme.apply_button(owner.map_button)
	owner.map_button.pressed.connect(owner._open_map)
	owner.add_child(owner.map_button)
	UIAudioManager.attach_button(owner.map_button)


static func create_info_overlay(owner) -> void:
	owner.info_overlay = ColorRect.new()
	owner.info_overlay.name = "HouseInfoOverlay"
	owner.info_overlay.color = Color(0, 0, 0, 0.55)
	owner.info_overlay.z_index = 70
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
	owner.map_button.position = Vector2(20, owner.size.y - 60)
	owner.map_button.size = DashboardTheme.BUTTON_SIZE
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
	if owner.tutorial_active:
		owner._show_tutorial_step(owner.tutorial_step_index)


static func render_day_start(owner) -> void:
	var current_time = PlayerState.get_current_time_of_day()
	owner.house.set_night(current_time == "night")
	owner.status_header.refresh()
	var rest_note = "Rest: +2 energy, -%d stress, then continue at noon." % GameTuning.REST_STRESS_RELIEF
	if current_time == "noon":
		rest_note = "Rest: +2 energy, -%d stress, then continue at night." % GameTuning.REST_STRESS_RELIEF
	elif current_time == "night":
		rest_note = "Sleep: restore energy to %d, reduce stress by %d, and start the next day at home." % [GameTuning.DEFAULT_MAX_ENERGY, GameTuning.NIGHT_SLEEP_STRESS_RELIEF]
	owner.house.buttons["rest"].tooltip_text = rest_note


static func show_info(owner, action: String) -> void:
	owner.info_action = action
	owner.calendar_background.visible = action == "calendar"
	owner.calendar_content.visible = action == "calendar"
	owner.radio_content.visible = action == "radio"
	owner.rest_content.visible = action == "rest"
	owner.rest_confirm.visible = action == "rest"
	if action == "rest":
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
	elif action == "rest":
		owner.rest_content.cancel_button.grab_focus()


static func close_info(owner) -> void:
	owner.info_overlay.hide()
	owner.calendar_content.close_button.release_focus()
	owner.radio_content.close_button.release_focus()
	owner.rest_confirm.release_focus()
	owner.rest_content.cancel_button.release_focus()
	owner.info_action = ""
	owner.house.set_enabled(not owner.is_transitioning and not owner.tutorial_active)
