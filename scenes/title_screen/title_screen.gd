extends Control

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer


func _ready() -> void:
	audio_stream_player.play()
	animation_player.play(&"intro")



#func _input(event: InputEvent) -> void:
	#if event is InputEventKey:
		#match event.keycode:
			#KEY_1: animation_player.play("open")
			#KEY_2: animation_player.play_backwards("open")
