extends RefCounted


static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


static func is_up_down_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W, KEY_DOWN, KEY_S:
				return true
	return false


static func is_left_right_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				return true
	return false


static func is_accelerating() -> bool:
	return Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)


static func is_braking() -> bool:
	return Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)


static func is_boosting() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)
