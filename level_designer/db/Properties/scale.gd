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
