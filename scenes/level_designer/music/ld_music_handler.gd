class_name LDMusicHandler
extends LDHandler

const SLIDE_TIME: float = 0.2
const REVEAL_TIME: float = 0.35
const HOLD_TIME: float = 3.8
const BAR_CLEARANCE: float = 8.0

@export var player: AudioStreamPlayer
@export_group("Song Island")
@export var song_panel: PanelContainer
@export var song_row: HBoxContainer
@export var song_icon: TextureRect
@export var song_clip: Control
@export var song_label: Label
@export var left_bar: Control
@export var right_bar: Control

var _track: MusicTrack
var _tween: Tween


func _setup() -> void:
	song_panel.hide()
	player.finished.connect(_next_track)
	Settings.level_designer.music_changed.connect(_refresh)
	_next_track()


func get_track() -> MusicTrack:
	return _track


func skip() -> void:
	_next_track()


func _refresh() -> void:
	if _track == null or not Settings.level_designer.get_editor_tracks().has(_track):
		_next_track()
		return
	
	var at: float = player.get_playback_position()
	player.stream = _stream_for(_track)
	player.play(at)


func _next_track() -> void:
	var pool: Array[MusicTrack] = Settings.level_designer.get_editor_tracks()
	if pool.size() > 1:
		pool.erase(_track)
	if pool.is_empty():
		_track = null
		player.stop()
		if _tween:
			_tween.kill()
		song_panel.hide()
		return
	
	_track = pool.pick_random()
	player.stream = _stream_for(_track)
	player.play()
	_announce()


func _stream_for(track: MusicTrack) -> AudioStream:
	return track.get_looped_stream() if Settings.level_designer.loop_music.current_value else track.get_stream()


func _announce() -> void:
	song_label.text = _track.display_name
	song_label.size = song_label.get_combined_minimum_size()
	if _tween:
		_tween.kill()
	
	song_panel.show()
	_set_reveal(0.0)
	var shown: float = left_bar.position.y + (left_bar.size.y - song_panel.size.y) * 0.5
	var hidden: float = -song_panel.size.y
	_tween = create_tween()
	if not Settings.ui.animations.current_value:
		_set_reveal(1.0)
		song_panel.position.y = shown
		_tween.tween_interval(REVEAL_TIME + HOLD_TIME + SLIDE_TIME * 3.0)
		_tween.tween_callback(song_panel.hide)
		return
	
	song_panel.position.y = hidden
	_tween.tween_property(song_panel, ^"position:y", shown, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_reveal, 0.0, 1.0, REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_method(_set_reveal, 1.0, 0.0, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(song_panel, ^"position:y", hidden, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(song_panel.hide)


func _set_reveal(amount: float) -> void:
	var line: float = maxf(song_label.size.y, song_icon.custom_minimum_size.y)
	var chrome: Vector2 = song_panel.get_theme_stylebox(&"panel").get_minimum_size() + Vector2(song_icon.custom_minimum_size.x, line)
	var start: float = left_bar.get_rect().end.x + BAR_CLEARANCE
	var room: float = right_bar.position.x - BAR_CLEARANCE - start
	var reveal: float = clampf(amount * song_label.size.x, 0.0, maxf(room - chrome.x - song_row.get_theme_constant(&"separation"), 0.0))
	song_clip.visible = reveal > 0.0
	song_clip.custom_minimum_size = Vector2(reveal, line)
	var width: float = chrome.x + (reveal + song_row.get_theme_constant(&"separation") if song_clip.visible else 0.0)
	song_panel.size = Vector2(width, chrome.y)
	song_panel.position.x = start + (room - width) * 0.5
