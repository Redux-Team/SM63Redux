class_name LDMusicHandler
extends LDComponent


const SILENCE_DB: float = -40.0
const RESUME_BUFFER: float = 0.6
const RESUME_FADE: float = 2.0


signal track_changed(id: String)


@export var song_label: Label
@export_group("Internal")
@export var audio_stream_player: AudioStreamPlayer
@export var animation_player: AnimationPlayer


var _current_id: String = ""
var _looping: bool = false
var _base_volume_db: float = 0.0
var _preview_ducked: bool = false
var _fade: Tween


func _on_ready() -> void:
	_base_volume_db = audio_stream_player.volume_db
	_looping = LDEditorConfig.get_ld_loop()
	song_label.self_modulate = Color.TRANSPARENT
	song_label.show()
	audio_stream_player.finished.connect(new_track)
	new_track()


func new_track() -> void:
	var playlist: Array[String] = LDEditorConfig.get_ld_playlist()
	if playlist.is_empty():
		return
	var id: String = playlist.pick_random()
	if playlist.size() > 1:
		while id == _current_id:
			id = playlist.pick_random()
	_play_id(id)


func skip() -> void:
	new_track()


func _play_id(id: String) -> void:
	_current_id = id
	song_label.text = LDMusicDB.get_display_name(id)
	audio_stream_player.stream = _apply_loop(LDMusicDB.get_stream(id), id)
	audio_stream_player.volume_db = _base_volume_db
	audio_stream_player.stream_paused = false
	audio_stream_player.play()
	animation_player.play(&"new_song")
	track_changed.emit(id)


func _apply_loop(stream: AudioStream, id: String) -> AudioStream:
	if stream == null or not _looping:
		return stream
	var copy: AudioStream = stream.duplicate() as AudioStream
	var loop_start: float = LDMusicDB.get_loop_start(id)
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
		(copy as AudioStreamOggVorbis).loop_offset = loop_start
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
		(copy as AudioStreamMP3).loop_offset = loop_start
	elif copy is AudioStreamWAV:
		var wav: AudioStreamWAV = copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(loop_start * float(wav.mix_rate))
	return copy


func get_current_id() -> String:
	return _current_id


func is_paused() -> bool:
	return audio_stream_player.stream_paused


func toggle_pause() -> void:
	audio_stream_player.stream_paused = not audio_stream_player.stream_paused


func is_looping() -> bool:
	return _looping


func set_loop(value: bool) -> void:
	if _looping == value:
		return
	_looping = value
	LDEditorConfig.set_ld_loop(value)
	if _current_id.is_empty():
		return
	var pos: float = audio_stream_player.get_playback_position()
	audio_stream_player.stream = _apply_loop(LDMusicDB.get_stream(_current_id), _current_id)
	audio_stream_player.play()
	audio_stream_player.seek(pos)


func pause_for_preview() -> void:
	_kill_fade()
	if not audio_stream_player.stream_paused:
		_preview_ducked = true
		audio_stream_player.stream_paused = true


func resume_after_preview() -> void:
	if not _preview_ducked:
		return
	_preview_ducked = false
	_kill_fade()
	_fade = create_tween()
	_fade.tween_interval(RESUME_BUFFER)
	_fade.tween_callback(_resume_silent)
	_fade.tween_property(audio_stream_player, "volume_db", _base_volume_db, RESUME_FADE)


func _resume_silent() -> void:
	audio_stream_player.volume_db = SILENCE_DB
	audio_stream_player.stream_paused = false


func _kill_fade() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	audio_stream_player.volume_db = _base_volume_db
