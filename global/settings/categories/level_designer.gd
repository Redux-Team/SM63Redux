@tool
class_name SettingsCategoryLevelDesigner
extends SettingsCategory

@export var tooltip_delay: SettingsTypeFloat


func is_tooltip_enabled() -> bool:
	return tooltip_delay.current_value < tooltip_delay.maximum
