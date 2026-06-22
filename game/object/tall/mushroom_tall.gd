extends LevelObjectPath


@export var head: SmartSprite2D
@export var stem: Line2D
@export var head_static_body: StaticBody2D
@export var stem_static_body: StaticBody2D
@export var stem_shape_width: float = 16.0
@export var use_stem_shape: bool = true


var _stem_shapes: Array[CollisionShape2D] = []


func _on_init() -> void:
	super()
	_rebuild_static_bodies()


func _on_points_changed(resolved_points: PackedVector2Array) -> void:
	if resolved_points.is_empty():
		return
	
	if head:
		head.position = resolved_points[0]
		if resolved_points.size() >= 2:
			head.rotation = (resolved_points[1] - resolved_points[0]).angle() - PI * 0.5
		_sync_head_shape(resolved_points[0], head.rotation)
	
	if stem:
		stem.points = resolved_points if resolved_points.size() >= 2 else PackedVector2Array()
	
	_sync_stem_shapes(resolved_points)


func _sync_head_shape(pos: Vector2, rot: float) -> void:
	if not head_static_body or not head:
		return
	
	head_static_body.position = pos
	head_static_body.rotation = rot
	
	var shape_node: CollisionShape2D
	if head_static_body.get_child_count() == 0:
		shape_node = CollisionShape2D.new()
		head_static_body.add_child(shape_node)
	else:
		shape_node = head_static_body.get_child(0) as CollisionShape2D
	
	if shape_node:
		if not shape_node.shape:
			shape_node.shape = RectangleShape2D.new()
		(shape_node.shape as RectangleShape2D).size = head.get_rect().size * head.scale


func _sync_stem_shapes(points: PackedVector2Array) -> void:
	_clear_stem_shapes()
	
	if not stem_static_body or not use_stem_shape or points.size() < 2:
		return
	
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.position = (a + b) * 0.5
		shape_node.rotation = (b - a).angle()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(a.distance_to(b), stem_shape_width)
		shape_node.shape = rect
		stem_static_body.add_child(shape_node)
		_stem_shapes.append(shape_node)


func _clear_stem_shapes() -> void:
	for s: CollisionShape2D in _stem_shapes:
		if is_instance_valid(s):
			s.queue_free()
	_stem_shapes.clear()


func _rebuild_static_bodies() -> void:
	var raw: PackedVector2Array = get_raw_points()
	if raw.is_empty():
		return
	_on_points_changed(get_path_points())


func _set_modulate(color: Color) -> void:
	if head:
		head.modulate = color
	if stem:
		stem.modulate = color
