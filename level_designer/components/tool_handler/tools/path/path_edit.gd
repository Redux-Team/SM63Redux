extends LDTool

const DOUBLE_CLICK_SEC: float = 0.4
const POINT_GRAB_RADIUS: float = 18.0
const VERTEX_BUTTON_SIZE: float = 12.0

var _editing_object: LDObjectPath
var _drag_start_points: PackedVector2Array
var _dragging_point_index: int = -1
var _hovered_point_index: int = -1
var _hovered_edge_index: int = -1
var _last_click_time: float = 0.0
var _last_click_index: int = -1
var _pending_object_drag: bool = false
var _vertex_buttons: Array[Button] = []
var _edge_preview_button: Button


func get_tool_name() -> String:
	return "PathEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected[0] is LDObjectPath:
		_editing_object = selected[0] as LDObjectPath
		_rebuild_vertex_buttons()
		_create_edge_preview_button()
	else:
		get_tool_handler().select_tool("select")


func _on_disable() -> void:
	_editing_object = null
	_dragging_point_index = -1
	_hovered_point_index = -1
	_hovered_edge_index = -1
	_clear_vertex_buttons()
	_destroy_edge_preview_button()
	super()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		_update_hover(_get_world_mouse_pos())
		if _dragging_point_index >= 0:
			_drag_point(_get_snapped_mouse_pos())
			_sync_vertex_buttons()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hovered_point_index >= 0:
				var now: float = Time.get_ticks_msec() / 1000.0
				if _last_click_index == _hovered_point_index and now - _last_click_time <= DOUBLE_CLICK_SEC:
					_delete_point(_hovered_point_index)
					_last_click_time = 0.0
					_last_click_index = -1
				else:
					_last_click_time = now
					_last_click_index = _hovered_point_index
					_begin_drag_point(_hovered_point_index)
			elif _hovered_edge_index >= 0:
				_last_click_index = -1
				_insert_point_on_edge(_hovered_edge_index, _get_snapped_mouse_pos())
			elif _is_mouse_near_path():
				_pending_object_drag = true
			else:
				viewport.clear_selection()
				get_tool_handler().select_tool("select")
				get_tool_handler().get_selected_tool()._on_viewport_input(event)
		else:
			if _dragging_point_index >= 0:
				_end_drag_point()
			_pending_object_drag = false
	
	if event is InputEventMouseMotion:
		if _pending_object_drag:
			_pending_object_drag = false
			var move: LDToolMove = _get_move_tool()
			if move and move.try_begin_drag(_get_screen_mouse_pos(), [_editing_object]):
				move.return_tool = "path_edit"
				get_tool_handler().select_tool("move")
			return
		_update_hover(_get_world_mouse_pos())
		if _dragging_point_index >= 0:
			_drag_point(_get_snapped_mouse_pos())
			_sync_vertex_buttons()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _hovered_point_index >= 0:
			_delete_point(_hovered_point_index)
			_last_click_index = -1
	
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and _hovered_point_index >= 0:
			_delete_point(_hovered_point_index)


func _is_mouse_near_path() -> bool:
	if not _editing_object:
		return false
	var points: PackedVector2Array = _editing_object.get_path_points()
	if points.size() < 2:
		return false
	var global_xform: Transform2D = _editing_object.get_global_transform()
	for i: int in points.size() - 1:
		var a: Vector2 = _world_to_screen(global_xform * points[i])
		var b: Vector2 = _world_to_screen(global_xform * points[i + 1])
		if _point_near_segment(_get_screen_mouse_pos(), a, b, POINT_GRAB_RADIUS):
			return true
	return false


func _on_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if objects.size() == 1 and objects[0] is LDObjectPath:
		_editing_object = objects[0] as LDObjectPath
		_rebuild_vertex_buttons()
		_create_edge_preview_button()
	else:
		_editing_object = null
		_clear_vertex_buttons()
		_destroy_edge_preview_button()
		get_tool_handler().select_tool("select")


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if is_active():
		_sync_vertex_buttons()
		_sync_edge_preview_button()


func _get_move_tool() -> LDToolMove:
	return get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


func _update_hover(_world_pos: Vector2) -> void:
	if not _editing_object or _dragging_point_index >= 0:
		return
	
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var points: PackedVector2Array = _editing_object.get_control_points()
	_hovered_point_index = -1
	_hovered_edge_index = -1
	
	for i: int in points.size():
		if _world_to_screen(global_xform * points[i]).distance_to(_get_screen_mouse_pos()) <= POINT_GRAB_RADIUS:
			_hovered_point_index = i
			set_cursor_shape(Control.CURSOR_POINTING_HAND if i > 0 else Control.CURSOR_DRAG)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	
	for i: int in points.size() - 1:
		var a: Vector2 = _world_to_screen(global_xform * points[i])
		var b: Vector2 = _world_to_screen(global_xform * points[i + 1])
		if _point_near_segment(_get_screen_mouse_pos(), a, b, POINT_GRAB_RADIUS):
			_hovered_edge_index = i
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	
	set_cursor_shape(Control.CURSOR_ARROW)
	_sync_vertex_button_states()
	_sync_edge_preview_button()


