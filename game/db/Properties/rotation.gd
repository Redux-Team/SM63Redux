@tool
class_name LDPropertyRotation
extends LDProperty


func _init() -> void:
	key = &"rotation"
	label = "Rotation"
	type = LDProperty.Type.FLOAT
	default_value = 0.0


func apply(obj: LDObject, value: Variant) -> void:
	obj.rotation_degrees = value


func clamp_value(value: Variant) -> Variant:
	return wrapf(value as float, 0, 360.0)


func get_range() -> Vector2:
	return Vector2(0.0, 360.0)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 15
