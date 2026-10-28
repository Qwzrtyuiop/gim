extends RefCounted

# Owns station/terminal presentation while preserving locked selection state.
const StationView := preload("res://scripts/ui/station_view.gd")
const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const PassengerConfirmation := preload("res://scripts/ride_selection/passenger_confirmation.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")

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
	screen.station_back_button.name = "StationMapButton"
	screen.station_back_button.text = "MAP"
	screen.station_back_button.tooltip_text = "Open the town map"
	DashboardTheme.apply_button(screen.station_back_button)
	screen.station_back_button.pressed.connect(screen._open_map)
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
	screen.terminal_view.object_pressed.connect(screen._on_terminal_object_pressed)
	screen.terminal_view.close_button.pressed.connect(screen._open_pickup_map)
	screen.terminal_view.store_button.pressed.connect(screen._open_store)
	screen.passenger_overlay.hide()
	screen.terminal_view.hide()
	screen.terminal_view.set_enabled(false)
	# Keep status above the passenger view and below modal confirmations.
	screen.move_child(screen.status_header, screen.get_child_count() - 1)
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
	if screen.is_departing or screen.passenger_overlay.visible or (screen.station_tutorial != null and screen.station_tutorial.active):
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
	if PlayerState.are_passengers_available() and not PlayerState.has_ride_select_tutorial_shown() and not screen.terminal_offers.is_empty():
		screen.tutorial.start()
	else:
		focus_passenger_controls()


func hide_passengers() -> void:
	if screen.is_departing or screen._tutorial_active() or not screen.passenger_overlay.visible:
		return
	var keyboard_navigation: bool = screen.terminal_view.is_keyboard_navigation()
	screen.terminal_view.set_enabled(false)
	screen.terminal_view.hide()
	screen.passenger_overlay.hide()
	screen.station.set_enabled(true)
	screen.station.set_keyboard_navigation(keyboard_navigation)
	screen.station_back_button.visible = not screen.is_departing
	screen.status_header.set_display_time()
	screen.status_header.show()
	PlayerState.set_pending_passengers_open(false)
	screen.station.buttons["passengers"].grab_focus()


func focus_passenger_controls() -> void:
	if screen.terminal_offers.is_empty():
		screen.terminal_view.close_button.grab_focus()
	elif PlayerState.are_passengers_available() and screen._needs_refuel():
		screen.terminal_view.store_button.grab_focus()
	else:
		screen.terminal_view.focus_first_offer()


func layout() -> void:
	if screen.station == null:
		return
	screen.status_header.layout_in(screen.size)
	screen.station_back_button.position = Vector2(20, screen.size.y - 60)
	screen.station_back_button.size = DashboardTheme.BUTTON_SIZE
	if screen.tutorial != null and screen.tutorial.active:
		screen.tutorial._layout_for_targets(screen.tutorial.steps[screen.tutorial.step_index].get("targets", []))
	if screen.station_tutorial != null and screen.station_tutorial.active:
		screen.station_tutorial._layout_for_targets(screen.station_tutorial.steps[screen.station_tutorial.step_index].get("targets", []))
