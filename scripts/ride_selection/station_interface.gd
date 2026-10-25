extends RefCounted

# Owns station/terminal presentation while preserving locked selection state.
const StationView := preload("res://scripts/ui/station_view.gd")
const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const PassengerConfirmation := preload("res://scripts/ride_selection/passenger_confirmation.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var screen


func _init(selection_screen) -> void:
	screen = selection_screen


func setup() -> void:
	screen.station = StationView.new()
	screen.station.name = "Station"
	screen.add_child(screen.station)
	screen.station.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.station.set_night(PlayerState.get_next_stage_time(screen._transition_mode()) == "night")
	screen.station.action_pressed.connect(screen._on_station_action)
	screen.status_header = HubStatusHeader.new()
	screen.add_child(screen.status_header)
	screen.station_back_button = Button.new()
	screen.station_back_button.name = "StationBack"
	screen.station_back_button.text = "BACK"
	screen.station_back_button.add_theme_font_override("font", FONT)
	screen.station_back_button.add_theme_font_size_override("font_size", 12)
	screen.station_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	screen.station_back_button.visible = screen._allow_back()
	screen.station_back_button.pressed.connect(screen._go_back)
	screen.add_child(screen.station_back_button)
	UIAudioManager.attach_button(screen.station_back_button)
	screen.passenger_overlay = ColorRect.new()
	screen.passenger_overlay.name = "PassengerOverlay"
	screen.passenger_overlay.color = Color("17110b")
	screen.passenger_overlay.z_index = 10
	screen.add_child(screen.passenger_overlay)
	screen.passenger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.terminal_view = TerminalView.new()
	screen.terminal_view.name = "TerminalPassengers"
	screen.passenger_overlay.add_child(screen.terminal_view)
	screen.terminal_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.status_label = screen.terminal_view.status_label
	screen.terminal_view.offer_pressed.connect(screen._choose_offer)
	screen.terminal_view.offer_focused.connect(screen._focus_offer)
	screen.terminal_view.close_button.pressed.connect(screen._close_passengers)
	screen.terminal_view.store_button.pressed.connect(screen._open_store)
	screen.passenger_overlay.hide()
	screen.terminal_view.hide()
	screen.terminal_view.set_enabled(false)
	screen.confirmation = PassengerConfirmation.new()
	screen.confirmation.name = "PassengerConfirmation"
	screen.confirmation.z_index = 80
	screen.add_child(screen.confirmation)
	screen.confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.confirmation.confirmed.connect(screen._confirm_passenger)
	screen.confirmation.cancelled.connect(screen._cancel_passenger)
	screen.resized.connect(layout)
	layout()


func show_passengers() -> void:
	if screen.is_departing or screen.passenger_overlay.visible:
		return
	var keyboard_navigation: bool = screen.station.is_keyboard_navigation()
	screen.passenger_overlay.show()
	screen.terminal_view.show()
	screen.terminal_view.set_enabled(true)
	screen.station.set_enabled(false)
	screen.terminal_view.set_keyboard_navigation(keyboard_navigation)
	screen.station_back_button.hide()
	screen.status_header.set_display_time(screen._display_day(), PlayerState.get_next_stage_time(screen._transition_mode()))
	screen.status_header.show()
	PlayerState.set_pending_passengers_open(true)
	if not PlayerState.has_ride_select_tutorial_shown():
		screen.tutorial.start()
	else:
		focus_passenger_controls()


func hide_passengers() -> void:
	if screen.is_departing or screen.tutorial.active or not screen.passenger_overlay.visible:
		return
	var keyboard_navigation: bool = screen.terminal_view.is_keyboard_navigation()
	screen.terminal_view.set_enabled(false)
	screen.terminal_view.hide()
	screen.passenger_overlay.hide()
	screen.station.set_enabled(true)
	screen.station.set_keyboard_navigation(keyboard_navigation)
	screen.station_back_button.visible = screen._allow_back()
	screen.status_header.set_display_time()
	screen.status_header.show()
	PlayerState.set_pending_passengers_open(false)
	screen.station.buttons["passengers"].grab_focus()


func focus_passenger_controls() -> void:
	if screen._needs_refuel():
		screen.terminal_view.store_button.grab_focus()
	else:
		screen.terminal_view.focus_first_offer()


func layout() -> void:
	if screen.station == null:
		return
	screen.status_header.layout_in(screen.size)
	screen.station_back_button.position = Vector2(24, screen.size.y - 66)
	screen.station_back_button.size = Vector2(160, 42)
	if screen.tutorial != null and screen.tutorial.active:
		screen.tutorial._layout_for_targets(screen.tutorial.steps[screen.tutorial.step_index].get("targets", []))
