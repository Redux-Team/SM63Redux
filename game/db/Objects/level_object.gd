class_name LevelObject
extends Node2D


var data: Dictionary
var properties: Dictionary[StringName, Variant] = {}
var source_object_id: String = ""


func init_from_data(obj_data: Dictionary) -> void:
	data = obj_data
	source_object_id = obj_data.get("object_id", "")
	var props: Dictionary = obj_data.get("properties", {})
	for key: String in props:
		properties[key] = props[key]
	position = _array_to_vec2(obj_data.get("position", [0.0, 0.0]))
	_on_init()


func get_property(key: StringName) -> Variant:
	return properties.get(key)


func set_property(key: StringName, value: Variant) -> void:
	properties[key] = value
	_on_property_changed(key, value)


func _on_init() -> void:
	pass


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass


func _array_to_vec2(a: Variant) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


func _array_to_packed_vec2(a: Variant) -> PackedVector2Array:
	var packed: PackedVector2Array = []
	if a is Array and a.size() >= 1:
		for v_a: Array in a:
			packed.append(Vector2(float(v_a[0]), float(v_a[1])))
	return packed
