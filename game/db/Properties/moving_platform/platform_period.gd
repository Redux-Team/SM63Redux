@tool
class_name LDPropertyPlatformSpeed
extends LDProperty


func _init() -> void:
	key = &"platform_period"
	label = "Period"
	type = LDProperty.Type.FLOAT
	default_value = 1.0


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return clamp(value, 0.0, 50.0)


func get_range() -> Vector2:
	return Vector2(0, 50)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 1
