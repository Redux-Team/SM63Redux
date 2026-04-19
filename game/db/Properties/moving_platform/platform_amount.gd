@tool
class_name LDPropertyPlatformAmount
extends LDProperty


func _init() -> void:
	key = &"platform_amount"
	label = "Amount"
	type = LDProperty.Type.INT
	default_value = 1


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return clampi(value, 1, 16)


func get_range() -> Vector2:
	return Vector2(0, 16)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 1
