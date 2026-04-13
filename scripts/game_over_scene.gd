extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GAME_OVER_BGM_PATH := "res://assets/story/music/truth.mp3"
const DEBT_FAIL_PATTERN := "Debt collector came for PhP "

@onready var message_label: Label = $Panel/MessageLabel
@onready var menu_button: BaseButton = $Panel/MenuButton
@onready var reset_button: BaseButton = $Panel/ResetButton

var bgm_player: AudioStreamPlayer


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/game_over.tscn")
	message_label.text = _build_game_over_message()
	_apply_button_font(menu_button)
	_apply_button_font(reset_button)
	ButtonGlow.attach(self, menu_button)
	ButtonGlow.attach(self, reset_button)
	menu_button.pressed.connect(_go_to_menu)
	reset_button.pressed.connect(_reset_progress)
	reset_button.grab_focus()
	_start_game_over_bgm()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_to_menu()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _reset_progress() -> void:
	PlayerState.reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_game_over_message() -> String:
	var fail_reason := PlayerState.get_run_fail_reason()
	if fail_reason.begins_with(DEBT_FAIL_PATTERN):
		var details := _extract_debt_failure_details(fail_reason)
		var amount := int(details.get("amount", 0))
		var day_number := int(details.get("day", 0))
		var opening := "The payment for Day %d never came." % day_number if day_number > 0 else "The payment never came."
		if amount > 0:
			opening = "The PhP %d payment for Day %d never came." % [amount, day_number] if day_number > 0 else "The PhP %d payment never came." % amount
		return "%s\n\nBy the time people started asking where John had gone, he was already missing from the routes, the terminals, and the city itself.\n\nSome said he ran before the debt could catch up. Others said the city simply swallowed him whole.\n\nEither way, John was never seen in the city again." % opening
	return fail_reason


func _extract_debt_failure_details(text: String) -> Dictionary:
	var pattern := RegEx.new()
	var compile_result := pattern.compile("Debt collector came for PhP (\\d+) on Day (\\d+)\\.")
	if compile_result != OK:
		return {}
	var match := pattern.search(text)
	if match == null:
		return {}
	return {
		"amount": int(match.get_string(1)),
		"day": int(match.get_string(2)),
	}


func _start_game_over_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "GameOverBGMPlayer"
	bgm_player.stream = load(GAME_OVER_BGM_PATH)
	bgm_player.autoplay = false
	bgm_player.bus = &"Master"
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func _apply_button_font(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.20, 0.10, 0.05, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.20, 0.10, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.20, 0.10, 0.05, 1.0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
