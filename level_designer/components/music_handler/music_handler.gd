class_name LDMusicHandler
extends LDComponent

@export var tracks: Array[AudioStream]
@export_group("Internal")
@export var audio_stream_player: AudioStreamPlayer


func _on_ready() -> void:
	if not tracks.is_empty():
		audio_stream_player.stream = tracks.pick_random()
	
	# DEBUG
	#if FileAccess.file_exists("uid://du5a7t1kcdnm7"):
		#var debug_track: AudioStream = load("uid://du5a7t1kcdnm7")
		#if debug_track:
			#audio_stream_player.stream = debug_track
	
	audio_stream_player.play()
