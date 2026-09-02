class_name LDPolygonWidget
extends LDToolWidget


const EDGE_GRAB_RADIUS: float = 18.0


@export var vertices: LDToolHandleSet
@export var hole_vertices: LDToolHandleSet
@export var edge_preview: LDToolHandleSet


var _outer_count: int = 0
var _hole_of: Array[int] = []
var _hole_ring_index: Array[int] = []
var _hovered_point: int = -1
var _hovered_edge: int = -1
var _hovered_edge_hole: int = -1
var _pressed_point: int = -1


func _on_activate() -> void:
	_attach_to_overlay()
	sync()


func _on_deactivate() -> void:
	_pressed_point = -1
	_clear_hover()
	_detach_from_overlay()


func _on_refresh(_objects: Array[LDObject]) -> void:
	_clear_hover()
	sync()


func draw_overlay(_draw_node: CanvasItem) -> void:
	sync()


func sync() -> void:
	var obj: LDObjectPolygon = get_polygon()
	if not obj:
		return
	
	var zoom: float = get_camera_zoom()
	var outer: PackedVector2Array = obj.get_outer_points()
	_outer_count = outer.size()
	vertices.resize_to(_outer_count)
	for i: int in _outer_count:
		vertices.place(i, object_to_screen(obj, outer.get(i)), zoom)
	
	_hole_of.clear()
	_hole_ring_index.clear()
	var hole_points: PackedVector2Array = PackedVector2Array()
	for hi: int in obj.get_hole_count():
		var hole: PackedVector2Array = obj.get_hole(hi)
		for i: int in hole.size():
			hole_points.append(hole.get(i))
			_hole_of.append(hi)
			_hole_ring_index.append(i)
	
	hole_vertices.resize_to(hole_points.size())
	for i: int in hole_points.size():
		hole_vertices.place(i, object_to_screen(obj, hole_points.get(i)), zoom)
	
	_sync_states()
	_sync_edge_preview()


func update_hover() -> void:
	var obj: LDObjectPolygon = get_polygon()
	if not obj:
		return
	
	var mouse: Vector2 = get_screen_mouse_pos()
	_hovered_edge = -1
	_hovered_edge_hole = -1
	_hovered_point = vertices.find_at(mouse)
	
	if _hovered_point < 0:
		var hole_hit: int = hole_vertices.find_at(mouse)
		if hole_hit >= 0:
			_hovered_point = _outer_count + hole_hit
	
	if _hovered_point < 0:
		_find_hovered_edge(obj, mouse)
	
	_sync_states()
	_sync_edge_preview()


func get_polygon() -> LDObjectPolygon:
	if _bound_objects.is_empty():
		return null
	return _bound_objects.front() as LDObjectPolygon


func get_point_count() -> int:
	return _outer_count + _hole_of.size()


func get_hovered_point() -> int:
	return _hovered_point


func get_hovered_edge() -> int:
	return _hovered_edge


## Which hole the hovered edge belongs to, or -1 when it belongs to the outer ring.
func get_hovered_edge_hole() -> int:
	return _hovered_edge_hole


func is_hole_point(index: int) -> bool:
	return index >= _outer_count and index < get_point_count()


func get_hole_of(index: int) -> int:
	if not is_hole_point(index):
		return -1
	return _hole_of.get(index - _outer_count)


## Where a point sits inside its own ring, which is what the object's setters index by.
func get_ring_index(index: int) -> int:
	if is_hole_point(index):
		return _hole_ring_index.get(index - _outer_count)
	return index


func set_pressed_point(index: int) -> void:
	_pressed_point = index
	_sync_states()
	_sync_edge_preview()


func forget_last_click() -> void:
	_last_click_index = -1
	_last_click_time = -INF


func is_mouse_inside() -> bool:
	var obj: LDObjectPolygon = get_polygon()
	if not obj:
		return false
	var xform: Transform2D = _object_xform(obj)
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in obj.get_ring():
		screen_points.append(xform * point)
	return Geometry2D.is_point_in_polygon(get_screen_mouse_pos(), screen_points)


func _clear_hover() -> void:
	_hovered_point = -1
	_hovered_edge = -1
	_hovered_edge_hole = -1


func _sync_states() -> void:
	vertices.set_active(_outer_index(_hovered_point), _outer_index(_pressed_point))
	hole_vertices.set_active(_hole_index(_hovered_point), _hole_index(_pressed_point))


func _outer_index(index: int) -> int:
	return index if index >= 0 and index < _outer_count else -1


func _hole_index(index: int) -> int:
	return index - _outer_count if is_hole_point(index) else -1


func _find_hovered_edge(obj: LDObjectPolygon, mouse: Vector2) -> void:
	var xform: Transform2D = _object_xform(obj)
	_hovered_edge = _edge_at(xform, obj.get_outer_points(), mouse)
	if _hovered_edge >= 0:
		return
	
	for hi: int in obj.get_hole_count():
		_hovered_edge = _edge_at(xform, obj.get_hole(hi), mouse)
		if _hovered_edge >= 0:
			_hovered_edge_hole = hi
			return


func _edge_at(xform: Transform2D, points: PackedVector2Array, mouse: Vector2) -> int:
	for i: int in points.size():
		var a: Vector2 = xform * points.get(i)
		var b: Vector2 = xform * points.get((i + 1) % points.size())
		if mouse.distance_to(_project_onto(a, b, mouse)) <= EDGE_GRAB_RADIUS:
			return i
	return -1


func _sync_edge_preview() -> void:
	var obj: LDObjectPolygon = get_polygon()
	if not obj or _hovered_edge < 0 or _pressed_point >= 0:
		edge_preview.resize_to(0)
		return
	
	var points: PackedVector2Array = obj.get_outer_points()
	if _hovered_edge_hole >= 0:
		if _hovered_edge_hole >= obj.get_hole_count():
			edge_preview.resize_to(0)
			return
		points = obj.get_hole(_hovered_edge_hole)
	
	if _hovered_edge >= points.size():
		edge_preview.resize_to(0)
		return
	
	var layer_xform: Transform2D = obj.transform
	var a: Vector2 = layer_xform * points.get(_hovered_edge)
	var b: Vector2 = layer_xform * points.get((_hovered_edge + 1) % points.size())
	var projected: Vector2 = _project_onto(a, b, get_snapped_mouse_pos(obj))
	edge_preview.resize_to(1)
	edge_preview.place(0, world_to_screen(projected, obj), get_camera_zoom())


func _project_onto(a: Vector2, b: Vector2, point: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	return a + clampf((point - a).dot(ab) / ab.dot(ab), 0.0, 1.0) * ab


func _object_xform(obj: Node2D) -> Transform2D:
	return get_ld_viewport().object_transform(obj)
