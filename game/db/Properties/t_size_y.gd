@tool
class_name LDPropertyTelescopeY
extends LDProperty


func _init() -> void:
	key = &"t_size_y"
	label = "Height"
	type = LDProperty.Type.INT
	default_value = 1
	exclusive = false

@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return maxi(value as int, 0)


func get_range() -> Vector2:
	return Vector2(0, 64)


func get_step() -> float:
	return 1.0
