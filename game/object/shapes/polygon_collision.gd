class_name PolygonCollision
extends Node

enum CollisionMode {
	SOLID,
	SEMISOLID,
	NONE,
}

@export var shape: PolygonShape
@export var body: CollisionObject2D
@export var polygon: CollisionPolygon2D
@export var area_polygons: Array[CollisionPolygon2D]
@export var mode: CollisionMode = CollisionMode.SOLID:
	set(value):
		mode = value
		_queue_sync()
@export var terrain_type: StringName
@export_group("Semisolid", "semisolid")
@export var semisolid_depth: float = 24.0
@export var semisolid_margin: float = 1.0

var _semisolid_shapes: Array[CollisionShape2D] = []
var _extra_polygons: Array[CollisionPolygon2D] = []
var _queued: bool = false


func _ready() -> void:
	if body and not terrain_type.is_empty():
		body.set_meta(&"terrain", terrain_type)
	shape.changed.connect(_queue_sync)
	sync()


func sync() -> void:
	_queued = false
	for semisolid: CollisionShape2D in _semisolid_shapes:
		semisolid.queue_free()
	_semisolid_shapes.clear()
	
	for extra: CollisionPolygon2D in _extra_polygons:
		extra.queue_free()
	_extra_polygons.clear()
	
	var pieces: Array[PackedVector2Array] = shape.get_pieces()
	for area: CollisionPolygon2D in area_polygons:
		_fill_polygons(area, pieces)
	
	if polygon:
		polygon.disabled = mode != CollisionMode.SOLID or pieces.is_empty()
		if mode == CollisionMode.SOLID:
			_fill_polygons(polygon, pieces)
		else:
			polygon.polygon = PackedVector2Array()
	
	if mode == CollisionMode.SEMISOLID and body:
		for segment: PackedVector2Array in shape.get_topline_segments():
			for i: int in segment.size() - 1:
				_add_slab(segment.get(i), segment.get(i + 1))


func _fill_polygons(target: CollisionPolygon2D, pieces: Array[PackedVector2Array]) -> void:
	target.polygon = pieces.front() if not pieces.is_empty() else PackedVector2Array()
	for piece: PackedVector2Array in pieces.slice(1):
		var extra: CollisionPolygon2D = target.duplicate() as CollisionPolygon2D
		extra.polygon = piece
		target.get_parent().add_child(extra)
		_extra_polygons.append(extra)


func _add_slab(a: Vector2, b: Vector2) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	
	var slab: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	slab.points = PackedVector2Array([Vector2(-length * 0.5, 0.0), Vector2(length * 0.5, 0.0), Vector2(length * 0.5, semisolid_depth), Vector2(-length * 0.5, semisolid_depth)])
	var node: CollisionShape2D = CollisionShape2D.new()
	node.shape = slab
	node.position = (a + b) * 0.5
	node.rotation = (b - a).angle()
	node.one_way_collision = true
	node.one_way_collision_margin = semisolid_margin
	body.add_child(node)
	_semisolid_shapes.append(node)


func _queue_sync() -> void:
	if _queued or not is_inside_tree():
		return
	
	_queued = true
	sync.call_deferred()
