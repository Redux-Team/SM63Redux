class_name LDMusicHandler
extends LDComponent

@export var tracks: Dictionary[String, AudioStream]
@export_group("Internal")
@export var audio_stream_player: AudioStreamPlayer


func _on_ready() -> void:
	if not tracks.is_empty():
		var selected_track_name: String = tracks.keys().pick_random()
		audio_stream_player.stream = tracks.get(selected_track_name)
	
	audio_stream_player.play()
