@tool
class_name LDPropertyPlatformRadius
extends LDProperty


func _init() -> void:
	key = &"platform_radius"
	label = "Radius"
	type = LDProperty.Type.FLOAT
	default_value = 64.0


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return clamp(value, 16.0, 256.0)


func get_range() -> Vector2:
	return Vector2(16, 256)


func get_step() -> float:
	return 8.0


func get_arrow_step() -> float:
	return 16.0
