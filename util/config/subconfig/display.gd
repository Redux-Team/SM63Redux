class_name DisplayConfig
extends Subconfig

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
	FULLSCREEN_BORDERLESS,
}


@export_range(0, 240) var max_fps: int = 60
@export var window_mode: WindowMode = WindowMode.WINDOWED
@export var vsync: bool = false
@export var ui_scale: float = 1.0
@export var particle_amount: String = "Medium"


func apply() -> void:
	Engine.max_fps = max_fps
	
	match window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, false)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, true)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, true)
		WindowMode.FULLSCREEN_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, false)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED, true)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	if Singleton and Singleton.get_window():
		Singleton.get_window().content_scale_factor = ui_scale
