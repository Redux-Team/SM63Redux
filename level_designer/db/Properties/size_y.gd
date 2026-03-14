@tool
class_name LDPropertySizeY
extends LDProperty


func _init() -> void:
	key = &"size_y"
	label = "Size Y"
	type = LDProperty.Type.FLOAT
	default_value = 1.0


func apply(obj: LDObject, value: Variant) -> void:
	if obj.editor_placement_rect and obj.editor_placement_rect.shape is RectangleShape2D:
		(obj.editor_placement_rect.shape as RectangleShape2D).size.y = value
