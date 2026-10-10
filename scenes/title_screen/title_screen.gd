extends Control

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var blur_panel: Panel


func _ready() -> void:
	audio_stream_player.play()
	animation_player.play(&"intro")



func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_1: 
				animation_player.play("open")
			#KEY_2: animation_player.play_backwards("open")


func _on_settings_button_pressed() -> void:
	if not animation_player.is_playing():
		animation_player.play("show_settings")
		GDSS.set_state(blur_panel, "open")
