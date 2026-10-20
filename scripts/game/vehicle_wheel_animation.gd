extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const WHEEL_SHADER := preload("res://scripts/game/vehicle_wheels.gdshader")

# Source-image pixel coordinates: hub center X/Y, tire radius X/Y.
# Hub fractions limit rotation to exposed rims. Zero preserves bike forks,
# chains and spokes drawn across the wheels; their tires get rolling highlights.
# Update these art anchors if the corresponding PNG is replaced or resized.
const LAYOUTS := {
	"beetle": [Vector4(126, 184, 42, 42), Vector4(465, 184, 42, 42), Vector2(0.66, 0.66)],
	"blue_truck": [Vector4(164, 414, 49, 47), Vector4(522, 413, 49, 47), Vector2(0.58, 0.60)],
	"bus": [Vector4(232, 240, 42, 40), Vector4(614, 239, 42, 40), Vector2(0.60, 0.63)],
	"cargotruck": [Vector4(141, 265, 40, 40), Vector4(488, 265, 43, 40), Vector2(0.66, 0.65)],
	"gray_sedan": [Vector4(142, 196, 43, 42), Vector4(502, 197, 43, 42), Vector2(0.78, 0.78)],
	"jeepney": [Vector4(208, 262, 39, 38), Vector4(610, 261, 40, 39), Vector2(0.65, 0.65)],
	"motorcycle": [Vector4(55, 224, 40, 40), Vector4(273, 225, 42, 41), Vector2.ZERO],
	"player_tricycle": [Vector4(115, 303, 42, 43), Vector4(395, 283, 43, 40), Vector2(0.72, 0.0)],
	"sedan": [Vector4(129, 194, 41, 40), Vector4(489, 195, 41, 39), Vector2(0.66, 0.66)],
	"truck": [Vector4(188, 415, 47, 46), Vector4(550, 416, 48, 46), Vector2(0.63, 0.63)],
	"van": [Vector4(102, 204, 33, 31), Vector4(355, 204, 33, 31), Vector2(0.62, 0.62)],
	"vendor_tricycle": [Vector4(122, 278, 52, 50), Vector4(347, 257, 50, 49), Vector2.ZERO],
}


static func attach(sprite: Sprite2D, vehicle_key: String) -> void:
	if not GameTuning.WHEEL_ANIMATION_ENABLED or not LAYOUTS.has(vehicle_key):
		return
	var layout: Array = LAYOUTS[vehicle_key]
	var material := ShaderMaterial.new()
	material.shader = WHEEL_SHADER
	material.set_shader_parameter("wheel_0", layout[0])
	material.set_shader_parameter("wheel_1", layout[1])
	material.set_shader_parameter("hub_fractions", layout[2])
	material.set_shader_parameter("wheel_angles", Vector2.ZERO)
	material.set_shader_parameter("tire_highlight_strength", GameTuning.WHEEL_TIRE_HIGHLIGHT_STRENGTH)
	sprite.material = material
	sprite.set_meta("wheel_radii", Vector2(layout[0].z, layout[1].z))


# Signed road velocity, not camera-relative screen motion. A vehicle driving
# alongside the player still rolls; parked scenery scrolling past does not.
static func update(sprite: Sprite2D, road_velocity: float, delta: float) -> void:
	if delta <= 0.0 or not sprite.has_meta("wheel_radii"):
		return
	var material := sprite.material as ShaderMaterial
	if material == null or material.shader != WHEEL_SHADER:
		return
	var radii: Vector2 = sprite.get_meta("wheel_radii")
	var angles: Vector2 = material.get_shader_parameter("wheel_angles")
	# UV mirroring already reverses the rendered rotation of left-facing cars.
	var local_speed := road_velocity * (-1.0 if sprite.flip_h else 1.0)
	var max_rate := maxf(0.0, GameTuning.WHEEL_MAX_REVOLUTIONS_PER_SECOND) * TAU
	for index in range(2):
		var radius := maxf(1.0, radii[index] * absf(sprite.scale.x))
		var rate := clampf(local_speed / radius * GameTuning.WHEEL_ROTATION_SPEED_X, -max_rate, max_rate)
		angles[index] = fposmod(angles[index] + rate * delta, TAU)
	material.set_shader_parameter("wheel_angles", angles)
