@tool
class_name LDPropertyDisabled
extends LDProperty


func _init() -> void:
	key = &"disabled"
	label = "Disabled"
	type = LDProperty.Type.BOOL
	default_value = false


func apply(obj: LDObject, value: Variant) -> void:
	if obj.editor_shape_area:
		obj.editor_shape_area.monitoring = not value
		obj.editor_shape_area.monitorable = not value
