class_name LevelObject
extends Node2D


var data: Dictionary
var properties: Dictionary = {}
var source_object_id: String = ""


func init_from_data(obj_data: Dictionary) -> void:
	data = obj_data
	source_object_id = obj_data.get("object_id", "")
	properties = obj_data.get("properties")
	_pre_init()
	_handle_properties()
	_on_init()


func get_property(key: StringName) -> Variant:
	return properties.get(key)


func set_property(key: StringName, value: Variant) -> void:
	properties[key] = value
	_on_property_changed(key, value)

## Main property method to be overridden, if necessary. This will go property by property. Call super()
## to let the superclass handle the property (if applicable).
func _handle_property(property_name: String, property_value: Variant) -> void:
	print("%s | %s | %s" % [property_name, property_value, self])
	if property_name in ["position", "scale"]:
		set(property_name, _array_to_vec2(property_value))
	else:
		set(property_name, property_value)

## Overrides the full property logic of the object.
func _handle_properties() -> void:
	for prop_name: String in properties:
		_handle_property(prop_name, properties.get(prop_name))


## Called before properties are set
func _pre_init() -> void:
	pass

## Called after properties are set
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
