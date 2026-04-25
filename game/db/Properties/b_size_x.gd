@tool
class_name LDPropertyBlockX
extends LDProperty


func _init() -> void:
	key = &"b_size_x"
	label = "Width"
	type = LDProperty.Type.INT
	default_value = 32
	exclusive = false

@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	var obj_size: Vector2 = obj.get(&"block_size")
	obj_size.x = value
	obj.set(&"block_size", obj_size)


func clamp_value(value: Variant) -> Variant:
	return clampi(value as int, 32, 1024)


func get_range() -> Vector2:
	return Vector2(32, 1024)


func get_step() -> float:
	return 16
