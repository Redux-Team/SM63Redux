extends Node

const VERSION: StringName = &"0.2.0"

@export var sfx_container: Node


func play_sfx(stream: AudioStream) -> void:
	var audio_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_stream_player.bus = &"SFX"
	audio_stream_player.stream = stream
	
	sfx_container.add_child(audio_stream_player)
	
	audio_stream_player.finished.connect(func() -> void:
		audio_stream_player.queue_free()
	)
	
	audio_stream_player.play()
