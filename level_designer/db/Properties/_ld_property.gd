@tool
@abstract class_name LDProperty
extends Resource


enum Type {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	COLOR,
}


@export var key: StringName
@export var label: String
@export var type: Type:
	set(t):
		type = t
		notify_property_list_changed()
@export var default_value: Variant
@export var visible_in_editor: bool = true
@export var exclusive: bool = false


func clamp_value(value: Variant) -> Variant:
	return value
