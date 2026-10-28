extends Node

# Scene-local bar cast; travel and audio remain with HomeMap.
signal interacted(character_id: String)

const BarAlmaSpawn := preload("res://scripts/home/bar_alma_spawn.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const BENNY_TEXTURE := preload("res://assets/characters/sprites/bennybar.png")
const BENNY_REGION := Rect2(735, 328, 250, 470)
const BENNY_MIN_BOND := 2
const BENNY_SPAWN_CHANCE := 0.30
const ALMA_DEFAULT_LINES := [
	"Welcome. What'll it be?",
	"Here for a drink?",
	"Take a seat. I'll be with you in a moment.",
	"Looking for something?",
	"What can I get you?",
	"You ordering, or just looking?",
	"Hm? Need anything?",
]
const ALMA_FAMILIAR_MIN_BOND := 2
const ALMA_FAMILIAR_LINES := [
	"Oh, it's you. What'll it be?",
	"Welcome back. Need something to drink?",
]
const ALMA_SHOP_CLOSING_LINES := [
	"Not ordering anything?",
	"You can sit. Just don't cause trouble.",
	"Are you buying something or not?",
	"Just here to pass the time?",
	"You know this is a bar, right?",
	"Well, let me know if you need anything.",
	"If you're not buying, at least don't block the counter.",
]

static var _benny_atlas: AtlasTexture
static var _benny_mask: BitMap

var alma_spawn: BarAlmaSpawn
var benny_spawn: TextureButton
var active := false
var interaction_override: Callable
var _interaction_enabled := true
var _background: TextureRect
var _dialogue: HubDialogue
var _rng := RandomNumberGenerator.new()
var _alma_line_index := 0
var _alma_shop_closing_index := 0


func _ready() -> void:
	name = "BarCharacters"
	_rng.randomize()
	set_process(false)


func setup(background: TextureRect) -> void:
	_background = background
	alma_spawn = BarAlmaSpawn.new()
	_background.add_child(alma_spawn)
	alma_spawn.interacted.connect(_on_character_interacted)
	_build_benny_spawn()


func setup_dialogue(dialogue: HubDialogue) -> void:
	_dialogue = dialogue
	_dialogue.register_control("bar:benny", benny_spawn)
	_dialogue.register_target("bar:alma", _alma_message_target)


func set_active(value: bool) -> void:
	active = value
	alma_spawn.set_active(value)
	# Roll once on entry, independently of passenger and driving RNG.
	var benny_present := value and PlayerState.get_unique_character_progress("benny") >= BENNY_MIN_BOND and _rng.randf() < BENNY_SPAWN_CHANCE
	benny_spawn.visible = benny_present
	benny_spawn.disabled = not benny_present
	benny_spawn.self_modulate = _background.self_modulate
	if not value:
		benny_spawn.release_focus()
	set_process(benny_present)


func layout_in(view_size: Vector2) -> void:
	if _background.texture == null:
		return
	var art_size := _background.texture.get_size()
	var fit := minf(view_size.x / art_size.x, view_size.y / art_size.y)
	benny_spawn.position = (_background.size - art_size * fit) * 0.5 + BENNY_REGION.position * fit
	benny_spawn.size = BENNY_REGION.size * fit


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	alma_spawn.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	benny_spawn.disabled = not value or not active or not benny_spawn.visible
	if not value:
		alma_spawn.release_focus()
		benny_spawn.release_focus()


func set_alma_pose_locked(value: bool) -> void:
	alma_spawn.set_pose_locked(value)


func _process(_delta: float) -> void:
	if benny_spawn.self_modulate != _background.self_modulate:
		benny_spawn.self_modulate = _background.self_modulate


func _on_character_interacted(character_id: String) -> void:
	if not _interaction_enabled or not active or not _background.is_visible_in_tree() or _dialogue == null or _dialogue.blocks_input():
		return
	if interaction_override.is_valid() and bool(interaction_override.call(character_id)):
		return
	var alma_lines: Array = ALMA_DEFAULT_LINES.duplicate()
	if PlayerState.get_unique_character_progress("alma") >= ALMA_FAMILIAR_MIN_BOND:
		alma_lines.append_array(ALMA_FAMILIAR_LINES)
	var line: String = alma_lines[_alma_line_index % alma_lines.size()] if character_id == "alma" else "..."
	if not _dialogue.say(line, {
		"target": "bar:" + character_id,
		"character_id": character_id,
		"duration": 4.0 if character_id == "alma" else 2.5,
	}):
		return
	if character_id == "alma":
		_alma_line_index = (_alma_line_index + 1) % alma_lines.size()
	interacted.emit(character_id)


func say_shop_closing_line() -> void:
	if _dialogue == null or not _interaction_enabled or not active or not _background.is_visible_in_tree() or _dialogue.blocks_input():
		return
	if _dialogue.say(ALMA_SHOP_CLOSING_LINES[_alma_shop_closing_index], {
		"target": "bar:alma",
		"character_id": "alma",
		"duration": 4.0,
	}):
		_alma_shop_closing_index = (_alma_shop_closing_index + 1) % ALMA_SHOP_CLOSING_LINES.size()


func _alma_message_target() -> Rect2:
	if not alma_spawn.active or not alma_spawn.is_visible_in_tree():
		return Rect2()
	return alma_spawn.get_global_transform_with_canvas() * alma_spawn.sprite_rect


func _build_benny_spawn() -> void:
	_prepare_benny_art()
	benny_spawn = TextureButton.new()
	benny_spawn.name = "BennyBarSpawn"
	benny_spawn.ignore_texture_size = true
	benny_spawn.stretch_mode = TextureButton.STRETCH_SCALE
	benny_spawn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	benny_spawn.texture_normal = _benny_atlas
	benny_spawn.texture_click_mask = _benny_mask
	benny_spawn.pressed.connect(_on_character_interacted.bind("benny"))
	_background.add_child(benny_spawn)
	benny_spawn.hide()
	benny_spawn.disabled = true


static func _prepare_benny_art() -> void:
	if _benny_atlas != null:
		return
	_benny_atlas = AtlasTexture.new()
	_benny_atlas.atlas = BENNY_TEXTURE
	_benny_atlas.region = BENNY_REGION
	_benny_atlas.filter_clip = true
	var image := BENNY_TEXTURE.get_image()
	if image.is_compressed():
		image.decompress()
	_benny_mask = BitMap.new()
	_benny_mask.create_from_image_alpha(image.get_region(Rect2i(BENNY_REGION)), 0.7)
