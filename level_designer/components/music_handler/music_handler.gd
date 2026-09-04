class_name LDMusicHandler
extends Node


const SILENCE_DB: float = -40.0
const RESUME_BUFFER: float = 0.6
const RESUME_FADE: float = 2.0


signal track_changed(id: String)


@export var song_label: Label
@export_group("Island")
## Clear space kept between the island and each of the two top bars.
@export var bar_clearance: float = 8.0
## Debug: replays the entrance for the current track instead of waiting for one to end.
@export var replay_key: Key = KEY_F9
## Driven by the "new_song" animation. 0 closes the island down to its icon, 1 opens it to the
## whole title, and overshooting past 1 is what gives the horizontal bounce.
@export_range(0.0, 1.5, 0.01) var expand: float = 0.0:
	set(e):
		expand = e
		_apply_expand()
@export_subgroup("Marquee")
## Pixels a second a title too long for the gap slides at, and how long it rests at each end
## before turning around.
@export var scroll_speed: float = 40.0
@export var scroll_hold: float = 0.9
@export_group("Internal")
@export var song_panel: PanelContainer
@export var song_slot: Control
@export var song_clip: Control
@export var song_icon: TextureRect
@export var song_row: HBoxContainer
@export var song_margin: MarginContainer
@export var audio_stream_player: AudioStreamPlayer
@export var animation_player: AnimationPlayer


var _current_id: String = ""
var _looping: bool = false
var _base_volume_db: float = 0.0
var _preview_ducked: bool = false
var _fade: Tween
var _scroll: Tween
var _hold: Tween
var _scroll_span: float = 0.0
## Island geometry. Only what the title itself decides is kept: where the bars are is read back
## fresh every time, since they settle after this handler is set up and it is their position that
## moves, which is not a resize there is any signal for.
var _chrome: Vector2 = Vector2.ZERO
var _line: float = 0.0
var _text_width: float = 0.0


func setup() -> void:
	_base_volume_db = audio_stream_player.volume_db
	_looping = LDEditorConfig.get_ld_loop()
	animation_player.play(&"RESET")
	song_panel.show()
	get_viewport().size_changed.connect(_lay_out_song)
	# The chrome has not been sorted yet when this runs, so the first measurement of the gap comes
	# back empty. item_rect_changed rather than resized: the bars settle into place by moving, and
	# the right-hand one keeps its width while it does, which resized would never report.
	LD.get_ui().get_top_bar_left().item_rect_changed.connect(_lay_out_song)
	LD.get_ui().get_top_bar_right().item_rect_changed.connect(_lay_out_song)
	animation_player.animation_finished.connect(_on_announce_finished)
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


## Replays the island's entrance for whatever is playing. Bound to the debug key as well as every
## track change, so the animation can be watched without waiting a song out.
func announce() -> void:
	_lay_out_song()
	if is_instance_valid(_hold):
		_hold.kill()
	if not Settings.get_bool(&"display/ui_animations"):
		_announce_still()
		return
	animation_player.play(&"new_song")
	animation_player.seek(0.0, true)


