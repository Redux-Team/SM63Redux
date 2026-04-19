@tool
class_name LDPropertyPlatformStartAngle
extends LDProperty


func _init() -> void:
	key = &"platform_start_angle"
	label = "Starting Angle"
	type = LDProperty.Type.FLOAT
	default_value = 0.0


func apply(_obj: LDObject, _value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return wrapf(value as float, 0, 360.0)


func get_range() -> Vector2:
	return Vector2(0.0, 360.0)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 15
