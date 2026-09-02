class_name LDPathWidget
extends LDToolWidget

## Control points of the path being edited, plus the single dot that previews where a click on an
## edge would insert one. Control point 0 is the path's head, so it wears [member head_style]
## instead of the set's own style - one set keeps hit testing a single [method
## LDToolHandleSet.find_at] call whose index is already the point index.


## Screen distance at which an edge or the path body answers to the cursor. Handles carry their
## own radius on their style.
const GRAB_RADIUS: float = 18.0


@export var nodes: LDToolHandleSet
@export var edge_preview: LDToolHandleSet
## Worn by control point 0. The head reads differently from the nodes trailing it.
@export var head_style: LDToolWidgetStyle


var _dragging_index: int = -1
var _hovered_index: int = -1
var _hovered_edge: int = -1
var _drag_start_points: PackedVector2Array = PackedVector2Array()
var _pending_object_drag: bool = false


func _on_activate() -> void:
	_attach_to_overlay()
	_sync_handles()


func _on_deactivate() -> void:
	_detach_from_overlay()
	_dragging_index = -1
	_hovered_index = -1
	_hovered_edge = -1
	_pending_object_drag = false


func _on_refresh(_objects: Array[LDObject]) -> void:
	_hovered_index = -1
	_hovered_edge = -1
	_sync_handles()


func draw_overlay(_draw_node: CanvasItem) -> void:
	_sync_handles()


func _on_input(event: InputEvent) -> void:
	var obj: LDObjectPath = _get_path()
	if not obj or should_ignore_input():
		return
	
	if event is InputEventMouseMotion:
		_on_motion(obj)
	elif event is InputEventMouseButton:
		_on_button(obj, event as InputEventMouseButton)
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.is_pressed() or key.echo or _hovered_index < 0:
			return
		if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
			_delete_point(obj, _hovered_index)


func _on_motion(obj: LDObjectPath) -> void:
	if _pending_object_drag:
		_pending_object_drag = false
		_begin_move_handoff("path_edit", _bound_objects)
		return
	if _dragging_index >= 0:
		_drag_point(obj)
		return
	_update_hover(obj)