func _begin_drag_point(index: int) -> void:
	_dragging_point_index = index
	_drag_start_points = _editing_object.get_control_points().duplicate()
	set_cursor_shape(Control.CURSOR_DRAG)


func _drag_point(pos: Vector2) -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	var local_pos: Vector2 = _editing_object.to_local(pos)
	var pts: PackedVector2Array = _editing_object.get_control_points()
	pts[_dragging_point_index] = local_pos
	_editing_object.apply_points(pts)
	_sync_vertex_buttons()


func _end_drag_point() -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	
	var new_points: PackedVector2Array = _editing_object.get_control_points().duplicate()
	var old_points: PackedVector2Array = _drag_start_points.duplicate()
	var obj: LDObjectPath = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Path Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(new_points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(old_points)
	)
	history.commit_action()
	
	_dragging_point_index = -1
	set_cursor_shape(Control.CURSOR_ARROW)


func _delete_point(index: int) -> void:
	if not _editing_object:
		return
	var pts: PackedVector2Array = _editing_object.get_control_points()
	if pts.size() <= 2:
		return
	
	var old_points: PackedVector2Array = pts.duplicate()
	pts.remove_at(index)
	var new_points: PackedVector2Array = pts.duplicate()
	var obj: LDObjectPath = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Delete Path Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(new_points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(old_points)
	)
	history.commit_action()
	
	_editing_object.apply_points(new_points)
	_hovered_point_index = -1
	_rebuild_vertex_buttons()



func _insert_point_on_edge(edge_index: int, pos: Vector2) -> void:
	if not _editing_object:
		return
	var local_pos: Vector2 = _editing_object.to_local(pos)
	var old_points: PackedVector2Array = _editing_object.get_control_points().duplicate()
	for existing: Vector2 in old_points:
		if existing.distance_to(local_pos) < POINT_GRAB_RADIUS:
			return
	var new_points: PackedVector2Array = old_points.duplicate()
	new_points.insert(edge_index + 1, local_pos)
	var obj: LDObjectPath = _editing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Insert Path Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(new_points)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.apply_points(old_points)
	)
	history.commit_action()
	
	_editing_object.apply_points(new_points)
	_rebuild_vertex_buttons()
	_begin_drag_point(edge_index + 1)


func _rebuild_vertex_buttons() -> void:
	_clear_vertex_buttons()
	if not _editing_object:
		return
	
	var overlay: Control = viewport.get_selection_overlay()
	var points: PackedVector2Array = _editing_object.get_control_points()
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	
	for i: int in points.size():
		var btn: Button = Button.new()
		btn.theme_type_variation = &"PolyVertexHead" if i == 0 else &"PolyVertex"
		btn.custom_minimum_size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
		btn.size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var screen_pos: Vector2 = _world_to_screen(global_xform * points[i])
		btn.position = screen_pos - Vector2(half, half)
		overlay.add_child(btn)
		_vertex_buttons.append(btn)


func _clear_vertex_buttons() -> void:
	for btn: Button in _vertex_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_vertex_buttons.clear()


func _sync_vertex_buttons() -> void:
	if not _editing_object:
		return
	var points: PackedVector2Array = _editing_object.get_control_points()
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	for i: int in mini(_vertex_buttons.size(), points.size()):
		var screen_pos: Vector2 = _world_to_screen(global_xform * points[i])
		_vertex_buttons[i].position = screen_pos - Vector2(half, half)


func _sync_vertex_button_states() -> void:
	for i: int in _vertex_buttons.size():
		_vertex_buttons[i].set_pressed_no_signal(i == _hovered_point_index)


func _create_edge_preview_button() -> void:
	_destroy_edge_preview_button()
	var overlay: Control = viewport.get_selection_overlay()
	_edge_preview_button = Button.new()
	_edge_preview_button.theme_type_variation = &"PolyVertexPreview"
	_edge_preview_button.custom_minimum_size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
	_edge_preview_button.size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
	_edge_preview_button.focus_mode = Control.FOCUS_NONE
	_edge_preview_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_preview_button.visible = false
	overlay.add_child(_edge_preview_button)


func _destroy_edge_preview_button() -> void:
	if is_instance_valid(_edge_preview_button):
		_edge_preview_button.queue_free()
	_edge_preview_button = null


func _sync_edge_preview_button() -> void:
	if not is_instance_valid(_edge_preview_button):
		return
	if _hovered_edge_index < 0 or _dragging_point_index >= 0:
		_edge_preview_button.visible = false
		return
	
	var points: PackedVector2Array = _editing_object.get_control_points()
	if _hovered_edge_index + 1 >= points.size():
		_edge_preview_button.visible = false
		return
	
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var a: Vector2 = global_xform * points[_hovered_edge_index]
	var b: Vector2 = global_xform * points[_hovered_edge_index + 1]
	var snapped_world: Vector2 = _get_snapped_mouse_pos()
	var ab: Vector2 = b - a
	var t: float = clampf((snapped_world - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	_edge_preview_button.position = _world_to_screen(a + t * ab) - Vector2(half, half)
	_edge_preview_button.visible = true


func _point_near_segment(point: Vector2, a: Vector2, b: Vector2, threshold: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = clampf((point - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return point.distance_to(a + t * ab) <= threshold


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
