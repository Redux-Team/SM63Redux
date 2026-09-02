class_name SettingsCatalog

## Every setting the game has, declared once. [Settings] derives storage from this list and the
## settings screen derives its rows from it, so adding a setting means adding one entry here and
## nothing else.


const SECTION_LABELS: Dictionary[StringName, String] = {
	&"display": "Display",
	&"audio": "Audio",
	&"controls": "Controls",
	&"game": "Game",
	&"editor": "Level Designer",
}

const WINDOW_WINDOWED: String = "windowed"
const WINDOW_FULLSCREEN: String = "fullscreen"
const WINDOW_BORDERLESS: String = "borderless"

const UI_QUALITY_LOW: String = "low"
const UI_QUALITY_HIGH: String = "high"

const PARTICLES_LOW: String = "low"
const PARTICLES_MEDIUM: String = "medium"
const PARTICLES_HIGH: String = "high"

const DEFAULT_DEVICE: String = "Default"
## Volume below which a bus is silenced outright, rather than left at a very small gain.
const SILENCE_THRESHOLD: float = 0.5


## Authored mix levels, captured before any player volume is applied so the sliders scale the
## bus layout's balance instead of flattening it.
static var _base_volume_db: Dictionary[StringName, float] = {}


static func get_section_label(section: StringName) -> String:
	return SECTION_LABELS.get(section, String(section).capitalize())


static func build() -> Array[SettingDef]:
	var defs: Array[SettingDef] = []
	defs.append_array(_display())
	defs.append_array(_audio())
	defs.append_array(_controls())
	defs.append_array(_game())
	defs.append_array(_editor())
	return defs


static func _display() -> Array[SettingDef]:
	var window_modes: Dictionary[String, Variant] = {
		"Windowed": WINDOW_WINDOWED,
		"Fullscreen": WINDOW_FULLSCREEN,
		"Borderless": WINDOW_BORDERLESS,
	}
	var ui_quality_levels: Dictionary[String, Variant] = {
		"Low": UI_QUALITY_LOW,
		"High": UI_QUALITY_HIGH,
	}
	var particle_levels: Dictionary[String, Variant] = {
		"Low": PARTICLES_LOW,
		"Medium": PARTICLES_MEDIUM,
		"High": PARTICLES_HIGH,
	}
	
	return [
		SettingDef.boolean(&"display/vsync", "V-Sync", false).in_group("Window") \
			.hint("Caps the frame rate to your monitor to remove tearing.") \
			.on_apply(_apply_vsync),
		
		SettingDef.slider(&"display/max_fps", "FPS Limit", 0.0, 240.0, 0.0).stepped(10.0).fps().in_group("Window") \
			.hint("0 removes the cap.") \
			.on_apply(_apply_max_fps),
		
		SettingDef.slider(&"display/ui_scale", "UI Scaling", 0.5, 2.0, 1.0).stepped(0.05).multiplier().in_group("Window").deferred() \
			.on_apply(_apply_ui_scale),
		
		SettingDef.choice(&"display/window_mode", "Window Mode", window_modes, WINDOW_WINDOWED) \
			.in_group("Window").on_apply(apply_window_mode),
		
		SettingDef.choice(&"display/ui_quality", "UI Quality", ui_quality_levels, UI_QUALITY_HIGH).in_group("Graphics") \
			.hint("Low turns off GPU-rendered interface panels, which are the expensive part of the editor's look.") \
			.on_apply(_apply_ui_quality),
		
		SettingDef.choice(&"display/particles", "Particles", particle_levels, PARTICLES_HIGH if Device.is_desktop() else PARTICLES_LOW).in_group("Graphics") \
			.hint("Lower densities help on weaker hardware."),
	]


static func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


static func _apply_max_fps(value: float) -> void:
	Engine.max_fps = roundi(value)


