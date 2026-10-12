@tool
class_name SettingsCategory
extends Node


func settings() -> Array[SettingsType]:
	var category_settings: Array[SettingsType] = []
	for child: Node in get_children():
		if child is SettingsType:
			category_settings.append(child)
	return category_settings


func visible_settings() -> Array[SettingsType]:
	var ignored: Array[SettingsType] = _get_ignored_settings()
	var shown: Array[SettingsType] = []
	for setting: SettingsType in settings():
		if not ignored.has(setting):
			shown.append(setting)
	return shown


func _get_ignored_settings() -> Array[SettingsType]:
	return []


func _apply_setting(setting: SettingsType) -> void:
	push_error("Settings: no apply branch for '%s' in category '%s'." % [setting.setting_key, name])
