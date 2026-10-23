class_name LDTelescopingTool
extends LDDragPlaceTool


func _idle_preview(object: GameObject, at: Vector2) -> void:
	var shape: TelescopingShape = object.shape as TelescopingShape
	shape.set_units(shape.default_units)
	object.position = at


func _resize_preview(object: GameObject, origin: Vector2, current: Vector2) -> void:
	var shape: TelescopingShape = object.shape as TelescopingShape
	var axis: Vector2 = shape.get_axis_vector()
	var reach: float = (current - origin).dot(axis)
	var base: float = shape.get_segment_length() * shape.default_units
	shape.set_units(
			maxi(
					shape.default_units,
					roundi((absf(reach) + base * 0.5) / shape.get_segment_length()),
			)
	)
	object.position = (
			origin
			+ (axis * signf(reach) * (shape.get_length() - shape.get_caps_length() - base) * 0.5)
	)
	object.invalidate_bounds()
