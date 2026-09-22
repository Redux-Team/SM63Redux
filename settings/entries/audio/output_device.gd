@tool
extends SettingsTypeList


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var ops: PackedStringArray = PackedStringArray()
	ops.append_array(AudioServer.get_output_device_list())
	options = ops


func apply() -> void:
	AudioServer.output_device = options.get(current_value)
