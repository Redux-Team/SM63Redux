class_name MusicController
extends Node


const BUS: StringName = &"Music"
const SILENCE_DB: float = -80.0


var _entries: Array[Dictionary] = []
var _underwater: bool = false


func play(music: LDMusic) -> void:
	stop()
	if music == null or music.is_empty():
		return
	for layer: LDMusicLayer in music.layers:
		var stream: AudioStream = LDMusicDB.get_stream(layer.track_id)
		if stream == null:
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = _looped(stream, LDMusicDB.get_loop_start(layer.track_id))
		player.bus = BUS
		player.volume_db = layer.volume_db if _is_active(layer) else SILENCE_DB
		add_child(player)
		player.play()
		_entries.append({"player": player, "layer": layer, "tween": null})


func stop() -> void:
	for entry: Dictionary in _entries:
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_entries.clear()


func has_music() -> bool:
	return not _entries.is_empty()


func set_underwater(underwater: bool) -> void:
	if _underwater == underwater:
		return
	_underwater = underwater
	_refresh_volumes()


func _refresh_volumes() -> void:
	for entry: Dictionary in _entries:
		var player: AudioStreamPlayer = entry.get("player") as AudioStreamPlayer
		var layer: LDMusicLayer = entry.get("layer") as LDMusicLayer
		if not is_instance_valid(player):
			continue
		var target: float = layer.volume_db if _is_active(layer) else SILENCE_DB
		var old_tween: Variant = entry.get("tween")
		if old_tween is Tween and (old_tween as Tween).is_valid():
			(old_tween as Tween).kill()
		var tween: Tween = create_tween()
		tween.tween_property(player, "volume_db", target, maxf(0.01, layer.fade_time))
		entry.set("tween", tween)


func _is_active(layer: LDMusicLayer) -> bool:
	match layer.trigger:
		LDMusicLayer.Trigger.ALWAYS:
			return true
		LDMusicLayer.Trigger.UNDERWATER:
			return _underwater
	return false


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
