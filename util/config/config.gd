class_name Config
extends Resource
## Global singleton-like config loader and saver.

static var folder_path: String = OS.get_user_data_dir()
static var config_file_path: String = folder_path.path_join("config.tres")
static var _current_conf: Config

@export var display_config: DisplayConfig
@export var input_config: InputConfig
@export var audio_config: AudioConfig
@export var misc_config: MiscConfig

@export_storage var configurations: Array[Subconfig]


static func _static_init() -> void:
	_current_conf = ResourceLoader.load("uid://do0n8w5nirmwk")
	
	if not _current_conf.configurations:
		_current_conf.assign_configurations()
	
	Config.load()
	Config.apply()


## Save current config resource to disk
static func save() -> void:
	ResourceSaver.save(_current_conf, config_file_path)


## Load config from disk if exists, then reapply input mappings
static func load() -> void:
	if ResourceLoader.exists(config_file_path):
		_current_conf = ResourceLoader.load(config_file_path)
	
	get_control_scheme().assign_to_map()


## Apply all sub-configs (display, input, audio, misc)
static func apply() -> void:
	for conf: Subconfig in _current_conf.configurations:
		conf.apply()


## Display section: get/set display-related settings
#region Display
class display:
	static var max_fps: int:
		get(): return Config._current_conf.display_config.max_fps
		set(mfps): Config._current_conf.display_config.max_fps = mfps
	static var window_mode: int:
		get(): return Config._current_conf.display_config.window_mode
		set(wm): Config._current_conf.display_config.window_mode = wm as DisplayConfig.WindowMode
	static var vsync: bool:
		get(): return Config._current_conf.display_config.vsync
		set(vs): Config._current_conf.display_config.vsync = vs
	static var ui_scale: float:
		get(): return Config._current_conf.display_config.ui_scale
		set(uis): Config._current_conf.display_config.ui_scale = uis
#endregion


## Input section: access and reset control scheme
#region Input
static func get_control_scheme() -> ControlScheme:
	var _input_config: InputConfig = Config._current_conf.input_config
	return _input_config.get_active_control_scheme()


static func reset_control_scheme() -> void:
	var _input_config: InputConfig = Config._current_conf.input_config
	_input_config.control_schemes[_input_config.selected_control_scheme] = ControlScheme.copy_from(_input_config.default_control_scheme)
	Singleton.control_scheme_changed.emit()



class input:
	static var touch_button_scale: float:
		get(): return Config._current_conf.input_config.button_scale
		set(tbs): Config._current_conf.input_config.button_scale = tbs
	static var touch_button_opacity: float:
		get(): return Config._current_conf.input_config.button_opacity
		set(tbo): Config._current_conf.input_config.button_opacity = tbo
	static var touch_button_positions: Dictionary[StringName, Dictionary]:
		get(): return Config._current_conf.input_config.button_positions
		set(tbp): Config._current_conf.input_config.button_positions = tbp
	static var button_map: Dictionary[StringName, TouchButtonSetting]:
		get(): return Config._current_conf.input_config.button_map
		set(bm): Config._current_conf.input_config.button_map = bm
	static var controller_icon_map: Dictionary[InputEvent, Texture2D]:
		get(): return Config._current_conf.input_config.controller_icon_map
		set(cim): Config._current_conf.input_config.controller_icon_map = cim
	
	static func get_controller_icon(event: InputEvent) -> Texture2D:
		for input_event: InputEvent in controller_icon_map:
			if input_event.is_match(event, true):
				return controller_icon_map.get(input_event)
		return null
#endregion


## Audio section: get/set audio settings
#region Audio
class audio:
	static var output_device: String:
		get(): return Config._current_conf.audio_config.output_device
		set(od): Config._current_conf.audio_config.output_device = od
	static var music_on: bool:
		get(): return Config._current_conf.audio_config.music_on
		set(mo): Config._current_conf.audio_config.music_on = mo
	static var music_volume: float:
		get(): return Config._current_conf.audio_config.music_volume
		set(mv): Config._current_conf.audio_config.music_volume = mv
	static var sfx_on: bool:
		get(): return Config._current_conf.audio_config.sfx_on
		set(so): Config._current_conf.audio_config.sfx_on = so
	static var sfx_volume: float:
		get(): return Config._current_conf.audio_config.sfx_volume
		set(sv): Config._current_conf.audio_config.sfx_volume = sv
#endregion


## Misc section: get/set miscellaneous game settings
#region Miscellaneous
class misc:
	static var show_timer: bool:
		get(): return Config._current_conf.misc_config.show_timer
		set(st): Config._current_conf.misc_config.show_timer = st
	static var enforce_touch_display: bool:
		get(): return Config._current_conf.misc_config.enforce_touch_display
		set(efd): Config._current_conf.misc_config.enforce_touch_display = efd
	static var disable_camera_limiting: bool:
		get(): return Config._current_conf.misc_config.disable_camera_limiting
		set(dcl): Config._current_conf.misc_config.disable_camera_limiting = dcl
	static var language: StringName:
		get(): return Config._current_conf.misc_config.language
		set(l): Config._current_conf.misc_config.language = l
#endregion


func assign_configurations() -> void:
	configurations = [display_config, input_config, audio_config, misc_config]
