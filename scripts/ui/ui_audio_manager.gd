extends Node

const UI_HOVER_STREAM_PATH := "res://assets/ui/fx/ui_hover.mp3"
const UI_PRESS_STREAM_PATH := "res://assets/ui/fx/ui_press.mp3"
const HOVER_COOLDOWN_SECONDS := 0.05

var hover_player: AudioStreamPlayer
var press_player: AudioStreamPlayer
var last_hover_time_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hover_player = AudioStreamPlayer.new()
	hover_player.name = "HoverPlayer"
	hover_player.bus = "Master"
	hover_player.stream = load(UI_HOVER_STREAM_PATH)
	add_child(hover_player)
	AudioSettingsManager.register_player(hover_player, "ui")

	press_player = AudioStreamPlayer.new()
	press_player.name = "PressPlayer"
	press_player.bus = "Master"
	press_player.stream = load(UI_PRESS_STREAM_PATH)
	add_child(press_player)
	AudioSettingsManager.register_player(press_player, "ui")


func attach_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	if bool(button.get_meta("ui_audio_attached", false)):
		return

	button.set_meta("ui_audio_attached", true)
	button.set_meta("ui_audio_skip_first_focus", true)
	button.mouse_entered.connect(func() -> void:
		play_hover()
	)
	button.focus_entered.connect(func() -> void:
		if bool(button.get_meta("ui_audio_skip_first_focus", false)):
			button.set_meta("ui_audio_skip_first_focus", false)
			return
		play_hover()
	)
	button.pressed.connect(func() -> void:
		play_press()
	)


func play_hover() -> void:
	if hover_player == null or hover_player.stream == null:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_hover_time_msec < int(HOVER_COOLDOWN_SECONDS * 1000.0):
		return
	last_hover_time_msec = now_msec
	hover_player.play()


func play_press() -> void:
	if press_player == null or press_player.stream == null:
		return
	press_player.play()
