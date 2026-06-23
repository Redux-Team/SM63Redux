class_name LDMusicEditor
extends MarginContainer


const NONE_ID: String = ""
const UPLOAD_ID: String = "__upload__"
const PREVIEW_BUS: StringName = &"LDPreview"
const SCAN_BUS: StringName = &"LDScan"
const SCAN_PITCH: float = 40.0
const SCAN_VOLUME_DB: float = -80.0
const TRIGGER_NAMES: Dictionary = {
	LDMusicSubtrack.Trigger.UNDERWATER: "Underwater",
	LDMusicSubtrack.Trigger.REGION: "Region",
}
const UNDERWATER_NAMES: Dictionary = {
	LDMusic.UnderwaterMode.MUFFLE: "Muffle",
	LDMusic.UnderwaterMode.TRACK: "Track",
	LDMusic.UnderwaterMode.IGNORE: "Ignore",
}


@export var base_option: OptionButton
@export var base_preview: Button
@export var layer_list: VBoxContainer
@export var add_button: Button
@export var upload_button: Button
@export var preview_player: AudioStreamPlayer
@export var level_panel: Control
@export var ld_panel: Control
@export var level_tab: Button
@export var ld_tab: Button
@export var ld_list: VBoxContainer
@export var play_button: Button
@export var time_label: Label
@export var now_playing_label: Label
@export var waveform: LDWaveformView
@export var ambient_now_label: Label
@export var ambient_play_button: Button
@export var ambient_ff_button: Button
@export var ambient_loop_button: Button
@export var preset_option: OptionButton
@export var underwater_option: OptionButton
@export var loop_spin: SpinBox


var _now_playing: String = NONE_ID
var _scanner: AudioStreamPlayer
var _preview_capture: AudioEffectCapture
var _scan_capture: AudioEffectCapture
var _wave_cache: Dictionary = {}
var _scanning: bool = false
var _scan_track: String = NONE_ID
var _scan_length: float = 0.0


func _ready() -> void:
	_setup_buses()
	base_option.item_selected.connect(_on_base_selected)
	base_preview.pressed.connect(_on_base_preview)
	add_button.pressed.connect(_on_add_triggered)
	upload_button.pressed.connect(_on_upload_pressed)
	level_tab.pressed.connect(_select_level_tab)
	ld_tab.pressed.connect(_select_ld_tab)
	play_button.pressed.connect(_on_play_pressed)
	waveform.seek_requested.connect(_on_seek)
	ambient_play_button.pressed.connect(_on_ambient_play)
	ambient_ff_button.pressed.connect(_on_ambient_ff)
	ambient_loop_button.toggled.connect(_on_ambient_loop_toggled)
	preset_option.item_selected.connect(_on_preset_selected)
	underwater_option.item_selected.connect(_on_underwater_selected)
	loop_spin.value_changed.connect(_on_loop_changed)
	_populate_underwater()
	_update_now_playing()
	_update_play_button()
	if LDLevel._inst and not LDLevel._inst.active_area_changed.is_connected(_on_area_changed):
		LDLevel._inst.active_area_changed.connect(_on_area_changed)


func _setup_buses() -> void:
	_preview_capture = _ensure_capture_bus(PREVIEW_BUS, 0.0)
	_scan_capture = _ensure_capture_bus(SCAN_BUS, SCAN_VOLUME_DB)
	preview_player.bus = PREVIEW_BUS
	_scanner = AudioStreamPlayer.new()
	_scanner.bus = SCAN_BUS
	_scanner.pitch_scale = SCAN_PITCH
	add_child(_scanner)


func _ensure_capture_bus(bus_name: StringName, volume_db: float) -> AudioEffectCapture:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
		idx = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, volume_db)
	return AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture


func _exit_tree() -> void:
	_remove_bus(PREVIEW_BUS)
	_remove_bus(SCAN_BUS)


func _remove_bus(bus_name: StringName) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.remove_bus(idx)


