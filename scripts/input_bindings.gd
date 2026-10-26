extends Node

# Add letter-key alternatives without replacing Godot's arrows or gamepad inputs.
const WASD_ACTIONS := {
	&"ui_up": KEY_W,
	&"ui_down": KEY_S,
	&"ui_left": KEY_A,
	&"ui_right": KEY_D,
}


func _enter_tree() -> void:
	for action: StringName in WASD_ACTIONS:
		var key := InputEventKey.new()
		key.physical_keycode = WASD_ACTIONS[action]
		if not InputMap.action_has_event(action, key):
			InputMap.action_add_event(action, key)
