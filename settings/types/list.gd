@tool
class_name SettingsTypeList
extends SettingsType

enum Hint {
	DROPDOWN,
	SLIDER
}

@export var options: PackedStringArray
@export var default_value: int = 0
@export var hint: Hint = Hint.DROPDOWN
var current_value: int = 0:
	set(value):
		current_value = clampi(value, 0, maxi(options.size() - 1, 0))
		apply()


func option() -> String:
	return options.get(current_value) if current_value < options.size() else ""


func _serialize() -> String:
	return option()


func _deserialize(string: String) -> void:
	var index: int = options.find(string)
	current_value = index if index != -1 else default_value


func _get_default_value() -> Variant:
	return options.get(default_value)


func _restore_default() -> void:
	current_value = default_value


func _get_value() -> Variant:
	return option()


func _validate_property(property: Dictionary) -> void:
	if property.name == "default_value":
		property.set("hint", PROPERTY_HINT_ENUM)
		property.set("hint_string", ",".join(options))
