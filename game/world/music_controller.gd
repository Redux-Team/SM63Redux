class_name MusicController
extends Node


const SILENCE_DB: float = -80.0
const MUFFLE_CUTOFF: float = 600.0


@export var bus: StringName = &"Music"
## Maps a subtrack's "presence" (0 = silent, 1 = full) to its gain (0..1). Left unset, an equal-power
## (sine) law is used so that crossfading synchronized variants (base <-> region/underwater) keeps a
## constant total volume: no mid dip, and no doubling from both arrangements playing at once.
@export var fade_curve: Curve
## Prints region/underwater changes and which subtracks become active, to diagnose transitions.
@export var debug: bool = false


var _entries: Array[Dictionary] = []
var _underwater: bool = false
var _current_region: String = ""
var _mode: LDMusic.UnderwaterMode = LDMusic.UnderwaterMode.MUFFLE


## Ensures the underwater muffle bus is torn down whenever this controller leaves the tree, even if
## stop() was never called (e.g. the level is freed on a playtest exit).
func _exit_tree() -> void:
	_remove_muffle_bus()


func play(music: LDMusic) -> void:
	stop()
	if music == null or music.is_empty():
		return
	_mode = music.underwater_mode
	_ensure_muffle_bus()
	for subtrack: LDMusicSubtrack in music.subtracks:
		var stream: AudioStream = LDMusicDB.get_stream(subtrack.track_id)
		if stream == null:
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = _looped(stream, LDMusicDB.get_loop_start(subtrack.track_id))
		player.bus = _muffle_bus_name() if _muffle_eligible(subtrack) else bus
		var mix: float = 1.0 if _is_active(subtrack) else 0.0
		player.volume_db = _mix_db(mix, subtrack.volume_db)
		add_child(player)
		player.play()
		_entries.append({"player": player, "subtrack": subtrack, "tween": null, "mix": mix})
	if debug:
		print("[music] play: ", _entries.size(), " subtracks, mode=", _mode)


func stop() -> void:
	for entry: Dictionary in _entries:
		_kill_tween(entry)
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_entries.clear()
	_remove_muffle_bus()
	_underwater = false
	_current_region = ""


func has_music() -> bool:
	return not _entries.is_empty()


func set_underwater(underwater: bool) -> void:
	if _underwater == underwater:
		return
	_underwater = underwater
	if debug:
		print("[music] underwater -> ", underwater, " (mode=", _mode, ")")
	_set_muffle_enabled(underwater)
	_refresh_volumes()


func set_region(region_id: String) -> void:
	if _current_region == region_id:
		return
	_current_region = region_id
	if debug:
		print("[music] region -> '", region_id, "'")
	_refresh_volumes()


func _refresh_volumes() -> void:
	for entry: Dictionary in _entries:
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		var subtrack: LDMusicSubtrack = entry.get("subtrack") as LDMusicSubtrack
		if not is_instance_valid(player):
			continue
		var target_mix: float = 1.0 if _is_active(subtrack) else 0.0
		var from_mix: float = float(entry.get("mix", 0.0))
		if is_equal_approx(from_mix, target_mix):
			continue
		if debug:
			print("[music]   ", subtrack.track_id, " ", from_mix, " -> ", target_mix)
		_kill_tween(entry)
		entry.set("tween", _fade_entry(entry, from_mix, target_mix, maxf(0.01, subtrack.fade_time)))


## Crossfades one subtrack between silent (mix 0) and full (mix 1) over `fade`, driving its volume
## through the equal-power gain law. Run simultaneously on the outgoing and incoming subtracks, the
## sine/cosine pairing keeps total power constant.
func _fade_entry(entry: Dictionary, from_mix: float, target_mix: float, fade: float) -> Tween:
	var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
	var full_db: float = (entry.get("subtrack") as LDMusicSubtrack).volume_db
	var tween: Tween = create_tween()
	tween.tween_method(func(progress: float) -> void:
		var mix: float = lerpf(from_mix, target_mix, progress)
		entry.set("mix", mix)
		if is_instance_valid(player):
			player.volume_db = _mix_db(mix, full_db)
	, 0.0, 1.0, fade)
	return tween


func _mix_db(mix: float, full_db: float) -> float:
	var gain: float = _gain(mix)
	if gain <= 0.0001:
		return SILENCE_DB
	return full_db + linear_to_db(gain)


func _gain(mix: float) -> float:
	var clamped: float = clampf(mix, 0.0, 1.0)
	if fade_curve:
		return clampf(fade_curve.sample(clamped), 0.0, 1.0)
	return sin(clamped * PI * 0.5)


func _kill_tween(entry: Dictionary) -> void:
	var old_tween: Variant = entry.get("tween")
	if old_tween is Tween and (old_tween as Tween).is_valid():
		(old_tween as Tween).kill()


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


func _muffle_bus_name() -> StringName:
	return StringName("%sMuffled" % bus)


func _muffle_eligible(subtrack: LDMusicSubtrack) -> bool:
	if subtrack.trigger == LDMusicSubtrack.Trigger.ALWAYS:
		return _mode == LDMusic.UnderwaterMode.MUFFLE
	return subtrack.muffled


func _ensure_muffle_bus() -> int:
	var muffle_name: StringName = _muffle_bus_name()
	var idx: int = AudioServer.get_bus_index(muffle_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, muffle_name)
		AudioServer.set_bus_send(idx, bus)
		var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = MUFFLE_CUTOFF
		AudioServer.add_bus_effect(idx, low_pass)
		idx = AudioServer.get_bus_index(muffle_name)
	AudioServer.set_bus_effect_enabled(idx, 0, _underwater)
	return idx


func _set_muffle_enabled(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index(_muffle_bus_name())
	if idx != -1:
		AudioServer.set_bus_effect_enabled(idx, 0, on)


func _remove_muffle_bus() -> void:
	var idx: int = AudioServer.get_bus_index(_muffle_bus_name())
	if idx != -1:
		AudioServer.remove_bus(idx)


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
