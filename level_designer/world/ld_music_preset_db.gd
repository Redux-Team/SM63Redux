class_name LDMusicPresetDB

## Registry of music presets. Presets are plain LDMusic resources dropped into PRESETS_DIR; add or
## tweak one there and it shows up automatically. A preset bundles a base track plus subtracks
## (underwater / region) and an underwater mode, so per-campaign-song setup is not repeated. Both the
## level designer and the runtime resolve a saved music block through here.


const PRESETS_DIR: String = "res://game/db/Music"
const CUSTOM: String = "Custom"


static var _presets: Array[LDMusic] = []
static var _loaded: bool = false


static func get_presets() -> Array[LDMusic]:
	_ensure_loaded()
	return _presets


static func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for preset: LDMusic in get_presets():
		names.append(preset.preset_name)
	return names


static func get_preset(preset_name: String) -> LDMusic:
	for preset: LDMusic in get_presets():
		if preset.preset_name == preset_name:
			return preset
	return null


static func has_preset(preset_name: String) -> bool:
	return get_preset(preset_name) != null


## Turns a saved music block into a fresh LDMusic. Accepts the new { "preset": name, "data": {...} }
## wrapper, a legacy bare array of subtrack dicts, or a full LDMusic dict.
static func resolve(data: Variant) -> LDMusic:
	if data is Array:
		return LDMusic.deserialize(data)
	if data is Dictionary:
		var dict: Dictionary = data as Dictionary
		var preset_name: String = str(dict.get("preset", ""))
		if preset_name != CUSTOM and has_preset(preset_name):
			return get_preset(preset_name).working_copy()
		if dict.has("data"):
			return LDMusic.deserialize(dict.get("data"))
		return LDMusic.deserialize(dict)
	return LDMusic.new()


## Serializes one area's music: just the preset name, plus the full data when it's custom.
static func serialize_area(area: LDArea) -> Dictionary:
	var music_preset: String = area.music_preset
	var result: Dictionary = {"preset": music_preset}
	if music_preset == CUSTOM or not has_preset(music_preset):
		result.set("data", area.music.serialize() if area.music else {})
	return result


## Restores an area's music from a saved block (resolving preset vs custom data).
static func apply_to_area(area: LDArea, data: Variant) -> void:
	var preset_name: String = ""
	if data is Dictionary:
		preset_name = str((data as Dictionary).get("preset", ""))
	if preset_name != CUSTOM and has_preset(preset_name):
		area.music_preset = preset_name
	else:
		area.music_preset = CUSTOM
	area.music = resolve(data)
	if area.music_preset == CUSTOM:
		area.custom_music = area.music


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir: DirAccess = DirAccess.open(PRESETS_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(PRESETS_DIR.path_join(file_name))
			if res is LDMusic:
				_presets.append(res as LDMusic)
		file_name = dir.get_next()
	_presets.sort_custom(func(a: LDMusic, b: LDMusic) -> bool:
		return a.preset_name < b.preset_name
	)
