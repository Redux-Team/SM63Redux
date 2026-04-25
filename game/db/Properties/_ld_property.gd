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
	ARRAY_VECTOR2
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


func apply(obj: LDObject, value: Variant) -> void:
	obj.set(key, value)


func clamp_value(value: Variant) -> Variant:
	return value


func get_range() -> Vector2:
	return Vector2(-INF, INF)


func get_step() -> float:
	return 1.0


func get_arrow_step() -> float:
	return 1.0


func is_unbound() -> bool:
	return get_range() == Vector2(-INF, INF)
