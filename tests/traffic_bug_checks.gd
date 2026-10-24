extends RefCounted

const GameAudioManager := preload("res://scripts/game/game_audio_manager.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const TrafficManeuvers := preload("res://scripts/game/vehicle_traffic_maneuvers.gd")
const TrafficSignals := preload("res://scripts/game/vehicle_traffic_signals.gd")


class GeometryOwner extends Node2D:
	var texture_hitbox_cache: Dictionary = {}


class WarningOwner extends GeometryOwner:
	const VEHICLE_HITBOX_INSET := Vector4.ZERO
	var active_entities: Array = []
	var player: Sprite2D
	var player_lane := 1
	var incoming_lane_scale := 1.0
	var main_lane_scale := 1.0
	var shoulder_lane_scale := 1.0
	var npc_lane_change_planning_padding_x := 0.0
	var npc_lane_change_planning_padding_y := 0.0
	var speeder_safe_gap := 50.0
	var speeder_avoid_lookahead := 50.0
	var speeder_lane_change_warning_active := false
	var speeder_lane_change_warning_timer := 0.0
	var speeder_lane_change_warning_beeps_remaining := 0
	var speeder_lane_change_warning_target_lane := -1
	var pending_speeder_lane_change_sprite: Sprite2D


static func run(host: Node) -> void:
	var owner := GeometryOwner.new()
	host.add_child(owner)
	var first_bounds := Rect2i(2, 3, 4, 5)
	var second_bounds := Rect2i(8, 1, 6, 12)
	var first_texture := _texture_with_bounds(first_bounds)
	var second_texture := _texture_with_bounds(second_bounds)
	assert(first_texture.resource_path.is_empty() and second_texture.resource_path.is_empty())
	assert(VehicleGeometry.visible_texture_rect(first_texture, owner) == Rect2(first_bounds))
	assert(VehicleGeometry.visible_texture_rect(second_texture, owner) == Rect2(second_bounds), "Distinct runtime textures must retain independent hitbox bounds")
	owner.free()
	_test_warning_ownership(host)

	var audio := GameAudioManager.new()
	host.add_child(audio)
	audio.setup(audio)
	audio.speeder_beep_player.play()
	var empty_playback := audio.speeder_beep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var empty_buffer_frames := empty_playback.get_frames_available()
	for warning in range(100):
		audio.play_speeder_beep()
		var playback := audio.speeder_beep_player.get_stream_playback() as AudioStreamGeneratorPlayback
		assert(playback != null)
		assert(playback.get_frames_available() < empty_buffer_frames, "Every warning must queue its beep samples")
	audio.free()
	print("PASS: independent runtime texture hitboxes, speeder warning ownership and repeated beep playback")


static func _test_warning_ownership(host: Node) -> void:
	var owner := WarningOwner.new()
	host.add_child(owner)
	var first := Sprite2D.new()
	var second := Sprite2D.new()
	first.texture = _texture_with_bounds(Rect2i(1, 1, 14, 14))
	second.texture = first.texture
	owner.add_child(first)
	owner.add_child(second)
	TrafficSignals.start_speeder_lane_change_warning(owner, first, 1)
	owner.speeder_lane_change_warning_timer = 0.14
	owner.speeder_lane_change_warning_beeps_remaining = 2
	var second_entity := {"kind": "speeder", "lane": 2, "sprite": second}
	assert(not TrafficManeuvers.try_set_speeder_target_lane(owner, second_entity, 1), "Another speeder must wait for the current warning to finish")
	assert(owner.pending_speeder_lane_change_sprite == first)
	assert(owner.speeder_lane_change_warning_beeps_remaining == 2 and owner.speeder_lane_change_warning_timer == 0.14, "A competing speeder must not restart the active countdown")
	owner.free()


static func _texture_with_bounds(bounds: Rect2i) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(bounds, Color.WHITE)
	return ImageTexture.create_from_image(image)
