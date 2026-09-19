@tool
class_name SettingsTypeBoolean
extends SettingsType


@export var default_value: bool = true
var current_value: bool


func _serialize() -> String:
	return str(current_value)


func _deserialize(string: String) -> void:
	current_value = true if string == "true" else false


func _get_default_value() -> Variant:
	return default_value


func _restore_default() -> void:
	current_value = default_value
