@tool
class_name LDPropertyDecorationsEnabled
extends LDProperty


func _init() -> void:
	key = &"decorations_enabled"
	label = "Decorations"
	type = LDProperty.Type.BOOL
	default_value = true


func apply(_obj: LDObject, _value: Variant) -> void:
	pass
