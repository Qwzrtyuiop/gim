extends Node

# Ride-local equipment; ordinary horns retain their existing response rules.
const STAGE_ID := "alma_special_delivery"
const OWNER_META := &"alma_delivery_equipment"
const Tuning := preload("res://scripts/config/game_tuning.gd")
const HornTraffic := preload("res://scripts/game/vehicle_horn_response.gd")
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
# Trimmed PCM starts at the horn's onset, without the source MP3's silent lead-in.
const HORN_SOUND := preload("res://assets/audio/sfx/driving/truck_horn.wav")

var tutorial_active := false
var enabled := false
var _owner
var _horn_player: AudioStreamPlayer
var _surface: Control
var _overlay: Control
var _panel: Panel
var _text: Label
var _status: Label
var _cooldown_seconds := Tuning.ALMA_TRUCK_HORN_COOLDOWN


static func for_owner(host):
	if not is_instance_valid(host) or not host.has_meta(OWNER_META):
		return null
	var helper: Variant = host.get_meta(OWNER_META)
	return helper if is_instance_valid(helper) else null


func setup(host) -> void:
	_owner = host
	var metadata: Dictionary = host.special_stage_blueprint.get("metadata", {})
	enabled = host.special_stage_id == STAGE_ID and bool(metadata.get("truck_horn", false))
	if not enabled:
		return
	_owner.set_meta(OWNER_META, self)
	_cooldown_seconds = maxf(0.0, float(metadata.get("truck_horn_cooldown", Tuning.ALMA_TRUCK_HORN_COOLDOWN)))
	_horn_player = AudioStreamPlayer.new()
	_horn_player.name = "DeliveryTruckHorn"
	var stream := HORN_SOUND.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_horn_player.stream = stream
	add_child(_horn_player)
	AudioSettingsManager.register_player(_horn_player, "sfx")
	_build_ui()
	var saved_intro := bool(PlayerState.active_event_special_stage.get("truck_horn_tutorial_seen", false))
	if not _owner.delivery_tutorial_seen and not saved_intro:
		tutorial_active = true
		TutorialOverlayHelper.set_overlay_visible(true, _overlay, _panel, _text)
	else:
		_owner.delivery_tutorial_seen = true
	_layout()
	_refresh_status()


func handle_input(event: InputEvent) -> bool:
	if not tutorial_active:
		return false
	if event.is_action_pressed("ui_cancel"):
		return false
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if (event.is_action_pressed("ui_accept") and not event.is_echo()) or clicked:
		tutorial_active = false
		_owner.delivery_tutorial_seen = true
		if str(PlayerState.active_event_special_stage.get("id", "")) == STAGE_ID:
			PlayerState.active_event_special_stage["truck_horn_tutorial_seen"] = true
			PlayerState.save_progress()
		TutorialOverlayHelper.set_overlay_visible(false, _overlay, _panel, _text)
		_refresh_status()
	return true


func press() -> void:
	if not enabled or tutorial_active or _owner.game_state != "playing" or _owner.crash_repair_transition_active or _owner.get_tree().paused:
		return
	if _owner.truck_horn_cooldown > 0.0:
		return
	_owner.truck_horn_cooldown = _cooldown_seconds
	_horn_player.play()
	var size: Vector2 = _owner.get_viewport_rect().size
	_owner.truck_horn_wave = {
		"origin": _owner.player.position / size,
		"radius": 0.0,
	}
	_refresh_status()


func update(delta: float) -> void:
	if not enabled:
		return
	_layout()
	if not tutorial_active and _owner.game_state == "playing" and not _owner.crash_repair_transition_active:
		_owner.truck_horn_cooldown = maxf(0.0, _owner.truck_horn_cooldown - delta)
		_update_horn_wave(delta)
	elif _owner.game_state != "playing" or _owner.crash_repair_transition_active:
		_owner.truck_horn_wave = {}
	_refresh_status()


func _update_horn_wave(delta: float) -> void:
	if _owner.truck_horn_wave.is_empty():
		return
	var size: Vector2 = _owner.get_viewport_rect().size
	var origin: Vector2 = _owner.truck_horn_wave.origin * size
	_owner.truck_horn_wave.radius = float(_owner.truck_horn_wave.radius) + Tuning.ALMA_TRUCK_HORN_WAVE_SPEED * delta
	var radius: float = float(_owner.truck_horn_wave.radius) * size.y / 720.0
	HornTraffic.truck_wave(_owner, origin, radius)
	var farthest_corner := Vector2(maxf(origin.x, size.x - origin.x), maxf(origin.y, size.y - origin.y))
	if radius >= farthest_corner.length():
		_owner.truck_horn_wave = {}


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 400
	add_child(layer)
	_surface = Control.new()
	_surface.name = "DeliveryEquipmentUI"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status = TutorialOverlayHelper.make_label(FONT, 10)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_status)
	var refs := TutorialOverlayHelper.create(_surface, FONT)
	_overlay = refs.overlay
	_panel = refs.text_panel
	_text = refs.text_label
	refs.highlight.hide()
	_text.text = "TRUCK HORN\n\nPress Q to send out a horn wave.\nCars pull aside when it reaches them.\nIt recharges in 5 seconds.\n\nPress Enter or click to begin."


func _layout() -> void:
	var dimensions: Vector2 = _owner.get_viewport_rect().size
	_status.position = Vector2(maxf(12.0, (dimensions.x - 360.0) * 0.5), 56.0)
	_status.size = Vector2(minf(360.0, dimensions.x - 24.0), 32.0)
	_panel.size = Vector2(minf(640.0, maxf(1.0, dimensions.x - 40.0)), minf(210.0, dimensions.y - 32.0))
	_panel.position = (dimensions - _panel.size) * 0.5
	_text.add_theme_font_size_override("font_size", 10 if dimensions.x < 800.0 else 12)


func _refresh_status() -> void:
	_status.visible = not tutorial_active and _owner.game_state == "playing"
	_status.text = "TRUCK HORN [Q]  READY" if _owner.truck_horn_cooldown <= 0.0 else "TRUCK HORN [Q]  %.1fs" % _owner.truck_horn_cooldown
