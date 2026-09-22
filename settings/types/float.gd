@tool
class_name SettingsTypeFloat
extends SettingsType


@export var default_value: float = 0.0
@export var minimum: float = 0.0
@export var maximum: float = 1.0
@export var step: float = 0.1
@export var slider_text: String = "%.2f"
var current_value: float


func _serialize() -> String:
	return str(current_value)


func _deserialize(string: String) -> void:
	current_value = string.to_float()


func _get_default_value() -> Variant:
	return default_value


func _restore_default() -> void:
	current_value = default_value


func _get_value() -> Variant:
	return current_value


func _set_value(val: Variant) -> void:
	current_value = val
