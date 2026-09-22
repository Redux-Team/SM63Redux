@tool
extends SettingsTypeFloat


func apply() -> void:
	get_window().content_scale_factor = current_value \
	# This is to make scaling consistent with hiDPI displays 
	* 2.0 if DisplayServer.has_feature(DisplayServer.FEATURE_HIDPI) else 1.0
