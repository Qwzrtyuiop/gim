extends Control

const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const SLEEP_SCENE := "res://scenes/sleep_transition.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")

@onready var duration_label: Label = $Center/Panel/Content/Duration
@onready var bill_label: Label = $Center/Panel/Content/Bill
@onready var balance_label: Label = $Center/Panel/Content/Balance
@onready var next_day_label: Label = $Center/Panel/Content/NextDay
@onready var continue_button: Button = $Center/Panel/Content/Continue

var is_transitioning := false


func _ready() -> void:
	var repair := PlayerState.get_pending_crash_repair()
	if repair.is_empty():
		get_tree().change_scene_to_file(GAME_OVER_SCENE if PlayerState.is_run_failed() else HOME_SCENE)
		return
	if bool(repair.get("transition_started", false)):
		get_tree().change_scene_to_file(SLEEP_SCENE)
		return
	PlayerState.set_resume_scene(REPAIR_SCENE)
	var days := int(repair["days"])
	duration_label.text = "%d %s OFF THE ROAD" % [days, "DAY" if days == 1 else "DAYS"]
	bill_label.text = "REPAIR BILL: PhP %d" % int(repair["cost"])
	balance_label.text = "Cash remaining: PhP %d" % int(repair["cash_after"])
	next_day_label.text = "Repairs finished on Day %d, morning.\nYour trip ended without a fare." % int(repair["target_day"])
	continue_button.pressed.connect(_continue_repair)
	ButtonGlow.attach(self, continue_button)
	continue_button.grab_focus()


func _continue_repair() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	continue_button.disabled = true
	if PlayerState.start_crash_repair_transition():
		get_tree().change_scene_to_file(SLEEP_SCENE)
	else:
		get_tree().change_scene_to_file(HOME_SCENE)
