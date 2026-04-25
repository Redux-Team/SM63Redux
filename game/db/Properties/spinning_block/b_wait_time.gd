@tool
class_name LDPropertyBlockWaitTime
extends LDProperty


func _init() -> void:
	key = &"b_wait_time"
	label = "Wait Time"
	type = LDProperty.Type.FLOAT
	default_value = 2.0
	exclusive = false


func clamp_value(value: Variant) -> Variant:
	return max(value as float, 0)


func get_range() -> Vector2:
	return Vector2(0, 100)


func get_step() -> float:
	return 0.1
