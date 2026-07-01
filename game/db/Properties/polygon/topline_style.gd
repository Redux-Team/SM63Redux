@tool
class_name LDPropertyToplineStyle
extends LDProperty


func _init() -> void:
	key = &"topline_style"
	label = "Topline Style"
	type = LDProperty.Type.OPTION
	default_value = ""


func apply(_obj: LDObject, _value: Variant) -> void:
	pass
