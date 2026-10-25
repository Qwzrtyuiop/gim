extends RefCounted

# Target callbacks return canvas-space bounds, including letterboxing and resize.
const STORE_COUNTERS := {
	"tricycle": Rect2(0.350, 0.580, 0.150, 0.150),
	"food": Rect2(0.665, 0.565, 0.235, 0.155),
}
const STORE_OWNER_HEADS := {
	# These portraits include their shop interiors above the characters. Locate
	# the actual face, rather than treating the top quarter as a head cutout.
	"tricycle": Rect2(0.32, 0.24, 0.48, 0.30),
	"food": Rect2(0.32, 0.14, 0.43, 0.22),
}


static func control_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return Rect2()
	var rect := Rect2(Vector2.ZERO, control.size)
	if control is TextureRect and control.texture != null and control.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var texture_size: Vector2 = control.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			var ratio := minf(control.size.x / texture_size.x, control.size.y / texture_size.y)
			rect = Rect2((control.size - texture_size * ratio) * 0.5, texture_size * ratio)
	return transform_rect(control, rect)


static func image_region(view: Control, region: Rect2) -> Rect2:
	if not is_instance_valid(view) or not view.is_inside_tree() or not view.is_visible_in_tree():
		return Rect2()
	var image: Rect2 = view.get("image_rect")
	return transform_rect(view, Rect2(image.position + image.size * region.position, image.size * region.size))


static func terminal_character(screen, character_id: String) -> Rect2:
	if not is_instance_valid(screen) or not screen.passenger_overlay.visible or not screen.terminal_view.is_visible_in_tree():
		return Rect2()
	var highlighted: bool = screen.terminal_view.active_offer_id() == character_id
	var rect: Rect2 = screen.terminal_view.sprite_rect_for(character_id, highlighted)
	return transform_rect(screen.terminal_view, rect) if rect.has_area() else Rect2()


static func store_owner(screen, category: String) -> Rect2:
	if not is_instance_valid(screen):
		return Rect2()
	if screen.shop_overlay.visible:
		if screen.active_category != category:
			return Rect2()
		var portrait := control_rect(screen.owner_portrait)
		# Anchor below the head rather than beside the entire full-body portrait.
		# The body fills most of the owner column; its full bounds would push speech
		# into the item list and its BUY controls.
		var head: Rect2 = STORE_OWNER_HEADS.get(category, Rect2(0.2, 0.03, 0.6, 0.25))
		return Rect2(portrait.position + portrait.size * head.position, portrait.size * head.size) if portrait.has_area() else Rect2()
	# There are no owner sprites in the street background. These optional targets
	# locate the counters for a voice coming from inside a closed shop panel.
	return image_region(screen.street, STORE_COUNTERS.get(category, Rect2()))


static func transform_rect(control: Control, rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	return control.get_global_transform_with_canvas() * rect
