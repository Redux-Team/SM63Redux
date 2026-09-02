class_name LDEditorConfig

## Level designer preferences. A typed front for the [code]editor/[/code] entries in [Settings],
## kept so editor code reads as LDEditorConfig.get_pan_speed() rather than reaching for raw
## setting keys. The values themselves live in the shared settings file; the level designer's
## old standalone config is imported once, on first access.


const LEGACY_PATH: String = "user://ld_editor.cfg"

const PAN_SPEED: StringName = &"editor/pan_speed"
const MUSIC_LOOP: StringName = &"editor/music_loop"
const PLAYLIST: StringName = &"editor/playlist"
const INITIALIZED: StringName = &"editor/initialized"


## Runs once ever: imports the old config file if there is one, and otherwise starts the
## playlist off with every level designer track. Distinguishing this from a plain default
## matters because an empty playlist is also a valid choice - it means "no music".
static func _ensure_initialized() -> void:
	if Settings.get_bool(INITIALIZED):
		return
	Settings.set_value(INITIALIZED, true)
	
	var legacy: ConfigFile = ConfigFile.new()
	if legacy.load(LEGACY_PATH) == OK:
		Settings.set_value(PAN_SPEED, legacy.get_value("viewport", "pan_speed", Settings.get_float(PAN_SPEED)))
		Settings.set_value(MUSIC_LOOP, legacy.get_value("music", "ld_loop", false))
		if legacy.has_section_key("music", "ld_playlist"):
			Settings.set_value(PLAYLIST, legacy.get_value("music", "ld_playlist"))
			return
	
	Settings.set_value(PLAYLIST, PackedStringArray(LDMusicDB.get_track_ids_in(LDMusicDB.CATEGORY_LD)))


## Camera pan speed used by WASD navigation in the editor viewport.
static func get_pan_speed() -> float:
	_ensure_initialized()
	return Settings.get_float(PAN_SPEED)


static func set_pan_speed(value: float) -> void:
	Settings.set_value(PAN_SPEED, value)


static func get_ld_playlist() -> Array[String]:
	_ensure_initialized()
	var playlist: Array[String] = []
	playlist.assign(Settings.get_value(PLAYLIST) as PackedStringArray)
	return playlist


static func is_ld_track_enabled(id: String) -> bool:
	return get_ld_playlist().has(id)


static func set_ld_track_enabled(id: String, enabled: bool) -> void:
	var playlist: Array[String] = get_ld_playlist()
	if enabled and not playlist.has(id):
		playlist.append(id)
	elif not enabled:
		playlist.erase(id)
	Settings.set_value(PLAYLIST, PackedStringArray(playlist))


static func get_ld_loop() -> bool:
	_ensure_initialized()
	return Settings.get_bool(MUSIC_LOOP)


static func set_ld_loop(value: bool) -> void:
	Settings.set_value(MUSIC_LOOP, value)
