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
@export var type: Type
@export var default_value: Variant
@export var visible_in_editor: bool = true


@abstract func apply(obj: LDObject, value: Variant) -> void
