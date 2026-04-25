@tool
class_name LDPropertyBlockRotateSpeed
extends LDProperty


func _init() -> void:
	key = &"b_rotate_speed"
	label = "Rotation Speed"
	type = LDProperty.Type.FLOAT
	default_value = 1.0
	exclusive = false


func clamp_value(value: Variant) -> Variant:
	return maxi(value as int, 0)


func get_range() -> Vector2:
	return Vector2(0, 16)


func get_step() -> float:
	return 1