func _on_button(obj: LDObjectPath, event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and _hovered_index >= 0 and can_begin_interaction():
			_delete_point(obj, _hovered_index)
			is_double_click(-1)
		return
	
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if not event.pressed:
		if _dragging_index >= 0:
			_end_drag(obj)
		_pending_object_drag = false
		return
	
	if not can_begin_interaction():
		return
	
	if _hovered_index >= 0:
		if is_double_click(_hovered_index):
			_delete_point(obj, _hovered_index)
		else:
			_begin_drag(obj, _hovered_index)
	elif _hovered_edge >= 0:
		is_double_click(-1)
		_insert_point_on_edge(obj, _hovered_edge)
	elif _is_mouse_near_path(obj):
		_pending_object_drag = true
	else:
		get_ld_viewport().clear_selection()
		select_tool("select")
		_tool.get_tool_handler().get_selected_tool()._on_viewport_input(event)


func _update_hover(obj: LDObjectPath) -> void:
	_hovered_index = nodes.find_at(get_screen_mouse_pos())
	_hovered_edge = -1 if _hovered_index >= 0 else _find_edge_at(obj)
	
	if _hovered_index > 0 or _hovered_edge >= 0:
		_tool.set_cursor_shape(Control.CURSOR_POINTING_HAND)
	elif _hovered_index == 0:
		_tool.set_cursor_shape(Control.CURSOR_DRAG)
	else:
		_tool.set_cursor_shape(Control.CURSOR_ARROW)
	
	nodes.set_active(_hovered_index, _dragging_index)
	_sync_edge_preview(obj)


func _sync_handles() -> void:
	var obj: LDObjectPath = _get_path()
	if not obj:
		return
	
	var points: PackedVector2Array = obj.get_control_points()
	var handles: Array[LDToolHandle] = nodes.resize_to(points.size())
	if not handles.is_empty() and head_style and handles.front().style != head_style:
		handles.front().style = head_style
	
	var zoom: float = get_camera_zoom()
	for i: int in points.size():
		nodes.place(i, object_to_screen(obj, points.get(i)), zoom)
	
	nodes.set_active(_hovered_index, _dragging_index)
	_sync_edge_preview(obj)


func _sync_edge_preview(obj: LDObjectPath) -> void:
	var points: PackedVector2Array = obj.get_control_points()
	if _hovered_edge < 0 or _dragging_index >= 0 or _hovered_edge + 1 >= points.size():
		edge_preview.clear()
		return
	
	var a: Vector2 = object_to_screen(obj, points.get(_hovered_edge))
	var b: Vector2 = object_to_screen(obj, points.get(_hovered_edge + 1))
	var cursor: Vector2 = world_to_screen(get_snapped_mouse_pos(obj), obj)
	edge_preview.resize_to(1)
	edge_preview.place(0, Geometry2D.get_closest_point_to_segment(cursor, a, b), get_camera_zoom())


func _begin_drag(obj: LDObjectPath, index: int) -> void:
	_dragging_index = index
	_drag_start_points = obj.get_control_points().duplicate()
	_tool.set_cursor_shape(Control.CURSOR_DRAG)
	nodes.set_active(-1, index)


func _drag_point(obj: LDObjectPath) -> void:
	var points: PackedVector2Array = obj.get_control_points()
	if _dragging_index >= points.size():
		return
	points.set(_dragging_index, _tool.world_to_object(obj, get_snapped_mouse_pos(obj)))
	obj.apply_points(points)
	_sync_handles()


func _end_drag(obj: LDObjectPath) -> void:
	var new_points: PackedVector2Array = obj.get_control_points().duplicate()
	_dragging_index = -1
	_tool.set_cursor_shape(Control.CURSOR_ARROW)
	_push_points(obj, "Move Path Point", _drag_start_points.duplicate(), new_points)


func _delete_point(obj: LDObjectPath, index: int) -> void:
	var old_points: PackedVector2Array = obj.get_control_points().duplicate()
	if old_points.size() <= 2 or index < 0 or index >= old_points.size():
		return
	
	var new_points: PackedVector2Array = old_points.duplicate()
	new_points.remove_at(index)
	_hovered_index = -1
	_hovered_edge = -1
	_push_points(obj, "Delete Path Point", old_points, new_points)


func _insert_point_on_edge(obj: LDObjectPath, edge_index: int) -> void:
	var old_points: PackedVector2Array = obj.get_control_points().duplicate()
	if edge_index < 0 or edge_index + 1 >= old_points.size():
		return
	
	var local_pos: Vector2 = _tool.world_to_object(obj, get_snapped_mouse_pos(obj))
	var screen_pos: Vector2 = object_to_screen(obj, local_pos)
	for existing: Vector2 in old_points:
		if object_to_screen(obj, existing).distance_to(screen_pos) < GRAB_RADIUS:
			return
	
	var new_points: PackedVector2Array = old_points.duplicate()
	new_points.insert(edge_index + 1, local_pos)
	_push_points(obj, "Insert Path Point", old_points, new_points)
	_begin_drag(obj, edge_index + 1)


func _push_points(obj: LDObjectPath, action: String, old_points: PackedVector2Array, new_points: PackedVector2Array) -> void:
	get_history().push(action,
		func() -> void:
			if is_instance_valid(obj):
				obj.apply_points(new_points),
		func() -> void:
			if is_instance_valid(obj):
				obj.apply_points(old_points)
	)


## Index of the segment between two control points under the cursor, or -1.
func _find_edge_at(obj: LDObjectPath) -> int:
	var points: PackedVector2Array = obj.get_control_points()
	for i: int in points.size() - 1:
		if _near_segment(object_to_screen(obj, points.get(i)), object_to_screen(obj, points.get(i + 1))):
			return i
	return -1


## Whether the cursor is over the drawn path itself rather than one of its control points, which
## is what starts a body drag.
func _is_mouse_near_path(obj: LDObjectPath) -> bool:
	var points: PackedVector2Array = obj.get_path_points()
	for i: int in points.size() - 1:
		if _near_segment(object_to_screen(obj, points.get(i)), object_to_screen(obj, points.get(i + 1))):
			return true
	return false


func _near_segment(a: Vector2, b: Vector2) -> bool:
	var mouse: Vector2 = get_screen_mouse_pos()
	return mouse.distance_to(Geometry2D.get_closest_point_to_segment(mouse, a, b)) <= GRAB_RADIUS


func _get_path() -> LDObjectPath:
	if _bound_objects.is_empty():
		return null
	var obj: LDObject = _bound_objects.front()
	if not is_instance_valid(obj):
		return null
	return obj as LDObjectPath
