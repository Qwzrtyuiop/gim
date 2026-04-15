extends RefCounted

var layer: Node2D
var tiles: Array[Dictionary] = []


func setup(parent: Node, texture: Texture2D, z_index := -100) -> void:
	layer = Node2D.new()
	layer.z_index = z_index
	parent.add_child(layer)

	tiles.clear()
	var sprites: Array[Sprite2D] = []
	for copy_index in range(2):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		layer.add_child(sprite)
		sprites.append(sprite)

	tiles.append({
		"sprites": sprites,
		"texture": texture,
		"width": 1280.0,
	})


func is_ready() -> bool:
	return not tiles.is_empty()


func layout(size: Vector2) -> void:
	for tile in tiles:
		var texture := tile["texture"] as Texture2D
		if texture == null:
			continue

		var tile_scale := _cover_scale(texture, size)
		tile["width"] = texture.get_width() * tile_scale
		var tile_y := (size.y - texture.get_height() * tile_scale) * 0.5
		var sprites: Array = tile.get("sprites", [])
		for sprite_variant in sprites:
			var sprite := sprite_variant as Sprite2D
			if sprite == null:
				continue
			sprite.scale = Vector2(tile_scale, tile_scale)
			sprite.position.y = tile_y


func update(distance: float) -> void:
	for tile in tiles:
		var tile_width := float(tile.get("width", 1280.0))
		if tile_width <= 0.0:
			continue

		var background_x := -fmod(distance * 16.0, tile_width)
		var sprites: Array = tile.get("sprites", [])
		for index in range(sprites.size()):
			var sprite := sprites[index] as Sprite2D
			if sprite == null:
				continue
			sprite.position.x = background_x + tile_width * index


func _cover_scale(texture: Texture2D, size: Vector2) -> float:
	return maxf(size.x / texture.get_width(), size.y / texture.get_height())