func _process(_delta: float) -> void:
	if preview_player.stream != null:
		var length: float = preview_player.stream.get_length()
		if length > 0.0:
			var pos: float = preview_player.get_playback_position()
			var fraction: float = clampf(pos / length, 0.0, 1.0)
			_drain_capture(_preview_capture, fraction)
			waveform.set_progress(fraction)
			_update_time(pos, length)
	if _scanning:
		_poll_scan()
	if ld_panel.visible:
		_refresh_ambient()


func _drain_capture(capture: AudioEffectCapture, fraction: float) -> void:
	if capture == null:
		return
	var available: int = capture.get_frames_available()
	if available <= 0:
		return
	var frames: PackedVector2Array = capture.get_buffer(available)
	var peak: float = 0.0
	for frame: Vector2 in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	waveform.write_peak(fraction, peak)


func _poll_scan() -> void:
	if _scan_length > 0.0:
		var fraction: float = clampf(_scanner.get_playback_position() / _scan_length, 0.0, 1.0)
		_drain_capture(_scan_capture, fraction)
	if not _scanner.playing:
		_scanning = false
		var bins: PackedFloat32Array = waveform.get_bins()
		var loudest: float = 0.0
		for value: float in bins:
			loudest = maxf(loudest, value)
		if loudest > 0.02:
			_wave_cache[_scan_track] = bins


func _on_show() -> void:
	_set_ambient_ducked(false)
	_select_level_tab()
	_refresh()
	_build_ld_playlist()
	var handler: LDMusicHandler = _ambient()
	if handler and not handler.track_changed.is_connected(_on_ambient_track_changed):
		handler.track_changed.connect(_on_ambient_track_changed)
	_refresh_ambient()


func _on_hide() -> void:
	preview_player.stop()
	_stop_scan()
	_set_ambient_ducked(false)
	_now_playing = NONE_ID
	waveform.clear_bins()
	loop_spin.editable = false
	loop_spin.set_value_no_signal(0.0)
	_update_now_playing()
	_update_play_button()


func _on_loop_changed(value: float) -> void:
	if not LDMusicDB.is_custom(_now_playing):
		return
	LDMusicDB.set_custom_loop_start(_now_playing, value)
	var stream: AudioStream = preview_player.stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop_offset = value
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop_offset = value
	_persist()


func _set_ambient_ducked(ducked: bool) -> void:
	var handler: LDMusicHandler = _ambient()
	if handler == null:
		return
	if ducked:
		handler.pause_for_preview()
	else:
		handler.resume_after_preview()


func _ambient() -> LDMusicHandler:
	if not LD.is_ready():
		return null
	var handler: LDMusicHandler = LD.get_music_handler()
	return handler if is_instance_valid(handler) else null


func _on_ambient_play() -> void:
	var handler: LDMusicHandler = _ambient()
	if handler:
		handler.toggle_pause()
	_refresh_ambient()


func _on_ambient_ff() -> void:
	var handler: LDMusicHandler = _ambient()
	if handler:
		handler.skip()
	_refresh_ambient()


func _on_ambient_loop_toggled(on: bool) -> void:
	var handler: LDMusicHandler = _ambient()
	if handler:
		handler.set_loop(on)


func _on_ambient_track_changed(_id: String) -> void:
	_refresh_ambient()


func _refresh_ambient() -> void:
	var handler: LDMusicHandler = _ambient()
	if handler == null:
		return
	var id: String = handler.get_current_id()
	ambient_now_label.text = LDMusicDB.get_display_name(id) if not id.is_empty() else "Nothing playing"
	ambient_play_button.text = "▶" if handler.is_paused() else "⏸"
	ambient_loop_button.set_pressed_no_signal(handler.is_looping())


func _select_level_tab() -> void:
	level_tab.set_pressed_no_signal(true)
	level_panel.visible = true
	ld_panel.visible = false


func _select_ld_tab() -> void:
	ld_tab.set_pressed_no_signal(true)
	level_panel.visible = false
	ld_panel.visible = true
	_build_ld_playlist()


func _build_ld_playlist() -> void:
	for child: Node in ld_list.get_children():
		child.queue_free()
	for id: String in LDMusicDB.get_track_ids_in(LDMusicDB.CATEGORY_LD):
		ld_list.add_child(_build_ld_row(id))


