@tool
class_name LDPropertyBlockY
extends LDProperty


func _init() -> void:
	key = &"b_size_y"
	label = "Height"
	type = LDProperty.Type.INT
	default_value = 32
	exclusive = false

@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	var obj_size: Vector2 = obj.get(&"block_size")
	obj_size.y = value
	obj.set(&"block_size", obj_size)


func clamp_value(value: Variant) -> Variant:
	return clampi(value as int, 32, 1024)


func get_range() -> Vector2:
	return Vector2(32, 1024)


func get_step() -> float:
	return 16
