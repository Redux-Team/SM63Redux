@tool
class_name LDPropertyRotation
extends LDProperty

@export var rotation_owner: StringName = &""

func _init() -> void:
	key = &"rotation"
	label = "Rotation"
	type = LDProperty.Type.FLOAT
	default_value = 0.0


func apply(obj: LDObject, value: Variant) -> void:
	var target: Node2D = obj
	if target and key == &"rotation":
		target.rotation_degrees = value
	elif target:
		target.set_property_no_apply(key, value)


func clamp_value(value: Variant) -> Variant:
	return wrapf(value as float, 0.0, 360.0)


func get_range() -> Vector2:
	return Vector2(0.0, 360.0)


func get_step() -> float:
	return 1.0


func get_arrow_step() -> float:
	return 15.0