func _build_ld_row(id: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var check: CheckButton = CheckButton.new()
	check.text = LDMusicDB.get_display_name(id)
	check.clip_text = true
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.button_pressed = LDEditorConfig.is_ld_track_enabled(id)
	check.toggled.connect(func(pressed: bool) -> void: LDEditorConfig.set_ld_track_enabled(id, pressed))
	row.add_child(check)
	var preview: Button = Button.new()
	preview.text = "▶"
	preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview.pressed.connect(func() -> void: _preview(id))
	row.add_child(preview)
	return row


func _on_area_changed(_area: LDArea) -> void:
	_refresh()


func _music() -> LDMusic:
	var area: LDArea = LD.get_area()
	if area.music == null:
		area.music = LDMusic.new()
	return area.music


func _persist() -> void:
	LD.get_save_load_handler().save_session()


func _base_layer() -> LDMusicSubtrack:
	for layer: LDMusicSubtrack in _music().subtracks:
		if layer.trigger == LDMusicSubtrack.Trigger.ALWAYS:
			return layer
	return null


func _base_track_id() -> String:
	var base: LDMusicSubtrack = _base_layer()
	return base.track_id if base else NONE_ID


func _triggered_layers() -> Array[LDMusicSubtrack]:
	var result: Array[LDMusicSubtrack] = []
	for layer: LDMusicSubtrack in _music().subtracks:
		if layer.trigger != LDMusicSubtrack.Trigger.ALWAYS:
			result.append(layer)
	return result


func _refresh() -> void:
	_populate_presets()
	_select_active_preset()
	_apply_underwater_ui()
	_populate_track_option(base_option, true)
	_select_track(base_option, _base_track_id())
	for child: Node in layer_list.get_children():
		child.queue_free()
	for layer: LDMusicSubtrack in _triggered_layers():
		layer_list.add_child(_build_layer_row(layer))


func _mark_custom() -> void:
	var area: LDArea = LD.get_area()
	area.music_preset = LDMusicPresetDB.CUSTOM
	area.custom_music = area.music
	_persist()


func _populate_presets() -> void:
	preset_option.clear()
	preset_option.clip_text = true
	for preset_name: String in LDMusicPresetDB.get_preset_names():
		preset_option.add_item(preset_name)
		preset_option.set_item_metadata(preset_option.item_count - 1, preset_name)
	preset_option.add_item(LDMusicPresetDB.CUSTOM)
	preset_option.set_item_metadata(preset_option.item_count - 1, LDMusicPresetDB.CUSTOM)


func _select_active_preset() -> void:
	var active: String = LD.get_area().music_preset
	for i: int in preset_option.item_count:
		if str(preset_option.get_item_metadata(i)) == active:
			preset_option.select(i)
			return
	preset_option.select(preset_option.item_count - 1)


func _on_preset_selected(index: int) -> void:
	var preset_name: String = str(preset_option.get_item_metadata(index))
	var area: LDArea = LD.get_area()
	if preset_name == LDMusicPresetDB.CUSTOM:
		if area.custom_music == null:
			area.custom_music = area.music.working_copy() if area.music else LDMusic.new()
		area.music = area.custom_music
		area.music_preset = LDMusicPresetDB.CUSTOM
	else:
		var preset: LDMusic = LDMusicPresetDB.get_preset(preset_name)
		if preset == null:
			return
		area.music = preset.working_copy()
		area.music_preset = preset_name
	_persist()
	_refresh()


func _populate_underwater() -> void:
	underwater_option.clear()
	for mode: int in UNDERWATER_NAMES:
		underwater_option.add_item(str(UNDERWATER_NAMES.get(mode)))
		underwater_option.set_item_metadata(underwater_option.item_count - 1, mode)


func _apply_underwater_ui() -> void:
	for i: int in underwater_option.item_count:
		if int(underwater_option.get_item_metadata(i)) == _music().underwater_mode:
			underwater_option.select(i)
			return


func _on_underwater_selected(index: int) -> void:
	_music().underwater_mode = int(underwater_option.get_item_metadata(index))
	_mark_custom()
	_select_active_preset()


func _populate_track_option(option: OptionButton, include_none: bool) -> void:
	option.clear()
	option.clip_text = true
	if include_none:
		option.add_item("None")
		option.set_item_metadata(option.item_count - 1, NONE_ID)
	for id: String in LDMusicDB.get_track_ids_in(LDMusicDB.CATEGORY_LEVEL):
		option.add_item(LDMusicDB.get_display_name(id))
		option.set_item_metadata(option.item_count - 1, id)
	option.add_item("Upload custom track")
	option.set_item_metadata(option.item_count - 1, UPLOAD_ID)


func _select_track(option: OptionButton, track_id: String) -> void:
	for i: int in option.item_count:
		if str(option.get_item_metadata(i)) == track_id:
			option.select(i)
			return
	option.select(0)


func _select_trigger(option: OptionButton, trigger: int) -> void:
	for i: int in option.item_count:
		if int(option.get_item_metadata(i)) == trigger:
			option.select(i)
			return


func _on_base_selected(index: int) -> void:
	var track_id: String = str(base_option.get_item_metadata(index))
	if track_id == UPLOAD_ID:
		_open_upload(_set_base_track)
		_select_track(base_option, _base_track_id())
		return
	_set_base_track(track_id)


func _set_base_track(track_id: String) -> void:
	var base: LDMusicSubtrack = _base_layer()
	if track_id == NONE_ID:
		if base:
			_music().subtracks.erase(base)
	elif base == null:
		base = LDMusicSubtrack.new()
		base.trigger = LDMusicSubtrack.Trigger.ALWAYS
		base.track_id = track_id
		_music().subtracks.insert(0, base)
	else:
		base.track_id = track_id
	_mark_custom()
	_refresh()


func _on_base_preview() -> void:
	_preview(_base_track_id())


func _on_add_triggered() -> void:
	var layer: LDMusicSubtrack = LDMusicSubtrack.new()
	layer.trigger = LDMusicSubtrack.Trigger.UNDERWATER
	_music().subtracks.append(layer)
	_mark_custom()
	_refresh()


func _on_upload_pressed() -> void:
	_open_upload(_set_base_track)


func _on_play_pressed() -> void:
	if preview_player.stream == null:
		return
	if preview_player.playing:
		preview_player.stream_paused = not preview_player.stream_paused
		_set_ambient_ducked(not preview_player.stream_paused)
	else:
		preview_player.play()
		preview_player.stream_paused = false
		_set_ambient_ducked(true)
	_update_play_button()


func _on_seek(fraction: float) -> void:
	if preview_player.stream == null:
		return
	var length: float = preview_player.stream.get_length()
	if length <= 0.0:
		return
	if not preview_player.playing:
		preview_player.play()
		preview_player.stream_paused = false
		_set_ambient_ducked(true)
	preview_player.seek(fraction * length)
	waveform.set_progress(fraction)
	_update_time(fraction * length, length)
	_update_play_button()


func _preview(track_id: String) -> void:
	if track_id == NONE_ID:
		preview_player.stop()
		_stop_scan()
		_set_ambient_ducked(false)
		_now_playing = NONE_ID
		waveform.clear_bins()
		loop_spin.visible = false
		loop_spin.set_value_no_signal(0.0)
		_update_now_playing()
		_update_play_button()
		return
	var stream: AudioStream = LDMusicDB.get_stream(track_id)
	if stream == null:
		return
	preview_player.stream = _prepare_stream(stream, LDMusicDB.get_loop_start(track_id))
	preview_player.stream_paused = false
	preview_player.play()
	_set_ambient_ducked(true)
	_now_playing = track_id
	var is_custom: bool = LDMusicDB.is_custom(track_id)
	loop_spin.visible = is_custom
	loop_spin.set_value_no_signal(LDMusicDB.get_loop_start(track_id) if is_custom else 0.0)
	if _wave_cache.has(track_id):
		waveform.load_bins(_wave_cache.get(track_id))
		_stop_scan()
	else:
		waveform.clear_bins()
		_begin_scan(track_id, preview_player.stream.get_length())
	_update_now_playing()
	_update_play_button()


func _begin_scan(track_id: String, length: float) -> void:
	if length <= 0.0:
		return
	_scan_track = track_id
	_scan_length = length
	_scanner.stream = _unlooped(LDMusicDB.get_stream(track_id))
	_scanner.play()
	_scanning = true


func _stop_scan() -> void:
	_scanning = false
	if _scanner and _scanner.playing:
		_scanner.stop()


func _prepare_stream(stream: AudioStream, loop_start: float) -> AudioStream:
	var copy: AudioStream = stream.duplicate()
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


func _unlooped(stream: AudioStream) -> AudioStream:
	var copy: AudioStream = stream.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = false
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = false
	elif copy is AudioStreamWAV:
		(copy as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	return copy


func _update_now_playing() -> void:
	if _now_playing == NONE_ID:
		now_playing_label.text = "Nothing playing"
	else:
		now_playing_label.text = LDMusicDB.get_display_name(_now_playing)


func _update_play_button() -> void:
	var active: bool = preview_player.playing and not preview_player.stream_paused
	play_button.text = "⏸" if active else "▶"


func _update_time(position: float, length: float) -> void:
	time_label.text = _format_time(position) + " / " + _format_time(length)


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var minutes: int = total / 60
	var remainder: int = total % 60
	return "%d:%02d" % [minutes, remainder]


func _open_upload(on_uploaded: Callable) -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.add_filter("*.ogg,*.mp3", "Audio")
	dialog.file_selected.connect(func(path: String) -> void:
		var id: String = _import_custom(path)
		if not id.is_empty():
			on_uploaded.call(id)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 480))


func _import_custom(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var id: String = LDMusicDB.add_custom(bytes, path.get_file(), path.get_extension().to_lower())
	if not id.is_empty():
		_persist()
	return id


func _build_layer_row(layer: LDMusicSubtrack) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var trigger_option: OptionButton = OptionButton.new()
	trigger_option.clip_text = true
	for trigger: int in TRIGGER_NAMES:
		trigger_option.add_item(str(TRIGGER_NAMES.get(trigger)))
		trigger_option.set_item_metadata(trigger_option.item_count - 1, trigger)
	_select_trigger(trigger_option, layer.trigger)
	trigger_option.item_selected.connect(func(index: int) -> void:
		layer.trigger = int(trigger_option.get_item_metadata(index))
		_mark_custom()
		_refresh()
	)
	row.add_child(trigger_option)
	if layer.trigger == LDMusicSubtrack.Trigger.REGION:
		var region_edit: LineEdit = LineEdit.new()
		region_edit.custom_minimum_size = Vector2(64, 0)
		region_edit.placeholder_text = "Region"
		region_edit.text = layer.region_id
		region_edit.tooltip_text = "Region id"
		region_edit.text_changed.connect(func(value: String) -> void:
			layer.region_id = value
			_mark_custom()
		)
		row.add_child(region_edit)
	var track_option: OptionButton = OptionButton.new()
	track_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_track_option(track_option, false)
	_select_track(track_option, layer.track_id)
	track_option.item_selected.connect(func(index: int) -> void:
		var picked: String = str(track_option.get_item_metadata(index))
		if picked == UPLOAD_ID:
			_open_upload(func(id: String) -> void:
				layer.track_id = id
				_mark_custom()
				_refresh()
			)
			_select_track(track_option, layer.track_id)
			return
		layer.track_id = picked
		_mark_custom()
	)
	row.add_child(track_option)
	var volume: HSlider = HSlider.new()
	volume.custom_minimum_size = Vector2(52, 0)
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.min_value = -40.0
	volume.max_value = 6.0
	volume.step = 1.0
	volume.value = layer.volume_db
	volume.tooltip_text = "Layer volume"
	volume.value_changed.connect(func(value: float) -> void:
		layer.volume_db = value
		_mark_custom()
	)
	row.add_child(volume)
	var preview: Button = Button.new()
	preview.text = "▶"
	preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview.pressed.connect(func() -> void: _preview(layer.track_id))
	row.add_child(preview)
	var remove: Button = Button.new()
	remove.text = "✕"
	remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	remove.set_meta(&"gdss_classes", PackedStringArray(["Danger"]))
	remove.pressed.connect(func() -> void:
		_music().subtracks.erase(layer)
		_mark_custom()
		_refresh()
	)
	row.add_child(remove)
	return row
