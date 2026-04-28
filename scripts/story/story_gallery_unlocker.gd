extends RefCounted

const IMAGE_EXTENSIONS := {
	"jpeg": true,
	"jpg": true,
	"png": true,
	"webp": true,
}
const IMAGE_KEYS := {
	"background": true,
	"image": true,
	"left_portrait": true,
	"path": true,
	"portrait": true,
	"preview_image": true,
	"right_portrait": true,
	"texture": true,
}


static func unlock_gallery_images(player_state, image_refs: Array) -> int:
	if player_state == null:
		return 0
	var image_paths: Array[String] = []
	for image_ref in image_refs:
		var image_path: String = normalize_image_path(image_ref)
		if image_path.is_empty() or image_paths.has(image_path):
			continue
		image_paths.append(image_path)
	return player_state.unlock_gallery_images(image_paths)


static func collect_payload_gallery_image_paths(payload: Dictionary) -> Array[String]:
	var image_paths: Array[String] = []
	_collect_gallery_images_from_value(payload, image_paths)
	return image_paths


static func build_gallery_entry(image_path: String, metadata: Dictionary = {}) -> Dictionary:
	var safe_path: String = normalize_image_path(image_path)
	if safe_path.is_empty():
		return {}

	var entry: Dictionary = metadata.duplicate(true)
	entry["id"] = str(entry.get("id", _entry_id_from_path(safe_path)))
	entry["title"] = str(entry.get("title", _title_from_path(safe_path)))
	entry["subtitle"] = str(entry.get("subtitle", "Unlocked story image."))
	entry["image"] = safe_path
	entry["unlocked"] = true
	return entry


static func normalize_image_path(image_ref) -> String:
	var image_path: String = ""
	if image_ref is Texture2D:
		image_path = str((image_ref as Texture2D).resource_path)
	else:
		image_path = str(image_ref)

	image_path = image_path.strip_edges()
	if image_path.is_empty() or not image_path.begins_with("res://"):
		return ""
	if not IMAGE_EXTENSIONS.has(image_path.get_extension().to_lower()):
		return ""
	if not ResourceLoader.exists(image_path):
		return ""
	return image_path


static func _collect_gallery_images_from_value(value, image_paths: Array[String], parent_key: String = "") -> void:
	if value is Dictionary:
		var value_dictionary: Dictionary = value as Dictionary
		for key_variant in value_dictionary.keys():
			var key: String = str(key_variant)
			var item = value_dictionary.get(key_variant)
			if IMAGE_KEYS.has(key):
				_append_image_path(image_paths, item)
			_collect_gallery_images_from_value(item, image_paths, key)
		return

	if value is Array:
		var value_array: Array = value as Array
		for item_variant in value_array:
			_collect_gallery_images_from_value(item_variant, image_paths, parent_key)
		return

	if IMAGE_KEYS.has(parent_key):
		_append_image_path(image_paths, value)


static func _append_image_path(image_paths: Array[String], image_ref) -> void:
	var image_path: String = normalize_image_path(image_ref)
	if image_path.is_empty() or image_paths.has(image_path):
		return
	image_paths.append(image_path)


static func _entry_id_from_path(image_path: String) -> String:
	var file_name: String = image_path.get_file().get_basename()
	var normalized_id: String = file_name.replace(" ", "_").replace("-", "_").to_lower()
	if normalized_id.is_empty():
		return "gallery_image"
	return normalized_id


static func _title_from_path(image_path: String) -> String:
	var file_name: String = image_path.get_file().get_basename()
	var title: String = ""
	for index in range(file_name.length()):
		var character: String = file_name.substr(index, 1)
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			var previous: String = file_name.substr(index - 1, 1)
			if previous == previous.to_lower() and previous != previous.to_upper():
				title += " "
		elif character == "_" or character == "-":
			title += " "
			continue
		title += character
	title = title.strip_edges()
	return title.capitalize() if not title.is_empty() else "Gallery Image"
