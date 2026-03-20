extends LDTool


var _editing_object: LDObjectPolygon
var _dragging_point_index: int = -1
var _hovered_point_index: int = -1
var _hovered_edge_index: int = -1
const POINT_GRAB_RADIUS: float = 8.0


func get_tool_name() -> String:
	return "PolygonEdit"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_POINTING_HAND


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)


func _on_enable() -> void:
	super()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected[0] is LDObjectPolygon:
		_editing_object = selected[0] as LDObjectPolygon
	else:
		get_tool_handler().select_tool("select")


func _on_disable() -> void:
	_editing_object = null
	_dragging_point_index = -1
	_hovered_point_index = -1
	_hovered_edge_index = -1
	super()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.current_input_type == Singleton.InputType.TOUCHSCREEN:
		return
	
	if event is InputEventMouseMotion:
		var world_pos: Vector2 = _get_world_mouse_pos()
		_update_hover(world_pos)
		if _dragging_point_index >= 0:
			_drag_point(_get_snapped_mouse_pos())
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var world_pos: Vector2 = _get_world_mouse_pos()
			if _hovered_point_index >= 0:
				_begin_drag_point(_hovered_point_index)
			elif _hovered_edge_index >= 0:
				_insert_point_on_edge(_hovered_edge_index, _get_snapped_mouse_pos())
		else:
			if _dragging_point_index >= 0:
				_end_drag_point()
	
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and _hovered_point_index >= 0:
			_delete_point(_hovered_point_index)


func _on_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if objects.size() == 1 and objects[0] is LDObjectPolygon:
		_editing_object = objects[0] as LDObjectPolygon
	else:
		_editing_object = null
		get_tool_handler().select_tool("select")


func _update_hover(world_pos: Vector2) -> void:
	if not _editing_object or not _editing_object.editor_polygon:
		return
	
	var points: PackedVector2Array = _editing_object.editor_polygon.polygon
	var global_xform: Transform2D = _editing_object.get_global_transform()
	
	_hovered_point_index = -1
	_hovered_edge_index = -1
	
	for i: int in points.size():
		var screen_point: Vector2 = _world_to_screen(global_xform * points[i])
		var screen_mouse: Vector2 = _get_screen_mouse_pos()
		if screen_point.distance_to(screen_mouse) <= POINT_GRAB_RADIUS:
			_hovered_point_index = i
			return
	
	for i: int in points.size():
		var a: Vector2 = _world_to_screen(global_xform * points[i])
		var b: Vector2 = _world_to_screen(global_xform * points[(i + 1) % points.size()])
		if _point_near_segment(_get_screen_mouse_pos(), a, b, POINT_GRAB_RADIUS):
			_hovered_edge_index = i
			return


func _begin_drag_point(index: int) -> void:
	_dragging_point_index = index


func _drag_point(pos: Vector2) -> void:
	if not _editing_object or not _editing_object.editor_polygon:
		return
	var points: PackedVector2Array = _editing_object.editor_polygon.polygon
	var local_pos: Vector2 = _editing_object.to_local(pos)
	points[_dragging_point_index] = local_pos
	_apply_points(points)


func _end_drag_point() -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	
	var points: PackedVector2Array = _editing_object.editor_polygon.polygon.duplicate()
	var old_points: PackedVector2Array = points.duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, old_points)
	)
	history.commit_action()
	
	_dragging_point_index = -1


func _insert_point_on_edge(edge_index: int, pos: Vector2) -> void:
	if not _editing_object or not _editing_object.editor_polygon:
		return
	
	var points: PackedVector2Array = _editing_object.editor_polygon.polygon.duplicate()
	var local_pos: Vector2 = _editing_object.to_local(pos)
	var old_points: PackedVector2Array = points.duplicate()
	points.insert(edge_index + 1, local_pos)
	var new_points: PackedVector2Array = points.duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Insert Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, new_points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, old_points)
	)
	history.commit_action()
	
	_apply_points(new_points)


func _delete_point(index: int) -> void:
	if not _editing_object or not _editing_object.editor_polygon:
		return
	
	var points: PackedVector2Array = _editing_object.editor_polygon.polygon.duplicate()
	if points.size() <= 3:
		return
	
	var old_points: PackedVector2Array = points.duplicate()
	points.remove_at(index)
	var new_points: PackedVector2Array = points.duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Delete Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, new_points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			_apply_points_to(obj, old_points)
	)
	history.commit_action()
	
	_apply_points(new_points)
	_hovered_point_index = -1


func _apply_points(points: PackedVector2Array) -> void:
	if not _editing_object:
		return
	_apply_points_to(_editing_object, points)


func _apply_points_to(obj: LDObjectPolygon, points: PackedVector2Array) -> void:
	if obj._polygon:
		obj._polygon.polygon = points
	if obj.editor_polygon:
		obj.editor_polygon.polygon = points
	if obj._topline:
		obj._topline.points = points
	if obj._outline:
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		obj._outline.points = closed


func _point_near_segment(point: Vector2, a: Vector2, b: Vector2, threshold: float) -> bool:
	var ab: Vector2 = b - a
	var ap: Vector2 = point - a
	var t: float = clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	var closest: Vector2 = a + t * ab
	return point.distance_to(closest) <= threshold


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform * world_pos


func _get_world_mouse_pos() -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform.affine_inverse() * _get_screen_mouse_pos()


func _get_screen_mouse_pos() -> Vector2:
	return viewport.get_selection_overlay().get_local_mouse_position()


func _get_snapped_mouse_pos() -> Vector2:
	return _get_world_mouse_pos().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
