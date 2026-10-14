class_name LDPolygonEditTool
extends LDWidgetTool

const EDGE_RADIUS: float = 12.0
const INSERT_ACTION: String = "Insert Polygon Point"

@export var vertex_style: LDHandleStyle
@export var hole_style: LDHandleStyle
@export var preview_style: LDHandleStyle

var _edge: Vector2i = Vector2i(-1, -1)
var _edge_point: Vector2
var _preview: LDHandle
var _before_rings: Array[PackedVector2Array] = []
var _before_toplines: Array[Dictionary] = []
var _action_name: String
var _press_world: Vector2


static func get_target(objects: Array[GameObject]) -> GameObject:
	if objects.size() != 1 or not objects.front().shape is PolygonShape:
		return null
	
	return objects.front()


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	var target: GameObject = get_target(objects)
	return [target] if target else []


func _layout_handles() -> void:
	var shape: PolygonShape = _shape()
	var to_world: Transform2D = targets.front().get_global_transform()
	for ring: int in shape.holes.size() + 1:
		var points: PackedVector2Array = shape.get_ring_points(ring)
		for index: int in points.size():
			place_handle(Vector2i(ring, index), to_world * points.get(index), vertex_style if ring == 0 else hole_style).cursor = Control.CURSOR_DRAG if is_dragging() else Control.CURSOR_POINTING_HAND


func _draw_guides(overlay: LDOverlay) -> void:
	if is_dragging() or _hovered or not _find_edge(editor.viewport_handler.get_world_mouse()):
		return
	
	if _preview == null:
		_preview = LDHandle.new(&"preview", preview_style)
	_preview.draw(overlay.canvas, editor.viewport_handler.to_screen(targets.front().get_global_transform() * _edge_point), LDHandleStyle.HandleState.NORMAL, get_process_delta_time())


func _on_empty_pressed(world_position: Vector2, screen: Vector2) -> bool:
	if not _find_edge(world_position):
		return false
	
	_press_world = world_position	
	var rings: Array[PackedVector2Array] = _shape().get_rings()
	var toplines: Array[Dictionary] = _shape().get_toplines()
	var points: PackedVector2Array = rings.get(_edge.x)
	var index: int = _edge.y + 1
	if Array(points).any(func(existing: Vector2) -> bool: return existing.distance_to(_edge_point) < LDPolygonStrokeTool.MIN_POINT_DISTANCE):
		return true
	
	_before_rings = _shape().get_rings()
	_before_toplines = _shape().get_toplines()
	toplines.set(_edge.x, PolygonShape.insert_override(toplines.get(_edge.x), index, points.size()))
	points.insert(index, _edge_point)
	rings.set(_edge.x, points)
	_shape().set_rings(rings, toplines)
	_sync_handles()
	_action_name = INSERT_ACTION
	press_handle(get_handle(Vector2i(_edge.x, index)), screen)
	return true


func _on_handle_pressed(_handle: LDHandle) -> void:
	if _action_name.is_empty():
		_before_rings = _shape().get_rings()
		_before_toplines = _shape().get_toplines()
		_action_name = "Move Polygon Point"


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var key: Vector2i = handle.key
	var rings: Array[PackedVector2Array] = _shape().get_rings()
	var points: PackedVector2Array = rings.get(key.x)
	points.set(key.y, to_parent(targets.front(), world_position) - targets.front().position)
	if not LDPolygonStrokeTool.is_simple(points):
		return
	
	if key.x > 0 and not Array(points).all(func(point: Vector2) -> bool: return Geometry2D.is_point_in_polygon(point, rings.front())):
		return
	
	rings.set(key.x, points)
	_shape().set_rings(rings, _shape().get_toplines())


func _on_handle_released(_handle: LDHandle) -> void:
	var action_name: String = _action_name
	_action_name = ""
	if action_name == INSERT_ACTION and not _moved:
		_shape().set_rings(_before_rings, _before_toplines)
		_click_through(_press_world)
		return
	
	if _shape().get_rings() != _before_rings:
		_commit(action_name, _shape().get_rings(), _shape().get_toplines())


func _on_handle_cancelled(_handle: LDHandle) -> void:
	_action_name = ""
	_shape().set_rings(_before_rings, _before_toplines)


func _on_handle_reset(handle: LDHandle) -> void:
	_on_handle_deleted(handle)


func _on_handle_deleted(handle: LDHandle) -> bool:
	var key: Vector2i = handle.key
	var rings: Array[PackedVector2Array] = _shape().get_rings()
	var toplines: Array[Dictionary] = _shape().get_toplines()
	var points: PackedVector2Array = rings.get(key.x)
	if points.size() <= PolygonShape.MIN_POINTS:
		if key.x == 0:
			return true
		
		rings.remove_at(key.x)
		toplines.remove_at(key.x)
	else:
		toplines.set(key.x, PolygonShape.remove_override(toplines.get(key.x), key.y, points.size()))
		points.remove_at(key.y)
		rings.set(key.x, points)
	
	_before_rings = _shape().get_rings()
	_before_toplines = _shape().get_toplines()
	_commit("Remove Hole" if rings.size() < _before_rings.size() else "Remove Polygon Point", rings, toplines)
	return true


func _click_through(world_position: Vector2) -> void:
	var selection: LDSelection = editor.object_handler.selection
	var hit: GameObject = editor.viewport_handler.pick(world_position)
	if hit == null:
		selection.clear()
	elif not selection.has(hit):
		selection.set_objects([hit])
		editor.tool_handler.enter_edit_tool(hit)


func _shape() -> PolygonShape:
	return targets.front().shape as PolygonShape


func _find_edge(world_position: Vector2) -> bool:
	_edge = Vector2i(-1, -1)
	var shape: PolygonShape = _shape()
	var to_world: Transform2D = targets.front().get_global_transform()
	var mouse: Vector2 = editor.viewport_handler.to_screen(world_position)
	var nearest: float = EDGE_RADIUS
	for ring: int in shape.holes.size() + 1:
		var points: PackedVector2Array = shape.get_ring_points(ring)
		for index: int in points.size():
			var a: Vector2 = editor.viewport_handler.to_screen(to_world * points.get(index))
			var b: Vector2 = editor.viewport_handler.to_screen(to_world * points.get((index + 1) % points.size()))
			var distance: float = Geometry2D.get_closest_point_to_segment(mouse, a, b).distance_to(mouse)
			if distance < nearest:
				nearest = distance
				_edge = Vector2i(ring, index)
	
	if _edge.x < 0:
		return false
	
	var ring_points: PackedVector2Array = shape.get_ring_points(_edge.x)
	var snapped_point: Vector2 = to_parent(targets.front(), world_position) - targets.front().position
	_edge_point = Geometry2D.get_closest_point_to_segment(snapped_point, ring_points.get(_edge.y), ring_points.get((_edge.y + 1) % ring_points.size()))
	_edge_point = editor.viewport_handler.snap(_edge_point + targets.front().position) - targets.front().position
	return true


func _commit(action_name: String, rings: Array[PackedVector2Array], toplines: Array[Dictionary]) -> void:
	var shape: PolygonShape = _shape()
	editor.history_handler.create(action_name) \
		.do(shape.set_rings.bind(rings, toplines)) \
		.undo(shape.set_rings.bind(_before_rings, _before_toplines)) \
		.commit()
