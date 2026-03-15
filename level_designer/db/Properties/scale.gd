@tool
class_name LDPropertyScale
extends LDProperty


func _init() -> void:
	key = &"scale"
	label = "Scale"
	type = LDProperty.Type.VECTOR2
	default_value = Vector2.ONE


func apply(obj: LDObject, value: Variant) -> void:
	obj.scale = value


func clamp_value(value: Variant) -> Variant:
	return (value as Vector2).clamp(Vector2(0.1, 0.1), Vector2(10.0, 10.0))
