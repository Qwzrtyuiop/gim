extends Control

# The parent draws its background with this helper's tint; only rain is overlaid.
const RAIN_SHADER := preload("res://scripts/ui/hub_weather_effects.gdshader")
const RAIN_TINT := Color(0.72, 0.76, 0.82)
const HEAVY_RAIN_TINT := Color(0.58, 0.64, 0.72)

var weather := "clear"
var elapsed := 0.0
var indoor := false
var strict_marker_colors := false
var marker_texture: Texture2D
var shader_material: ShaderMaterial
var effect_rect: ColorRect
var _marker_image: Image


func configure(marker: Texture2D, inside := false, strict_colors := false) -> void:
	marker_texture = marker
	indoor = inside
	strict_marker_colors = strict_colors
	_marker_image = null
	_sync_material()


func _ready() -> void:
	name = "HubWeatherEffects"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shader_material = ShaderMaterial.new()
	shader_material.shader = RAIN_SHADER
	material = shader_material
	effect_rect = ColorRect.new()
	effect_rect.name = "Rain"
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_rect.color = Color.WHITE
	effect_rect.material = shader_material
	add_child(effect_rect)
	effect_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_material()


func set_art_rect(rect: Rect2) -> void:
	position = rect.position
	size = rect.size


func set_weather(value: String) -> void:
	var normalized := value.strip_edges().to_lower().replace("_", " ").replace("-", " ")
	weather = normalized if normalized in ["clear", "cloudy", "rain", "heavy rain"] else "clear"
	if not is_raining():
		elapsed = 0.0
	_sync_material()


func is_raining() -> bool:
	return weather == "rain" or weather == "heavy rain"


func background_tint() -> Color:
	if weather == "heavy rain":
		return HEAVY_RAIN_TINT
	return RAIN_TINT if weather == "rain" else Color.WHITE


func _process(delta: float) -> void:
	if not is_raining() or not is_visible_in_tree() or get_tree().paused:
		return
	elapsed += maxf(0.0, delta)
	shader_material.set_shader_parameter("elapsed", elapsed)


func _sync_material() -> void:
	set_process(is_raining())
	if shader_material == null:
		return
	effect_rect.visible = is_raining()
	shader_material.set_shader_parameter("marker_mask", marker_texture)
	shader_material.set_shader_parameter("logical_size", marker_texture.get_size() if marker_texture != null else Vector2(1280, 720))
	shader_material.set_shader_parameter("indoor", indoor)
	shader_material.set_shader_parameter("strict_marker_colors", strict_marker_colors)
	shader_material.set_shader_parameter("elapsed", elapsed)
	shader_material.set_shader_parameter("rain_strength", 1.0 if weather == "heavy rain" else (0.6 if weather == "rain" else 0.0))


func contains_marked_uv(uv: Vector2) -> bool:
	if marker_texture == null or uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return false
	if _marker_image == null:
		_marker_image = marker_texture.get_image()
		if _marker_image != null and _marker_image.is_compressed():
			_marker_image.decompress()
	if _marker_image == null or _marker_image.is_empty():
		return false
	var dimensions := _marker_image.get_size()
	var pixel := Vector2i(floori(uv.x * dimensions.x), floori(uv.y * dimensions.y))
	var color := _marker_image.get_pixelv(pixel)
	# Transparent yellow padding must never become an emission region.
	if strict_marker_colors:
		return color.a >= 0.5 and color.r >= 160.0 / 255.0 and color.r <= 240.0 / 255.0 and color.g >= 240.0 / 255.0 and color.b <= 20.0 / 255.0
	return color.a >= 0.5 and color.r >= 0.4 and color.g >= 0.7 and color.b <= 0.3
