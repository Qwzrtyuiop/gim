extends RefCounted

const OUTLINE_SHADER := preload("res://scripts/story/story_portrait_outline.gdshader")


static func apply_to(rect: TextureRect) -> void:
	if not rect.material is ShaderMaterial or rect.material.shader != OUTLINE_SHADER:
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		rect.material = material
	var refresh := update_size.bind(rect)
	if not rect.resized.is_connected(refresh):
		rect.resized.connect(refresh)
	update_size(rect)


static func update_size(rect: TextureRect) -> void:
	if rect.texture == null:
		return
	# Both named and legacy portraits use KEEP_ASPECT_CENTERED.
	var texture_size := rect.texture.get_size()
	var scale_factor := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var displayed_size := (texture_size * scale_factor).max(Vector2.ONE)
	rect.material.set_shader_parameter("displayed_size", displayed_size)
