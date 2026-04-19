class_name LDMusicHandler
extends LDComponent

@export var tracks: Dictionary[String, AudioStream]
@export var song_label: Label
@export_group("Internal")
@export var audio_stream_player: AudioStreamPlayer
@export var animation_player: AnimationPlayer


func _on_ready() -> void:
	new_track()
	song_label.self_modulate = Color.TRANSPARENT
	song_label.show()
	audio_stream_player.finished.connect(new_track)


func new_track() -> void:
	if not tracks.is_empty():
		var selected_track_name: String = tracks.keys().pick_random()
		song_label.text = selected_track_name
		audio_stream_player.stream = tracks.get(selected_track_name)
	
	audio_stream_player.play()
	animation_player.play(&"new_song")
