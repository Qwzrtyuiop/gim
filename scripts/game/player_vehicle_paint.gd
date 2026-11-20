extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")
const PAINT_MASK := preload("res://assets/vehicles/player_tricycle_mask.png")


static func apply_preset(vehicle: CanvasItem, preset_id: String) -> bool:
	if not GameTuning.PLAYER_PAINT_PRESETS.has(preset_id):
		return false
	var preset: Dictionary = GameTuning.PLAYER_PAINT_PRESETS[preset_id]
	apply(vehicle, preset.main, preset.highlight)
	return true


# Reuse the wheel material so paint, wheel rotation and sprite tint compose.
# This also accepts the static TextureRect on the crash-repair screen.
static func apply(
	vehicle: CanvasItem,
	main_color: Color = GameTuning.PLAYER_MAIN_PAINT_COLOR,
	highlight_color: Color = GameTuning.PLAYER_HIGHLIGHT_PAINT_COLOR,
) -> void:
	var material := vehicle.material as ShaderMaterial
	if material == null or material.shader != VehicleWheelAnimation.WHEEL_SHADER:
		material = ShaderMaterial.new()
		material.shader = VehicleWheelAnimation.WHEEL_SHADER
		# No wheel regions: static previews and disabled wheel animation stay still.
		material.set_shader_parameter("wheel_0", Vector4.ZERO)
		material.set_shader_parameter("wheel_1", Vector4.ZERO)
		material.set_shader_parameter("hub_fractions", Vector2.ZERO)
		vehicle.material = material
	material.set_shader_parameter("paint_mask", PAINT_MASK)
	material.set_shader_parameter("main_paint_color", main_color)
	material.set_shader_parameter("highlight_paint_color", highlight_color)
	material.set_shader_parameter("paint_enabled", main_color.a > 0.0 or highlight_color.a > 0.0)
