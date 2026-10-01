@tool
class_name SettingsCategoryUI
extends SettingsCategory

@export var scale: SettingsTypeFloat
@export var blur_strength: SettingsTypeFloat
@export var animations: SettingsTypeBoolean


func _apply_setting(setting: SettingsType) -> void:
	match setting:
		scale:
			# This is to make scaling consistent with hiDPI displays
			get_window().content_scale_factor = scale.current_value \
			* (2.0 if DisplayServer.has_feature(DisplayServer.FEATURE_HIDPI) else 1.0)
		blur_strength:
			print_debug("TODO!")
		animations:
			print_debug("TODO!")
		_:
			super(setting)
