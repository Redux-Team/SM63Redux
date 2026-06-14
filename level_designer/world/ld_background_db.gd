class_name LDBackgroundDB

## Registry of background presets. Presets are plain LDBackground resources dropped into
## PRESETS_DIR; add or tweak one there and it shows up automatically. Both the level designer and
## the runtime resolve a saved background through here.

const PRESETS_DIR: String = "res://game/db/Backgrounds"
const CUSTOM: String = "Custom"


static var _presets: Array[LDBackground] = []
static var _loaded: bool = false


static func get_presets() -> Array[LDBackground]:
	_ensure_loaded()
	return _presets


static func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for preset: LDBackground in get_presets():
		names.append(preset.preset_name)
	return names


static func get_preset(preset_name: String) -> LDBackground:
	for preset: LDBackground in get_presets():
		if preset.preset_name == preset_name:
			return preset
	return null


static func has_preset(preset_name: String) -> bool:
	return get_preset(preset_name) != null


## Turns a saved background dict ({ "preset": name, "data": {...} }) into a fresh LDBackground:
## a copy of the named preset, or the custom data when it isn't a known preset.
static func resolve(data: Dictionary) -> LDBackground:
	var preset_name: String = str(data.get("preset", ""))
	if preset_name != CUSTOM and has_preset(preset_name):
		return get_preset(preset_name).duplicate(true) as LDBackground
	return LDBackground.deserialize(data.get("data", {}))


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
			if res is LDBackground:
				_presets.append(res as LDBackground)
		file_name = dir.get_next()
