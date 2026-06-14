@tool
class_name LDPropertyIsKickout
extends LDProperty


func _init() -> void:
	key = &"kickout"
	label = "Kickout"
	type = LDProperty.Type.BOOL
	default_value = true
