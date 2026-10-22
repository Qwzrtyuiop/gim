extends Control

const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const SLEEP_SCENE := "res://scenes/sleep_transition.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const REPAIR_AUDIO_PATH := "res://assets/audio/ambience/repair.mp3"
const DOT_INTERVAL_SECONDS := 0.5

@onready var title_label: Label = $Center/Panel/Content/Title
@onready var duration_label: Label = $Center/Panel/Content/Duration
@onready var bill_label: Label = $Center/Panel/Content/Bill
@onready var balance_label: Label = $Center/Panel/Content/Balance
@onready var next_day_label: Label = $Center/Panel/Content/NextDay
@onready var continue_button: Button = $Center/Panel/Content/Continue

var is_transitioning := false
var dot_count := 1
var repair_audio_player: AudioStreamPlayer


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
	next_day_label.text = "Repairs will be finished on Day %d, morning.\nYour trip ended without a fare." % int(repair["target_day"])
	_start_repair_presentation()
	continue_button.pressed.connect(_continue_repair)
	ButtonGlow.attach(self, continue_button)
	continue_button.grab_focus()


func _start_repair_presentation() -> void:
	_update_repair_title()
	var timer := Timer.new()
	timer.name = "RepairDotsTimer"
	timer.wait_time = DOT_INTERVAL_SECONDS
	timer.timeout.connect(func() -> void:
		dot_count = dot_count % 3 + 1
		_update_repair_title()
	)
	add_child(timer)
	timer.start()
	var stream := load(REPAIR_AUDIO_PATH).duplicate() as AudioStreamMP3
	stream.loop = true
	repair_audio_player = AudioStreamPlayer.new()
	repair_audio_player.name = "RepairAmbience"
	repair_audio_player.stream = stream
	add_child(repair_audio_player)
	AudioSettingsManager.register_player(repair_audio_player, "sfx")
	repair_audio_player.play()


func _update_repair_title() -> void:
	# Pad the dots so the centered title keeps the same width throughout the loop.
	title_label.text = "REPAIRING" + ".".repeat(dot_count).rpad(3, " ")


func _continue_repair() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	continue_button.disabled = true
	if PlayerState.start_crash_repair_transition():
		get_tree().change_scene_to_file(SLEEP_SCENE)
	else:
		get_tree().change_scene_to_file(HOME_SCENE)
