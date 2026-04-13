extends Control

const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"

@onready var message_label: Label = $MessageLabel


func _ready() -> void:
	message_label.text = "SLEEPING..."
	_begin_transition()


func _begin_transition() -> void:
	await get_tree().create_timer(1.1).timeout
	if PlayerState.get_pending_trip_selection().is_empty():
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return

	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
