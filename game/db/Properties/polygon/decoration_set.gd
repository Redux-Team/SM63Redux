@tool
class_name LDPropertyDecorationSet
extends LDProperty


func _init() -> void:
	key = &"decoration_set"
	label = "Decoration Set"
	type = LDProperty.Type.OPTION
	default_value = ""


func apply(_obj: LDObject, _value: Variant) -> void:
	pass
