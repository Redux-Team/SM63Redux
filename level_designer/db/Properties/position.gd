@tool
class_name LDPropertyPosition
extends LDProperty


func _init() -> void:
	key = &"position"
	label = "Position"
	type = LDProperty.Type.VECTOR2
	default_value = Vector2.ZERO


func apply(obj: LDObject, value: Variant) -> void:
	obj.position = value
