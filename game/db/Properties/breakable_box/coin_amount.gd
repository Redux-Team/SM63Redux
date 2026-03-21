@tool
class_name LDPropertyCoinAmount
extends LDProperty


func _init() -> void:
	key = &"coin_amount"
	label = "Coin Amount"
	type = LDProperty.Type.INT
	default_value = 5


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	pass


func clamp_value(value: Variant) -> Variant:
	return clampi(value, 0, 100)


func get_range() -> Vector2:
	return Vector2(0, 100)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 1
