class_name LDEditorConfig

## Global, level-independent editor preferences for the level designer, persisted to a user://
## config file so they carry across levels and sessions. Accessed statically, e.g.
## LDEditorConfig.get_pan_speed(). Lazily loaded on first access.


const CONFIG_PATH: String = "user://ld_editor.cfg"
const VIEWPORT_SECTION: String = "viewport"
const MUSIC_SECTION: String = "music"
const WINDOWS_SECTION: String = "windows"

const PAN_SPEED_DEFAULT: float = 4.0
const PAN_SPEED_MIN: float = 1.0
const PAN_SPEED_MAX: float = 16.0


static var _config: ConfigFile
static var _pan_speed: float = PAN_SPEED_DEFAULT
static var _ld_playlist: Array[String] = []
static var _ld_loop: bool = false
static var _window_rects: Dictionary[StringName, Rect2] = {}


static func _ensure_loaded() -> void:
	if _config:
		return
	_config = ConfigFile.new()
	if _config.load(CONFIG_PATH) == OK:
		_pan_speed = clampf(float(_config.get_value(VIEWPORT_SECTION, "pan_speed", PAN_SPEED_DEFAULT)), PAN_SPEED_MIN, PAN_SPEED_MAX)
	if _config.has_section_key(MUSIC_SECTION, "ld_playlist"):
		_ld_playlist.assign(_config.get_value(MUSIC_SECTION, "ld_playlist", PackedStringArray()))
	else:
		_ld_playlist.assign(LDMusicDB.get_track_ids_in(LDMusicDB.CATEGORY_LD))
	_ld_loop = bool(_config.get_value(MUSIC_SECTION, "ld_loop", false))
	for key: String in _config.get_section_keys(WINDOWS_SECTION) if _config.has_section(WINDOWS_SECTION) else PackedStringArray():
		_window_rects.set(StringName(key), _config.get_value(WINDOWS_SECTION, key, Rect2()))


## Camera pan speed used by WASD navigation in the editor viewport.
static func get_pan_speed() -> float:
	_ensure_loaded()
	return _pan_speed


static func set_pan_speed(value: float) -> void:
	_ensure_loaded()
	_pan_speed = clampf(value, PAN_SPEED_MIN, PAN_SPEED_MAX)
	_config.set_value(VIEWPORT_SECTION, "pan_speed", _pan_speed)
	_config.save(CONFIG_PATH)


static func get_ld_playlist() -> Array[String]:
	_ensure_loaded()
	return _ld_playlist.duplicate()


static func is_ld_track_enabled(id: String) -> bool:
	_ensure_loaded()
	return _ld_playlist.has(id)


static func set_ld_track_enabled(id: String, enabled: bool) -> void:
	_ensure_loaded()
	if enabled and not _ld_playlist.has(id):
		_ld_playlist.append(id)
	elif not enabled:
		_ld_playlist.erase(id)
	_config.set_value(MUSIC_SECTION, "ld_playlist", PackedStringArray(_ld_playlist))
	_config.save(CONFIG_PATH)


static func get_ld_loop() -> bool:
	_ensure_loaded()
	return _ld_loop


static func set_ld_loop(value: bool) -> void:
	_ensure_loaded()
	_ld_loop = value
	_config.set_value(MUSIC_SECTION, "ld_loop", value)
	_config.save(CONFIG_PATH)


## Where a level designer window was last left. A zero-size rect means it has never been placed,
## so the window should size itself to its content and centre instead.
static func get_window_rect(id: StringName) -> Rect2:
	_ensure_loaded()
	return _window_rects.get(id, Rect2())


static func set_window_rect(id: StringName, rect: Rect2) -> void:
	_ensure_loaded()
	if _window_rects.get(id, Rect2()) == rect:
		return
	_window_rects.set(id, rect)
	_config.set_value(WINDOWS_SECTION, String(id), rect)
	_config.save(CONFIG_PATH)
