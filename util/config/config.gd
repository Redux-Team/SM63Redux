class_name Config
extends Resource

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
	
	_first_time_overrides()
	
	Config.load()
	Config.apply()


static func save() -> void:
	ResourceSaver.save(_current_conf, config_file_path)


static func load() -> void:
	if ResourceLoader.exists(config_file_path):
		var loaded_config: Config = ResourceLoader.load(config_file_path)
		
		if _is_config_valid(loaded_config):
			_current_conf = loaded_config
		else:
			_handle_broken_config()
	
	get_control_scheme().assign_to_map()


static func _first_time_overrides() -> void:
	if Device.is_mobile():
		display.particle_amount = "Low"


static func _is_config_valid(config: Config) -> bool:
	if not config:
		return false
	
	if not config.configurations:
		return false
	
	var default_config: Config = ResourceLoader.load("uid://do0n8w5nirmwk")
	if not default_config.configurations:
		default_config.assign_configurations()
	
	if config.configurations.size() != default_config.configurations.size():
		return false
	
	for i: int in range(config.configurations.size()):
		var loaded_subconfig: Subconfig = config.configurations[i]
		var default_subconfig: Subconfig = default_config.configurations[i]
		
		if not _subconfig_properties_match(loaded_subconfig, default_subconfig):
			return false
	
	return true


static func _subconfig_properties_match(loaded: Subconfig, default: Subconfig) -> bool:
	if not loaded or not default:
		return false
	
	if loaded.get_class() != default.get_class():
		return false
	
	var loaded_properties: Array = loaded.get_property_list()
	var default_properties: Array = default.get_property_list()
	
	var loaded_export_props: Array[String] = []
	var default_export_props: Array[String] = []
	
	for prop: Dictionary in loaded_properties:
		if prop.usage & PROPERTY_USAGE_STORAGE:
			loaded_export_props.append(prop.name)
	
	for prop: Dictionary in default_properties:
		if prop.usage & PROPERTY_USAGE_STORAGE:
			default_export_props.append(prop.name)
	
	if loaded_export_props.size() != default_export_props.size():
		return false
	
	for prop_name: String in default_export_props:
		if not prop_name in loaded_export_props:
			return false
	
	return true


static func _handle_broken_config() -> void:
	print("Stored config file properties do not match expected structure, resorting to default...")
	
	var broken_file_path: String = config_file_path + ".broken"
	var counter: int = 1
	
	while FileAccess.file_exists(broken_file_path):
		broken_file_path = config_file_path + ".broken." + str(counter)
		counter += 1
	
	var file_system: DirAccess = DirAccess.open(folder_path)
	if file_system:
		var error: Error = file_system.rename(config_file_path.get_file(), broken_file_path.get_file())
		if error == OK:
			print("Renamed broken config to: ", broken_file_path)
		else:
			print("Failed to rename broken config file: ", error)
	
	_current_conf = ResourceLoader.load("uid://do0n8w5nirmwk")
	if not _current_conf.configurations:
		_current_conf.assign_configurations()



static func apply() -> void:
	for conf: Subconfig in _current_conf.configurations:
		conf.apply()
	
	if Singleton:
		Singleton.config_changed.emit()


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
	static var particle_amount: String:
		get(): return Config._current_conf.display_config.particle_amount
		set(pa): Config._current_conf.display_config.particle_amount = pa
#endregion


#region Input
static func get_control_scheme() -> ControlScheme:
	var _input_config: InputConfig = Config._current_conf.input_config
	return _input_config.get_active_control_scheme()


static func reset_control_scheme() -> void:
	var _input_config: InputConfig = Config._current_conf.input_config
	_input_config.control_schemes[_input_config.selected_control_scheme] = ControlScheme.copy_from(load("uid://dbwchs6hs285b"))
	Singleton.control_scheme_changed.emit()


class input:
	static var touch_button_scale: float:
		get(): return Config._current_conf.input_config.button_scale
		set(tbs): Config._current_conf.input_config.button_scale = tbs
	static var touch_button_opacity: float:
		get(): return Config._current_conf.input_config.button_opacity
		set(tbo): Config._current_conf.input_config.button_opacity = tbo
	static var touch_button_positions: Dictionary[StringName, Vector2]:
		get(): return Config._current_conf.input_config.button_positions
		set(tbp): Config._current_conf.input_config.button_positions = tbp
	static var touch_button_snapping: bool:
		get(): return Config._current_conf.input_config.button_snapping
		set(tbs): Config._current_conf.input_config.button_snapping = tbs
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
