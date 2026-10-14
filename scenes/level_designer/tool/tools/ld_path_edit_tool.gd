class_name LDPathEditTool
extends LDWidgetTool

const EDGE_RADIUS: float = 12.0

@export var node_style: LDHandleStyle
@export var head_style: LDHandleStyle
@export var preview_style: LDHandleStyle

var _before: PackedVector2Array = PackedVector2Array()
var _edge: int = -1
var _edge_point: Vector2
var _preview: LDHandle
var _action_name: String


static func get_shape(object: GameObject) -> PathShape:
	return object.shape as PathShape if object else null


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return objects if objects.size() == 1 and get_shape(objects.front()) else []


func _layout_handles() -> void:
	var object: GameObject = targets.front()
	var points: PackedVector2Array = get_shape(object).points
	for index: int in points.size():
		var handle: LDHandle = place_handle(index, object.get_global_transform() * points.get(index), head_style if index == 0 else node_style)
		handle.cursor = Control.CURSOR_DRAG if is_dragging() or index == 0 else Control.CURSOR_POINTING_HAND


func _draw_guides(overlay: LDOverlay) -> void:
	if is_dragging() or _hovered or not _find_edge(editor.viewport_handler.get_world_mouse()):
		return
	
	if _preview == null:
		_preview = LDHandle.new(&"preview", preview_style)
	_preview.draw(overlay.canvas, editor.viewport_handler.to_screen(targets.front().get_global_transform() * _edge_point), LDHandleStyle.HandleState.NORMAL, get_process_delta_time())


func _on_empty_pressed(world_position: Vector2, screen: Vector2) -> bool:
	if not _find_edge(world_position):
		return false
	
	var shape: PathShape = get_shape(targets.front())
	var points: PackedVector2Array = shape.get_points()
	if Array(points).any(func(existing: Vector2) -> bool: return existing.distance_to(_edge_point) < LDPolygonStrokeTool.MIN_POINT_DISTANCE):
		return true
	
	_before = shape.get_points()
	points.insert(_edge + 1, _edge_point)
	shape.set_points(points)
	_sync_handles()
	_action_name = "Insert Path Point"
	press_handle(get_handle(_edge + 1), screen)
	return true


func _on_handle_pressed(_handle: LDHandle) -> void:
	if _action_name.is_empty():
		_before = get_shape(targets.front()).get_points()
		_action_name = "Move Path Point"


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var object: GameObject = targets.front()
	var shape: PathShape = get_shape(object)
	var points: PackedVector2Array = shape.get_points()
	points.set(handle.key, object.transform.affine_inverse() * to_parent(object, world_position))
	shape.set_points(points)
	object.invalidate_bounds()


func _on_handle_released(_handle: LDHandle) -> void:
	var action_name: String = _action_name
	_action_name = ""
	_commit(action_name, get_shape(targets.front()).get_points())


func _on_handle_cancelled(_handle: LDHandle) -> void:
	_action_name = ""
	get_shape(targets.front()).set_points(_before)


func _on_handle_reset(handle: LDHandle) -> void:
	_on_handle_deleted(handle)


func _on_handle_deleted(handle: LDHandle) -> bool:
	var shape: PathShape = get_shape(targets.front())
	var points: PackedVector2Array = shape.get_points()
	if points.size() <= PathShape.MIN_POINTS:
		return true
	
	_before = shape.get_points()
	points.remove_at(handle.key)
	_commit("Delete Path Point", points)
	return true


func _find_edge(world_position: Vector2) -> bool:
	_edge = -1
	var object: GameObject = targets.front()
	var points: PackedVector2Array = get_shape(object).points
	var to_world: Transform2D = object.get_global_transform()
	var mouse: Vector2 = editor.viewport_handler.to_screen(world_position)
	var nearest: float = EDGE_RADIUS
	for index: int in points.size() - 1:
		var a: Vector2 = editor.viewport_handler.to_screen(to_world * points.get(index))
		var b: Vector2 = editor.viewport_handler.to_screen(to_world * points.get(index + 1))
		var distance: float = Geometry2D.get_closest_point_to_segment(mouse, a, b).distance_to(mouse)
		if distance < nearest:
			nearest = distance
			_edge = index
	
	if _edge < 0:
		return false
	
	var local: Vector2 = object.transform.affine_inverse() * to_parent(object, world_position)
	_edge_point = Geometry2D.get_closest_point_to_segment(local, points.get(_edge), points.get(_edge + 1)).round()
	return true


func _commit(action_name: String, points: PackedVector2Array) -> void:
	if points == _before:
		return
	
	var object: GameObject = targets.front()
	editor.history_handler.create(action_name) \
		.do(_apply.bind(object, points)) \
		.undo(_apply.bind(object, _before)) \
		.commit()


func _apply(object: GameObject, points: PackedVector2Array) -> void:
	get_shape(object).set_points(points)
	object.invalidate_bounds()
	editor.object_handler.notify_changed()
