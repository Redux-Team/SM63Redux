@tool
extends LDObjectPath

@export var head: SmartSprite2D
@export var stem: Line2D
@export var head_shape_area: Area2D
@export var stem_shape_area: Area2D
@export var stem_shape_width: float = 16.0
@export var use_stem_shape: bool = true

var _stem_shapes: Array[CollisionShape2D] = []


func _on_ready() -> void:
	if head_shape_area and not head_shape_area in editor_shape_areas:
		editor_shape_areas.append(head_shape_area)
	if stem_shape_area and not stem_shape_area in editor_shape_areas:
		editor_shape_areas.append(stem_shape_area)


func _on_preview() -> void:
	set_shader_parameter(&"post_modulate", Color(1.0, 1.0, 1.0, 0.6))


func _on_place() -> void:
	set_shader_parameter(&"post_modulate", Color.WHITE)


func _on_preview_valid_changed(valid: bool) -> void:
	if is_preview:
		set_shader_parameter(&"post_modulate",
		Color(1.0, 1.0, 1.0, 0.6) if valid else Color(1.0, 0.2, 0.2, 0.6))


func _on_points_changed(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	
	if head:
		head.position = points[0]
		if points.size() >= 2:
			head.rotation = (points[1] - points[0]).angle() - PI * 0.5
		_sync_head_shape(points[0], head.rotation)
	
	if stem:
		stem.points = get_path_points(stem.texture) if points.size() >= 2 else PackedVector2Array()
	
	_sync_stem_shapes(points)


func _sync_head_shape(pos: Vector2, rot: float) -> void:
	if not head_shape_area or not head:
		return
	head_shape_area.position = pos
	head_shape_area.rotation = rot
	var shapes: Array[Node] = head_shape_area.get_children()
	var shape_node: CollisionShape2D
	if shapes.is_empty():
		shape_node = CollisionShape2D.new()
		head_shape_area.add_child(shape_node)
	else:
		shape_node = shapes[0] as CollisionShape2D
	if not shape_node.shape:
		shape_node.shape = RectangleShape2D.new()
	var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
	rect.size = head.get_rect().size * head.scale


func _sync_stem_shapes(points: PackedVector2Array) -> void:
	if not stem_shape_area:
		return
	
	_clear_stem_shapes()
	
	if not use_stem_shape or points.size() < 2:
		return
	
	for i: int in points.size() - 1:
		var a: Vector2 = to_local(get_global_transform() * points[i]) if is_preview else points[i]
		var b: Vector2 = to_local(get_global_transform() * points[i + 1]) if is_preview else points[i + 1]
		var mid: Vector2 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		var angle: float = (b - a).angle()
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.position = mid
		shape.rotation = angle
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(length, stem_shape_width)
		shape.shape = rect
		stem_shape_area.add_child(shape)
		_stem_shapes.append(shape)


func _clear_stem_shapes() -> void:
	for s: CollisionShape2D in _stem_shapes:
		if is_instance_valid(s):
			s.queue_free()
	_stem_shapes.clear()
