class_name LDMusicHandler
extends LDComponent

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
	var playlist: Array[String] = LDEditorConfig.get_ld_playlist()
	if playlist.is_empty():
		return
	var id: String = playlist.pick_random()
	song_label.text = LDMusicDB.get_display_name(id)
	audio_stream_player.stream = LDMusicDB.get_stream(id)
	audio_stream_player.play()
	animation_player.play(&"new_song")
