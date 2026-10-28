extends Panel

# A border behind the existing icon leaves its texture and layout untouched.


func _ready() -> void:
	name = "StressShieldHighlight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = -3.0
	offset_top = -3.0
	offset_right = 3.0
	offset_bottom = 3.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.79, 0.08, 0.12)
	style.border_color = Color(1.0, 0.83, 0.12, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(1.0, 0.76, 0.08, 0.42)
	style.shadow_size = 3
	add_theme_stylebox_override("panel", style)
	PlayerState.stress_shield_changed.connect(_on_shield_changed)
	_on_shield_changed(PlayerState.get_stress_shield_points())


func _on_shield_changed(points: int) -> void:
	visible = points > 0
