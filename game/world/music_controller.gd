class_name MusicController
extends Node


const BUS: StringName = &"Music"
const SILENCE_DB: float = -80.0
const MUFFLE_CUTOFF: float = 600.0
## Fraction of the fade an outgoing track waits before it starts fading out, so the incoming track is
## already rising and the sum never dips (a seamless crossfade instead of a mid-transition gap).
const CROSSFADE_OVERLAP: float = 0.5


var _entries: Array[Dictionary] = []
var _underwater: bool = false
var _current_region: String = ""
var _mode: LDMusic.UnderwaterMode = LDMusic.UnderwaterMode.MUFFLE
var _muffle: AudioEffectLowPassFilter


func play(music: LDMusic) -> void:
	stop()
	if music == null or music.is_empty():
		return
	_mode = music.underwater_mode
	for subtrack: LDMusicSubtrack in music.subtracks:
		var stream: AudioStream = LDMusicDB.get_stream(subtrack.track_id)
		if stream == null:
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = _looped(stream, LDMusicDB.get_loop_start(subtrack.track_id))
		player.bus = BUS
		player.volume_db = subtrack.volume_db if _is_active(subtrack) else SILENCE_DB
		add_child(player)
		player.play()
		_entries.append({"player": player, "subtrack": subtrack, "tween": null})


func stop() -> void:
	_apply_muffle(false)
	for entry: Dictionary in _entries:
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_entries.clear()
	_underwater = false
	_current_region = ""


func has_music() -> bool:
	return not _entries.is_empty()


func set_underwater(underwater: bool) -> void:
	if _underwater == underwater:
		return
	_underwater = underwater
	if _mode == LDMusic.UnderwaterMode.MUFFLE:
		_apply_muffle(underwater)
	elif _mode == LDMusic.UnderwaterMode.TRACK:
		_refresh_volumes()


func set_region(region_id: String) -> void:
	if _current_region == region_id:
		return
	_current_region = region_id
	_refresh_volumes()


func _refresh_volumes() -> void:
	for entry: Dictionary in _entries:
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		var subtrack: LDMusicSubtrack = entry.get("subtrack") as LDMusicSubtrack
		if not is_instance_valid(player):
			continue
		var active: bool = _is_active(subtrack)
		var target: float = subtrack.volume_db if active else SILENCE_DB
		if is_equal_approx(player.volume_db, target):
			continue
		var fade: float = maxf(0.01, subtrack.fade_time)
		var old_tween: Variant = entry.get("tween")
		if old_tween is Tween and (old_tween as Tween).is_valid():
			(old_tween as Tween).kill()
		var tween: Tween = create_tween()
		if not active:
			tween.tween_interval(fade * CROSSFADE_OVERLAP)
		tween.tween_property(player, "volume_db", target, fade)
		entry.set("tween", tween)


func _is_active(subtrack: LDMusicSubtrack) -> bool:
	match subtrack.trigger:
		LDMusicSubtrack.Trigger.ALWAYS:
			return not _override_active()
		LDMusicSubtrack.Trigger.UNDERWATER:
			return _underwater
		LDMusicSubtrack.Trigger.REGION:
			return _current_region != "" and _current_region == subtrack.region_id
	return false


## Whether a variant (a matching region subtrack, or the underwater track in TRACK mode) currently
## overrides the base. The base (ALWAYS) is silenced while an override plays so they crossfade.
func _override_active() -> bool:
	if _mode == LDMusic.UnderwaterMode.TRACK and _underwater:
		return true
	if _current_region == "":
		return false
	for entry: Dictionary in _entries:
		var subtrack: LDMusicSubtrack = entry.get("subtrack") as LDMusicSubtrack
		if subtrack.trigger == LDMusicSubtrack.Trigger.REGION and subtrack.region_id == _current_region:
			return true
	return false


func _apply_muffle(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx == -1:
		return
	if on:
		if _muffle == null:
			_muffle = AudioEffectLowPassFilter.new()
			_muffle.cutoff_hz = MUFFLE_CUTOFF
			AudioServer.add_bus_effect(idx, _muffle)
	elif _muffle:
		var effect_idx: int = _find_effect(idx, _muffle)
		if effect_idx != -1:
			AudioServer.remove_bus_effect(idx, effect_idx)
		_muffle = null


func _find_effect(bus_idx: int, effect: AudioEffect) -> int:
	for i: int in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) == effect:
			return i
	return -1


func _looped(stream: AudioStream, loop_start: float) -> AudioStream:
	var copy: AudioStream = stream.duplicate() as AudioStream
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
