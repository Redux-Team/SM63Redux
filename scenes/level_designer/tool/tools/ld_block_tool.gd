class_name LDBlockTool
extends LDDragPlaceTool


func _idle_preview(object: GameObject, at: Vector2) -> void:
	var shape: BlockShape = object.shape as BlockShape
	shape.set_size(shape.default_size)
	object.position = at + shape.size * 0.5


func _resize_preview(object: GameObject, origin: Vector2, current: Vector2) -> void:
	var shape: BlockShape = object.shape as BlockShape
	var delta: Vector2 = current - origin
	shape.set_size(delta.abs())
	var direction: Vector2 = Vector2(1.0 if delta.x >= 0.0 else -1.0, 1.0 if delta.y >= 0.0 else -1.0)
	object.position = origin + direction * shape.size * 0.5
	object.invalidate_bounds()
