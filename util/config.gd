class_name Config
extends Resource

static var folder_path: String = OS.get_user_data_dir()
static var settings_file_path: String = folder_path.path_join("settings.json")


static var _conf_dict_default: Dictionary = {
	"Display": {
		&"max_fps": 60,
		&"window_mode": "Windowed",
		&"vsync": true,
	},
	"Audio": {
		&"music_on": true,
		&"music_volume": 75.0,
		&"sfx_on": true,
		&"sfx_volume": 75.0,
		&"output_device": "Default",
	},
	"Input": {},
	"Misc": {
		&"show_timer": false,
		&"enforce_touch_controls": false,
		&"disable_camera_limiting": false,
		&"language": "en"
	},
}

# This is what actually *holds* the config data, the classes below are just
# an abstract way to access/read/modify them.
static var _conf_dict: Dictionary = _conf_dict_default.duplicate(true)


static func _static_init() -> void:
	Config.load()
	Config.apply()


static func print() -> void:
	print(JSON.stringify(_conf_dict, "\t"))


static func save() -> void:
	var config_file: FileAccess = FileAccess.open(settings_file_path, FileAccess.WRITE)
	config_file.store_string(JSON.stringify(_conf_dict))


static func load() -> void:
	if not FileAccess.file_exists(settings_file_path):
		return
	
	var config_file: FileAccess = FileAccess.open(settings_file_path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(config_file.get_as_text())
	
	_conf_dict = Packer.merge_deep(_conf_dict_default, data)


static func apply() -> void:
	display.apply()
	audio.apply()
	misc.apply()


class display:
	static var max_fps: int:
		get(): return Config._conf_dict.Display.get(&"max_fps")
		set(mfps): Config._conf_dict.Display.set(&"max_fps", mfps)
	static var window_mode: String:
		get(): return Config._conf_dict.Display.get(&"window_mode")
		set(wm): Config._conf_dict.Display.set(&"window_mode", wm)
	static var vsync: bool:
		get(): return Config._conf_dict.Display.get(&"vsync")
		set(vs): Config._conf_dict.Display.set(&"vsync", vs)
	
	static func apply() -> void:
		# max_fps
		Engine.max_fps = max_fps
		
		# window_mode
		match window_mode:
			"Windowed":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, false)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, true)
			"Fullscreen":
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, true)
			"Fullscreen Borderless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, false)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, true)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		
		# vsync
		if vsync:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


class audio:
	static var music_on: bool:
		get(): return Config._conf_dict.Audio.get(&"music_on")
		set(m): Config._conf_dict.Audio.set(&"music_on", m)
	static var music_volume: float:
		get(): return Config._conf_dict.Audio.get(&"music_volume")
		set(m_v): Config._conf_dict.Audio.set(&"music_volume", m_v)
	static var sfx_on: bool:
		get(): return Config._conf_dict.Audio.get(&"sfx_on")
		set(sfx): Config._conf_dict.Audio.set(&"sfx_on", sfx)
	static var sfx_volume: float:
		get(): return Config._conf_dict.Audio.get(&"sfx_volume")
		set(sfx_v): Config._conf_dict.Audio.set(&"sfx_volume", sfx_v)
	static var output_device: String:
		get(): return Config._conf_dict.Audio.get(&"output_device")
		set(od): Config._conf_dict.Audio.set(&"output_device", od)
	
	static func apply() -> void:
		# music
		AudioServer.set_bus_mute(1, not music_on)
		AudioServer.set_bus_mute(2, not sfx_on)
		
		# sfx
		AudioServer.set_bus_volume_db(1, remap(music_volume, 0, 100, -60, 20))
		AudioServer.set_bus_volume_db(2, remap(sfx_volume, 0, 100, -60, 20))
		
		AudioServer.output_device = output_device


class input:
	pass


class misc:
	static var show_timer: bool:
		get(): return Config._conf_dict.Misc.get(&"show_timer")
		set(st): Config._conf_dict.Misc.set(&"show_timer", st)
	static var enforce_touch_controls: bool:
		get(): return Config._conf_dict.Misc.get(&"enforce_touch_controls")
		set(etc): Config._conf_dict.Misc.set(&"enforce_touch_controls", etc)
	static var disable_camera_limiting: bool:
		get(): return Config._conf_dict.Misc.get(&"disable_camera_limiting")
		set(dcl): Config._conf_dict.Misc.set(&"disable_camera_limiting", dcl)
	static var language: String:
		get(): return Config._conf_dict.Audio.get(&"language")
		set(l): Config._conf_dict.Audio.set(&"language", l)
	
	
	# TODO: Misc settings
	static func apply() -> void:
		pass
