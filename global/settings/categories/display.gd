@tool
class_name SettingsCategoryDisplay
extends SettingsCategory

const FPS_VALUES: Array[int] = [30, 60, 120, 240, 0]

@export var window_mode: SettingsTypeList
@export var fps_cap: SettingsTypeList
@export var v_sync: SettingsTypeBoolean


func _apply_setting(setting: SettingsType) -> void:
	match setting:
		window_mode:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			match window_mode.current_value:
				0:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				1:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				2:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		fps_cap:
			Engine.max_fps = FPS_VALUES.get(fps_cap.current_value)
		v_sync:
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if v_sync.current_value \
				else DisplayServer.VSYNC_DISABLED
			)
		_:
			super(setting)
