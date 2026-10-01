@tool
class_name SettingsCategory
extends Node


func _apply_setting(setting: SettingsType) -> void:
	push_error("Settings: no apply branch for '%s' in category '%s'." % [setting.setting_key, name])
