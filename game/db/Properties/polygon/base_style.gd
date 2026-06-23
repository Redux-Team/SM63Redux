@tool
class_name LDPropertyBaseStyle
extends LDProperty


func _init() -> void:
	key = &"base_style"
	label = "Base Style"
	type = LDProperty.Type.OPTION
	default_value = ""


func apply(_obj: LDObject, _value: Variant) -> void:
	pass
