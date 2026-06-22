class_name LDEditorConfig

## Global, level-independent editor preferences for the level designer, persisted to a user://
## config file so they carry across levels and sessions. Accessed statically, e.g.
## LDEditorConfig.get_pan_speed(). Lazily loaded on first access.


const CONFIG_PATH: String = "user://ld_editor.cfg"
const VIEWPORT_SECTION: String = "viewport"

const PAN_SPEED_DEFAULT: float = 4.0
const PAN_SPEED_MIN: float = 1.0
const PAN_SPEED_MAX: float = 16.0


static var _config: ConfigFile
static var _pan_speed: float = PAN_SPEED_DEFAULT


static func _ensure_loaded() -> void:
	if _config:
		return
	_config = ConfigFile.new()
	if _config.load(CONFIG_PATH) == OK:
		_pan_speed = clampf(float(_config.get_value(VIEWPORT_SECTION, "pan_speed", PAN_SPEED_DEFAULT)), PAN_SPEED_MIN, PAN_SPEED_MAX)


## Camera pan speed used by WASD navigation in the editor viewport.
static func get_pan_speed() -> float:
	_ensure_loaded()
	return _pan_speed


static func set_pan_speed(value: float) -> void:
	_ensure_loaded()
	_pan_speed = clampf(value, PAN_SPEED_MIN, PAN_SPEED_MAX)
	_config.set_value(VIEWPORT_SECTION, "pan_speed", _pan_speed)
	_config.save(CONFIG_PATH)