static func _apply_ui_scale(value: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.content_scale_factor = value


static func _audio() -> Array[SettingDef]:
	return [
		SettingDef.slider(&"audio/master_volume", "Master", 0.0, 100.0, 100.0).percent().in_group("Volume") \
			.on_apply(_apply_bus_volume.bind(&"Master")),
		
		SettingDef.slider(&"audio/music_volume", "Music", 0.0, 100.0, 75.0).percent().in_group("Volume") \
			.on_apply(_apply_bus_volume.bind(&"Music")),
		
		SettingDef.slider(&"audio/sfx_volume", "SFX", 0.0, 100.0, 75.0).percent().in_group("Volume") \
			.on_apply(_apply_bus_volume.bind(&"SFX")),
		
		SettingDef.slider(&"audio/player_volume", "Player", 0.0, 100.0, 100.0).percent().in_group("Volume") \
			.hint("Mario's own sounds - footsteps, jumps and voice.") \
			.on_apply(_apply_bus_volume.bind(&"Player")),
		
		SettingDef.choice(&"audio/output_device", "Output", {}, DEFAULT_DEVICE).in_group("Devices") \
			.provide_choices(_output_devices) \
			.on_apply(_apply_output_device),
	]


## The stylesheet renders its frosted panels on the GPU; dropping that is the single biggest
## saving available on weak hardware, and it restyles live rather than needing a restart.
static func _apply_ui_quality(level: String) -> void:
	GDSS.set_gpu_panels(level == UI_QUALITY_HIGH)


static func _apply_output_device(device: String) -> void:
	if AudioServer.get_output_device_list().has(device):
		AudioServer.output_device = device


static func _controls() -> Array[SettingDef]:
	var defs: Array[SettingDef] = []
	
	for action: StringName in ControlScheme.ACTIONS:
		var def: SettingDef = SettingDef.keybind(ControlScheme.get_key(action), ControlScheme.get_label(action))
		def.default_value = ControlScheme.get_default_events(action)
		def.in_group("Bindings")
		def.on_apply(_apply_keybind.bind(action))
		defs.append(def)
	
	defs.append(
		SettingDef.slider(&"controls/deadzone", "Stick Deadzone", 5.0, 95.0, 20.0).stepped(5.0).percent().in_group("Controller") \
			.hint("How far a stick must move before it registers.") \
			.available_when(_using_controller) \
			.on_apply(_apply_deadzone)
	)
	return defs


static func _apply_keybind(_events: Variant, action: StringName) -> void:
	ControlScheme.refresh(action)


## Stored as a percentage because that is what reads well on the slider; the input map wants a
## 0-1 fraction.
## Controller-only settings stay out of the way of players who never pick one up.
static func _using_controller() -> bool:
	return Singleton.get_input_handler().is_using_controller()


static func _apply_deadzone(value: float) -> void:
	ControlScheme.apply_deadzone(value / 100.0)


static func _game() -> Array[SettingDef]:
	return [
		SettingDef.boolean(&"game/screen_shake", "Screen Shake", true).in_group("Other Features") \
			.hint("Shakes the camera on heavy landings and hits."),
	]


## The editor section is fronted by [LDEditorConfig], which owns the playlist's shape and the
## one-time import from the level designer's old standalone config file.
static func _editor() -> Array[SettingDef]:
	return [
		SettingDef.slider(&"editor/pan_speed", "Camera Pan Speed", 1.0, 16.0, 4.0).stepped(0.5).in_group("Viewport") \
			.hint("Speed of WASD navigation in the level designer viewport."),
		
		SettingDef.raw(&"editor/music_loop", false),
		
		SettingDef.raw(&"editor/playlist", PackedStringArray()),
		SettingDef.raw(&"editor/initialized", false),
	]


static func _output_devices() -> Dictionary[String, Variant]:
	var devices: Dictionary[String, Variant] = {}
	for device: String in AudioServer.get_output_device_list():
		devices.set(device, device)
	return devices


## Scales a bus by a 0-100 slider value, relative to its authored level. Uses a perceptual
## (decibel) curve rather than a linear one, so halfway on the slider sounds halfway.
static func _apply_bus_volume(value: float, bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	
	if not _base_volume_db.has(bus):
		_base_volume_db.set(bus, AudioServer.get_bus_volume_db(index))
	
	var silent: bool = value < SILENCE_THRESHOLD
	AudioServer.set_bus_mute(index, silent)
	if not silent:
		AudioServer.set_bus_volume_db(index, _base_volume_db.get(bus) + linear_to_db(value / 100.0))


## Window mode has to leave whatever mode it was in before entering the next one, or the
## borderless flag and the maximized state end up disagreeing about the window's size.
static func apply_window_mode(mode: String) -> void:
	match mode:
		WINDOW_FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WINDOW_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
