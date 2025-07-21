extends Control

@export var animation_player: AnimationPlayer
@export var title_loop: AudioStreamPlayer
@export var menu_loop: AudioStreamPlayer
@export var splash_fade: ColorRect

@export var version_label: Label
@export var team_text: Label
@export var splash_screen: Control
@export var menu_screen: Control
@export var start_text: RichTextLabel

@export var input_locked: bool = false


var on_splash_screen: bool = true
var on_settings_screen: bool = false


func _ready() -> void:
	animation_player.play(&"title_in")
	title_loop.play()
	menu_loop.play()
	menu_loop.stream_paused = true
	Singleton.input_type_changed.connect(_on_input_type_changed)
	_on_input_type_changed()
	
	version_label.text = "v" + Singleton.version


func _input(event: InputEvent) -> void:
	if input_locked:
		return
	
	if (event.is_action_pressed(&"_ui_interact") or event is InputEventScreenTouch) and on_splash_screen:
		_switch_to_menu_screen()
	
	elif event.is_action(&"_ui_back") and event.is_pressed():
		if on_settings_screen:
			_on_settings_screen_exit_request()
		elif not on_splash_screen:
			_switch_to_splash_screen()


# this is handled manually in case the splash screen
# is exited early, that way we can just call this immediately.
func _show_bottom_text() -> void:
	var bottom_text_tween: Tween = get_tree().create_tween()
	bottom_text_tween.set_parallel(true)
	bottom_text_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	bottom_text_tween.tween_property(team_text, ^"anchor_top", 0.931, 0.45)
	bottom_text_tween.tween_property(version_label, ^"anchor_top", 0.931, 0.45)
	bottom_text_tween.tween_property(team_text, ^"anchor_bottom", 1.0, 0.45)
	bottom_text_tween.tween_property(version_label, ^"anchor_bottom", 1.0, 0.45)


func _switch_to_splash_screen() -> void:
	if on_splash_screen:
		return
	
	input_locked = true
	
	# skip to the looping segment if the song was cut off before the beat drop
	if title_loop.get_playback_position() < 4.250:
		title_loop.play(4.250)
	
	animation_player.play(&"switch_to_splash_screen")
	menu_loop.play()
	on_splash_screen = true
	SFX.play(SFX.UI_BACK)

	await get_tree().process_frame
	input_locked = false



func _switch_to_menu_screen() -> void:
	if not on_splash_screen:
		return
	
	SFX.play(SFX.UI_CONFIRM)
	on_splash_screen = false
	animation_player.play(&"switch_to_menu_screen")


func _switch_from_settings_screen() -> void:
	animation_player.play(&"switch_from_settings_screen", -1, 1.7)
	on_settings_screen = false
	SFX.play(SFX.UI_BACK)


func _on_settings_screen_exit_request() -> void:
	_switch_from_settings_screen()
	Config.save()


func _on_input_type_changed() -> void:
	var type: Singleton.InputType = Singleton.current_input_device
	
	if type == Singleton.InputType.TOUCHSCREEN:
		start_text.text = "Touch the screen to begin!"
		return
	
	start_text.text = "Press %s to begin!" % ControlScheme.get_hint("_ui_interact")


func _on_menu_back_button_pressed() -> void:
	_switch_to_splash_screen()
