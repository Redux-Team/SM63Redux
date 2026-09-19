@tool
extends SettingsTypeList


func apply() -> void:
	Engine.max_fps = [30, 60, 120, 240, 0][current_value]
