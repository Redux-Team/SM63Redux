extends LevelObjectPath


@export var head: SmartSprite2D
@export var stem: Line2D
@export var stem_shape_width: float = 16.0
@export var use_stem_shape: bool = true


var _stem_shapes: Array[CollisionShape2D] = []


func _on_points_changed(resolved_points: PackedVector2Array) -> void:
	if resolved_points.is_empty():
		return
	
	if head:
		head.position = resolved_points[0]
		if resolved_points.size() >= 2:
			head.rotation = (resolved_points[1] - resolved_points[0]).angle() - PI * 0.5
	if stem:
		stem.points = resolved_points if resolved_points.size() >= 2 else PackedVector2Array()
	
	_sync_stem_shapes(resolved_points)


func _sync_stem_shapes(points: PackedVector2Array) -> void:
	_clear_stem_shapes()
	
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.position = (a + b) * 0.5
		shape_node.rotation = (b - a).angle()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(a.distance_to(b), stem_shape_width)
		shape_node.shape = rect
		_stem_shapes.append(shape_node)


func _clear_stem_shapes() -> void:
	for s: CollisionShape2D in _stem_shapes:
		if is_instance_valid(s):
			s.queue_free()
	_stem_shapes.clear()


func _set_modulate(color: Color) -> void:
	if head:
		head.modulate = color
	if stem:
		stem.modulate = color
