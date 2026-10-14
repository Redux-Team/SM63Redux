@tool
class_name PathShape
extends ObjectShape

signal changed

const MIN_POINTS: int = 2

@export var stem: Line2D
@export var head: Node2D
@export var subdivide: bool = true
@export var default_points: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0, 48)])
@export var head_size: Vector2 = Vector2(32, 32)
@export_group("Collision")
@export var head_body: Node2D
@export var stem_body: StaticBody2D
@export var stem_width: float = 16.0

var points: PackedVector2Array = PackedVector2Array()
var _stem_shapes: Array[CollisionShape2D] = []


func _ready() -> void:
	if points.is_empty():
		set_points(default_points)
	_apply()


func get_kind() -> Kind:
	return Kind.PATH


func from_data(data: Dictionary) -> void:
	set_points(data.get("points", default_points))


func to_data() -> Dictionary:
	return {"points": points.duplicate()}


func set_points(value: PackedVector2Array) -> void:
	points = value.duplicate() if value.size() >= MIN_POINTS else default_points.duplicate()
	_apply()


func get_points() -> PackedVector2Array:
	return points.duplicate()


func get_resolved_points() -> PackedVector2Array:
	if subdivide and stem and stem.texture:
		return TerrainPolygon.subdivide_for_line2d(points, stem.texture)
	
	return points.duplicate()


func get_head_rotation() -> float:
	return (points.get(1) - points.get(0)).angle() - PI * 0.5 if points.size() >= MIN_POINTS else 0.0


func get_local_bounds() -> Rect2:
	var bounds: Rect2 = TerrainPolygon.get_bounds(points).grow(stem_width * 0.5)
	return bounds.merge(_head_rect()) if head else bounds


func contains_point(local_point: Vector2) -> bool:
	for i: int in points.size() - 1:
		if Geometry2D.get_closest_point_to_segment(local_point, points.get(i), points.get(i + 1)).distance_to(local_point) <= stem_width * 0.5:
			return true
	
	return head != null and _head_polygon().size() > 0 and Geometry2D.is_point_in_polygon(local_point, _head_polygon())


func get_outlines() -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for i: int in points.size() - 1:
		var a: Vector2 = points.get(i)
		var b: Vector2 = points.get(i + 1)
		var side: Vector2 = (b - a).orthogonal().normalized() * stem_width * 0.5
		outlines.append(PackedVector2Array([a + side, b + side, b - side, a - side]))
	if head:
		outlines.append(_head_polygon())
	
	return outlines


func _head_rect() -> Rect2:
	return TerrainPolygon.get_bounds(_head_polygon())


func _head_polygon() -> PackedVector2Array:
	var transform_2d: Transform2D = Transform2D(get_head_rotation(), points.get(0) if not points.is_empty() else Vector2.ZERO)
	var half: Vector2 = head_size * 0.5
	return transform_2d * PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])


func _apply() -> void:
	if not is_instance_valid(head_body):
		head_body = null
	if not is_instance_valid(stem_body):
		stem_body = null
	if points.size() < MIN_POINTS:
		return
	
	var resolved: PackedVector2Array = get_resolved_points()
	if stem:
		stem.points = resolved
	for node: Node2D in [head, head_body]:
		if node:
			node.position = points.get(0)
			node.rotation = get_head_rotation()
	_build_stem_collision()
	changed.emit()


func _build_stem_collision() -> void:
	if stem_body == null:
		return
	
	for shape_node: CollisionShape2D in _stem_shapes:
		shape_node.free()
	_stem_shapes.clear()
	for i: int in points.size() - 1:
		var a: Vector2 = points.get(i)
		var b: Vector2 = points.get(i + 1)
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(a.distance_to(b), stem_width)
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.shape = rectangle
		shape_node.position = (a + b) * 0.5
		shape_node.rotation = (b - a).angle()
		stem_body.add_child(shape_node)
		_stem_shapes.append(shape_node)
