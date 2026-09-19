@tool
extends SettingsTypeBoolean


func apply() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if current_value \
		else DisplayServer.VSYNC_DISABLED
	) 
