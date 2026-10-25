extends RefCounted

# Programmatic/mouse focus is kept for activation without looking like hover.
# Only intentional keyboard/controller navigation makes focus highlights visible.
const NAVIGATION_ACTIONS := [
	"ui_focus_next",
	"ui_focus_prev",
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
]

var keyboard_active := false


func handle_input(event: InputEvent) -> bool:
	var previous := keyboard_active
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		keyboard_active = false
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for action: String in NAVIGATION_ACTIONS:
			if event.is_action_pressed(action, true):
				keyboard_active = true
				break
	return previous != keyboard_active


func active(hovered: String, focused: String) -> String:
	return focused if keyboard_active else hovered


func reset() -> void:
	keyboard_active = false