## With UI animations off the island still has to come and go - the track name is the whole point
## of it - so it snaps to its resting pose, sits out the span the animation would have taken, and
## snaps back. The wait is read off the animation itself, so retiming that keeps the two in step.
func _announce_still() -> void:
	animation_player.stop()
	song_panel.position.y = 0.0
	expand = 1.0
	_hold = create_tween()
	_hold.tween_interval(animation_player.get_animation(&"new_song").length)
	_hold.tween_callback(animation_player.play.bind(&"RESET"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo or key.keycode != replay_key:
		return
	if LD.has_input_capture():
		return
	announce()
	get_viewport().set_input_as_handled()


## Measures the island against its title and the room between the two top bars. Everything is
## worked out from the fonts and the nodes rather than read back off the containers, so the
## island is placed the same frame the title changes instead of a frame later.
func _lay_out_song() -> void:
	if not is_instance_valid(song_panel) or not LD.is_ready():
		return
	
	var font: Font = song_label.get_theme_font(&"font")
	var font_size: int = song_label.get_theme_font_size(&"font_size")
	_text_width = font.get_string_size(song_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_line = maxf(font.get_height(font_size), song_icon.custom_minimum_size.x)
	song_label.size = Vector2(_text_width, _line)
	song_icon.custom_minimum_size.y = _line
	song_clip.custom_minimum_size.y = _line
	_chrome = _panel_chrome()
	
	_apply_expand()
	_scroll_song(_text_width - minf(_text_width, _title_room()))


## Opens the island around its own centre so it grows out of the icon rather than off to one side.
## Closed, the clip is dropped entirely, which takes the row's separation with it and leaves a pill
## exactly as wide as the icon.
func _apply_expand() -> void:
	if not is_instance_valid(song_clip) or not LD.is_ready():
		return
	
	var ui_scale: float = LDUI.get_ui_scale()
	var band: Rect2 = _bar_band()
	var gap: Vector2 = _bar_gap(band, ui_scale)
	var room: float = _room_in(gap, ui_scale)
	var shown: float = minf(maxf(expand, 0.0) * minf(_text_width, room), room)
	
	song_clip.visible = shown > 0.0
	song_clip.custom_minimum_size.x = shown
	var width: float = _chrome.x + shown
	if not song_clip.visible:
		width -= song_row.get_theme_constant(&"separation")
	# Sized outright rather than left to its own minimum: a Control grows to fit a minimum that
	# has gone up but keeps the offsets it grew into, so the island would never close again.
	song_panel.size = Vector2(width, _chrome.y + _line)
	song_slot.scale = Vector2(ui_scale, ui_scale)
	song_slot.position = Vector2(
		gap.x + (gap.y - width * ui_scale) * 0.5,
		band.get_center().y - (_chrome.y + _line) * ui_scale * 0.5
	)


## Width the title has to play with, in the island's own units.
func _title_room() -> float:
	var ui_scale: float = LDUI.get_ui_scale()
	return _room_in(_bar_gap(_bar_band(), ui_scale), ui_scale)


func _room_in(gap: Vector2, ui_scale: float) -> float:
	return maxf(gap.y / ui_scale - _chrome.x, 0.0)


## Width and height the island spends on itself before the title gets any: the Bar stylebox, the
## padding inside it, the icon and the gap after it. Read off the nodes, so the scene stays the one
## place those are set.
func _panel_chrome() -> Vector2:
	var pad: Vector2 = Vector2(
		song_margin.get_theme_constant(&"margin_left") + song_margin.get_theme_constant(&"margin_right"),
		song_margin.get_theme_constant(&"margin_top") + song_margin.get_theme_constant(&"margin_bottom")
	)
	var lead: float = song_icon.custom_minimum_size.x + song_row.get_theme_constant(&"separation")
	return song_panel.get_theme_stylebox(&"panel").get_minimum_size() + pad + Vector2(lead, 0.0)


## Left edge and width of the clear run between the two top bars, in screen pixels.
func _bar_gap(band: Rect2, ui_scale: float) -> Vector2:
	var clearance: float = bar_clearance * ui_scale
	var start: float = band.position.x + clearance
	return Vector2(start, maxf(band.end.x - clearance - start, 0.0))


func _bar_band() -> Rect2:
	var left: Rect2 = LD.get_ui().get_top_bar_left().get_global_rect()
	var right: Rect2 = LD.get_ui().get_top_bar_right().get_global_rect()
	return Rect2(left.end.x, left.position.y, right.position.x - left.end.x, left.size.y)


## Slides a title that outruns its room back and forth, the way a car stereo does. Left alone when
## it already fits, and left running when a relayout lands on the same title.
func _scroll_song(overflow: float) -> void:
	if is_equal_approx(overflow, _scroll_span) and is_instance_valid(_scroll) and _scroll.is_running():
		return
	_scroll_span = overflow
	if is_instance_valid(_scroll):
		_scroll.kill()
	song_label.position.x = 0.0
	if overflow <= 0.0 or not Settings.get_bool(&"display/ui_animations"):
		return
	
	var travel: float = overflow / scroll_speed
	_scroll = create_tween().set_loops()
	_scroll.tween_interval(scroll_hold)
	_scroll.tween_property(song_label, ^"position:x", -overflow, travel).set_trans(Tween.TRANS_SINE)
	_scroll.tween_interval(scroll_hold)
	_scroll.tween_property(song_label, ^"position:x", 0.0, travel).set_trans(Tween.TRANS_SINE)


func _on_announce_finished(_name: StringName) -> void:
	if is_instance_valid(_scroll):
		_scroll.kill()


func skip() -> void:
	new_track()


func _play_id(id: String) -> void:
	_current_id = id
	song_label.text = LDMusicDB.get_display_name(id)
	audio_stream_player.stream = _apply_loop(LDMusicDB.get_stream(id), id)
	audio_stream_player.volume_db = _base_volume_db
	audio_stream_player.stream_paused = false
	audio_stream_player.play()
	announce()
	track_changed.emit(id)


func _apply_loop(stream: AudioStream, id: String) -> AudioStream:
	if stream == null or not _looping:
		return stream
	return LDMusicDB.get_looped_stream(id)


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
