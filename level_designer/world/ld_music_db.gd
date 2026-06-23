class_name LDMusicDB


const CUSTOM_PREFIX: String = "custom:"
const CATEGORY_LD: String = "ld"
const CATEGORY_LEVEL: String = "level"
const LOOP_POINTS_PATH: String = "res://game/db/music_loop_points.tres"
const TRACKS: Dictionary = {
	"tutorial": {"name": "Tutorial", "category": "level", "path": "res://assets/music/level_tutorial_1.mp3"},
	"peachs_castle_ground_floor": {"name": "Peach's Castle (Ground Floor)", "category": "level", "path": "res://assets/music/level_peachs_castle_ground_floor.mp3"},
	"bob_omb_battlefield": {"name": "Bob-omb Battlefield", "category": "level", "path": "res://assets/music/level_bob_omb_battlefield.mp3"},
	"bob_omb_battlefield_mountain": {"name": "Bob-omb Battlefield (Mountain)", "category": "level", "path": "res://assets/music/level_bob_omb_battlefield_mountain.mp3"},
	"boos_mansion_interior": {"name": "Boo's Mansion (Interior)", "category": "level", "path": "res://assets/music/level_boos_mansion_interior.mp3"},
	"boos_mansion_exterior": {"name": "Boo's Mansion (Exterior)", "category": "level", "path": "res://assets/music/level_boos_mansion_exterior.mp3"},
	"jolly_roger_bay": {"name": "Jolly Roger Bay", "category": "level", "path": "res://assets/music/level_jolly_roger_bay.mp3"},
	"jolly_roger_bay_underwater": {"name": "Jolly Roger Bay (Underwater)", "category": "level", "path": "res://assets/music/level_jolly_roger_bay_underwater.mp3"},
	"frosty_fludd": {"name": "Frosty F.L.U.D.D", "category": "level", "path": "res://assets/music/level_frosty_fludd.mp3"},
	"bowser_koopa_king_of_the_stars": {"name": "Bowser, Koopa King of the Stars", "category": "level", "path": "res://assets/music/level_bowser_koopa_king_of_the_stars.mp3"},
	"editor_n64": {"name": "Level Editor - 64", "category": "ld", "path": "res://assets/music/ld_64.mp3"},
	"editor_sunshine": {"name": "Level Editor - Sunshine", "category": "ld", "path": "res://assets/music/ld_sunshine.mp3"},
	"editor_galaxy": {"name": "Level Editor - Galaxy", "category": "ld", "path": "res://assets/music/ld_galaxy.mp3"},
	"editor_galaxy_2": {"name": "Level Editor - Galaxy 2", "category": "ld", "path": "res://assets/music/ld_galaxy_2.mp3"},
}

static var _custom: Dictionary = {}
static var _loop_points: LDMusicLoopPoints


static func get_track_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(TRACKS.keys())
	result.append_array(_custom.keys())
	return result


static func get_track_ids_in(category: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in TRACKS:
		if get_category(id) == category:
			result.append(id)
	if category == CATEGORY_LEVEL:
		result.append_array(_custom.keys())
	return result


static func get_category(id: String) -> String:
	if TRACKS.has(id):
		return str((TRACKS.get(id) as Dictionary).get("category", CATEGORY_LEVEL))
	return CATEGORY_LEVEL


static func is_custom(id: String) -> bool:
	return id.begins_with(CUSTOM_PREFIX)


static func has_track(id: String) -> bool:
	return TRACKS.has(id) or _custom.has(id)


static func get_display_name(id: String) -> String:
	if TRACKS.has(id):
		return str((TRACKS.get(id) as Dictionary).get("name", id))
	if _custom.has(id):
		return str((_custom.get(id) as Dictionary).get("name", id))
	return id


static func get_stream(id: String) -> AudioStream:
	if TRACKS.has(id):
		var path: String = str((TRACKS.get(id) as Dictionary).get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			return null
		return load(path) as AudioStream
	if _custom.has(id):
		return (_custom.get(id) as Dictionary).get("stream") as AudioStream
	return null


static func get_loop_start(id: String) -> float:
	if _custom.has(id):
		return float((_custom.get(id) as Dictionary).get("loop_start", 0.0))
	if _loop_points == null and ResourceLoader.exists(LOOP_POINTS_PATH):
		_loop_points = load(LOOP_POINTS_PATH) as LDMusicLoopPoints
	if _loop_points:
		return _loop_points.loop_start_for(id)
	return 0.0


static func set_custom_loop_start(id: String, value: float) -> void:
	if _custom.has(id):
		(_custom.get(id) as Dictionary).set("loop_start", maxf(0.0, value))


static func add_custom(bytes: PackedByteArray, track_name: String, format: String) -> String:
	var id: String = CUSTOM_PREFIX + str(hash(bytes))
	if not _custom.has(id):
		var stream: AudioStream = _decode(format, bytes)
		if stream == null:
			return ""
		_custom.set(id, {"name": track_name, "format": format, "bytes": bytes, "stream": stream, "loop_start": 0.0})
	return id


static func clear_custom() -> void:
	_custom.clear()


static func serialize_custom() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _custom:
		var entry: Dictionary = _custom.get(id)
		var bytes: PackedByteArray = entry.get("bytes")
		result.set(id, {
			"name": str(entry.get("name", "")),
			"format": str(entry.get("format", "")),
			"loop_start": float(entry.get("loop_start", 0.0)),
			"data": Marshalls.raw_to_base64(bytes),
		})
	return result


static func deserialize_custom(data: Variant) -> void:
	clear_custom()
	if not data is Dictionary:
		return
	for id: String in (data as Dictionary):
		var entry: Dictionary = (data as Dictionary).get(id)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(entry.get("data", "")))
		var format: String = str(entry.get("format", ""))
		var stream: AudioStream = _decode(format, bytes)
		if stream:
			_custom.set(id, {"name": str(entry.get("name", id)), "format": format, "bytes": bytes, "stream": stream, "loop_start": float(entry.get("loop_start", 0.0))})


static func _decode(format: String, bytes: PackedByteArray) -> AudioStream:
	match format:
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"mp3":
			var stream: AudioStreamMP3 = AudioStreamMP3.new()
			stream.data = bytes
			return stream
	return null
