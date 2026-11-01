extends TextureRect

# Authored full-canvas silhouettes share the court's fit and weather tint.
const PLAYERS := preload("res://assets/story/backgrounds/locations/basketballplaying.png")

var _background: TextureRect


func setup(background: TextureRect) -> void:
	_background = background
	name = "BasketballPlayers"
	texture = PLAYERS
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep scenery at the background's depth so VN dialogue stays in front.
	z_index = 0
	_background.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_active(false)


func set_active(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		# Weather is configured before activation; paint players after its layer
		# without raising them above the rest of the scene's interface.
		_background.move_child(self, _background.get_child_count() - 1)
		_sync_tint()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_sync_tint()


func _sync_tint() -> void:
	if self_modulate != _background.self_modulate:
		self_modulate = _background.self_modulate
