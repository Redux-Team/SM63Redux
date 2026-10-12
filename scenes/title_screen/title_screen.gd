extends Control

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var blur_panel: Panel
@export var settings_screen: SettingsScreen


func _ready() -> void:
	audio_stream_player.play()
	animation_player.play(&"intro")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_1:
		animation_player.play("open")


func _on_settings_button_pressed() -> void:
	if not animation_player.is_playing():
		settings_screen.open()
		animation_player.play("show_settings")
		GDSS.set_state(blur_panel, "open")


func _on_settings_screen_closed() -> void:
	animation_player.play("hide_settings")
	GDSS.clear_state(blur_panel)
