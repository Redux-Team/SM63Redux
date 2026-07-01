class_name LevelObjectPath
extends LevelObject


@export var line2d: Line2D
@export var head: SmartSprite2D
@export var subdivide_path: bool = false

@export_group("Collision")
@export var head_static_body: StaticBody2D
@export var head_collision: CollisionPolygon2D
@export var stem_static_body: StaticBody2D
@export var stem_shape_width: float = 16.0
@export var use_stem_shape: bool = false


var path_points: PackedVector2Array = PackedVector2Array()
var _stem_shapes: Array[CollisionShape2D] = []


static func from_game_object(game_object: GameObject = null) -> LevelObjectPath:
	if not game_object:
		return null
	
	var instance: LevelObjectPath = preload("res://game/object_templates/path/level_object_path.tscn").instantiate()
	instance.subdivide_path = game_object.path_subdivide
	instance.use_stem_shape = game_object.path_use_stem_collision
	instance.stem_shape_width = game_object.path_stem_width
	
	if instance.line2d:
		instance.line2d.texture = game_object.path_line_texture
	
	if game_object.path_head_texture and instance.head:
		instance.head.diffuse_texture = game_object.path_head_texture
	elif instance.head:
		instance.head.queue_free()
		instance.head = null
	
	if game_object.path_head_collision and not game_object.path_head_collision_polygon.is_empty() and instance.head_collision:
		instance.head_collision.polygon = game_object.path_head_collision_polygon
		instance.head_collision.one_way_collision = true
	elif instance.head_static_body:
		instance.head_static_body.queue_free()
		instance.head_static_body = null
		instance.head_collision = null
	
	return instance


func _on_init() -> void:
	if not path_points.is_empty():
		_on_points_changed(_resolve_points())


func _handle_property(property_name: String, property_value: Variant) -> void:
	if property_name == "path_points":
		_apply_points(property_value)
	else:
		super(property_name, property_value)


func _apply_points(value: Variant) -> void:
	path_points = _coerce_points(value)
	
	var resolved: PackedVector2Array = _resolve_points()
	
	if line2d:
		line2d.points = resolved
	
	_on_points_changed(resolved)


func _coerce_points(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value
	if value is Array:
		return Packer.array_to_packed_vec2(value)
	return PackedVector2Array()


func _resolve_points() -> PackedVector2Array:
	if subdivide_path and line2d and line2d.texture:
		return TerrainPolygon.subdivide_for_line2d(path_points, line2d.texture)
	return path_points.duplicate()


func get_path_points() -> PackedVector2Array:
	return _resolve_points()


func get_raw_points() -> PackedVector2Array:
	return path_points.duplicate()


func _on_points_changed(resolved_points: PackedVector2Array) -> void:
	if resolved_points.is_empty():
		return
	
	if head:
		head.position = resolved_points[0]
		if resolved_points.size() >= 2:
			head.rotation = (resolved_points[1] - resolved_points[0]).angle() - PI * 0.5
		_sync_head_body(resolved_points[0], head.rotation)
	
	if line2d:
		line2d.points = resolved_points if resolved_points.size() >= 2 else PackedVector2Array()
	
	_sync_stem_shapes(resolved_points)


func _sync_head_body(pos: Vector2, rot: float) -> void:
	if not head_static_body:
		return
	head_static_body.position = pos
	head_static_body.rotation = rot


func _sync_stem_shapes(points: PackedVector2Array) -> void:
	if not stem_static_body:
		return
	
	_clear_stem_shapes()
	
	if not use_stem_shape or points.size() < 2:
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
