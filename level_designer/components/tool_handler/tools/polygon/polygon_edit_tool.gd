extends LDTool

enum PointSource { OUTER, HOLE }

const DOUBLE_CLICK_SEC: float = 0.4
const POINT_GRAB_RADIUS: float = 18.0
const VERTEX_BUTTON_SIZE: float = 12.0

var _editing_object: LDObjectPolygon
var _drag_start_points: PackedVector2Array
var _dragging_point_index: int = -1
var _hovered_point_index: int = -1
var _hovered_edge_index: int = -1
var _last_click_time: float = 0.0
var _last_click_index: int = -1
var _pending_polygon_drag: bool = false
var _vertex_buttons: Array[Button] = []
var _edge_preview_button: Button
var _point_sources: Array[PointSource] = []
var _point_hole_indices: Array[int] = []
var _hovered_edge_is_hole: bool = false
var _hovered_edge_hole_idx: int = -1


func get_tool_name() -> String:
	return "PolygonEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected[0] is LDObjectPolygon:
		_editing_object = selected[0] as LDObjectPolygon
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
				_insert_point_on_edge(_hovered_edge_index, _hovered_edge_is_hole, _hovered_edge_hole_idx, _get_snapped_mouse_pos())
			elif _is_mouse_inside_polygon():
				_pending_polygon_drag = true
			else:
				viewport.clear_selection()
				get_tool_handler().select_tool("select")
				get_tool_handler().get_selected_tool()._on_viewport_input(event)
		else:
			if _dragging_point_index >= 0:
				_end_drag_point()
			_pending_polygon_drag = false
	
	if event is InputEventMouseMotion:
		if _pending_polygon_drag:
			_pending_polygon_drag = false
			var move: LDToolMove = _get_move_tool()
			if move and move.try_begin_drag(_get_screen_mouse_pos(), [_editing_object]):
				move.return_tool = "polygon_edit"
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


func _is_mouse_inside_polygon() -> bool:
	if not _editing_object or not _editing_object._polygon:
		return false
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * _editing_object.get_global_transform()
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _editing_object._polygon.polygon:
		screen_points.append(full_transform * point)
	return Geometry2D.is_point_in_polygon(_get_screen_mouse_pos(), screen_points)


func _get_move_tool() -> LDToolMove:
	return get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


func _on_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if objects.size() == 1 and objects[0] is LDObjectPolygon:
		_editing_object = objects[0] as LDObjectPolygon
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


func _get_points() -> PackedVector2Array:
	if not _editing_object:
		return PackedVector2Array()
	return _editing_object.get_outer_points()


func _get_all_display_points() -> PackedVector2Array:
	if not _editing_object:
		return PackedVector2Array()
	var result: PackedVector2Array = PackedVector2Array()
	_point_sources.clear()
	_point_hole_indices.clear()
	
	for p: Vector2 in _editing_object.get_outer_points():
		result.append(p)
		_point_sources.append(PointSource.OUTER)
		_point_hole_indices.append(-1)
	
	for hi: int in _editing_object.get_hole_count():
		for p: Vector2 in _editing_object.get_hole(hi):
			result.append(p)
			_point_sources.append(PointSource.HOLE)
			_point_hole_indices.append(hi)
	
	return result


func _update_hover(_world_pos: Vector2) -> void:
	if not _editing_object or not _editing_object._polygon:
		return
	if _dragging_point_index >= 0:
		return
	
	var global_xform: Transform2D = _editing_object.get_global_transform()
	_hovered_point_index = -1
	_hovered_edge_index = -1
	_hovered_edge_is_hole = false
	_hovered_edge_hole_idx = -1
	
	var all_points: PackedVector2Array = _get_all_display_points()
	for i: int in all_points.size():
		if _world_to_screen(global_xform * all_points[i]).distance_to(_get_screen_mouse_pos()) <= POINT_GRAB_RADIUS:
			_hovered_point_index = i
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	
	var outer_points: PackedVector2Array = _editing_object.get_outer_points()
	for i: int in outer_points.size():
		var a: Vector2 = _world_to_screen(global_xform * outer_points[i])
		var b: Vector2 = _world_to_screen(global_xform * outer_points[(i + 1) % outer_points.size()])
		if _point_near_segment(_get_screen_mouse_pos(), a, b, POINT_GRAB_RADIUS):
			_hovered_edge_index = i
			_hovered_edge_is_hole = false
			_hovered_edge_hole_idx = -1
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	
	for hi: int in _editing_object.get_hole_count():
		var hole: PackedVector2Array = _editing_object.get_hole(hi)
		for i: int in hole.size():
			var a: Vector2 = _world_to_screen(global_xform * hole[i])
			var b: Vector2 = _world_to_screen(global_xform * hole[(i + 1) % hole.size()])
			if _point_near_segment(_get_screen_mouse_pos(), a, b, POINT_GRAB_RADIUS):
				_hovered_edge_index = i
				_hovered_edge_is_hole = true
				_hovered_edge_hole_idx = hi
				set_cursor_shape(Control.CURSOR_POINTING_HAND)
				_sync_vertex_button_states()
				_sync_edge_preview_button()
				return
	
	set_cursor_shape(Control.CURSOR_ARROW)
	_sync_vertex_button_states()
	_sync_edge_preview_button()


func _begin_drag_point(index: int) -> void:
	_dragging_point_index = index
	_drag_start_points = _get_all_display_points().duplicate()
	set_cursor_shape(Control.CURSOR_DRAG)


func _drag_point(pos: Vector2) -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	if _dragging_point_index >= _point_sources.size():
		return
	
	var local_pos: Vector2 = _editing_object.to_local(pos)
	
	if _point_sources[_dragging_point_index] == PointSource.OUTER:
		var outer_idx: int = _dragging_point_index
		var pts: PackedVector2Array = _editing_object.get_outer_points()
		pts[outer_idx] = local_pos
		_editing_object.set_outer_points_only(pts)
	else:
		var hole_idx: int = _point_hole_indices[_dragging_point_index]
		var outer_pts: PackedVector2Array = _editing_object.get_outer_points()
		if not Geometry2D.is_point_in_polygon(local_pos, outer_pts):
			return
		var local_point_idx: int = 0
		for i: int in _dragging_point_index:
			if _point_sources[i] == PointSource.HOLE and _point_hole_indices[i] == hole_idx:
				local_point_idx += 1
		var hole: PackedVector2Array = _editing_object.get_hole(hole_idx)
		hole[local_point_idx] = local_pos
		_editing_object.set_hole(hole_idx, hole)
	
	_sync_vertex_buttons()


func _end_drag_point() -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	
	var new_outer: PackedVector2Array = _editing_object.get_outer_points().duplicate()
	var new_holes: Array[PackedVector2Array] = _editing_object.get_holes().duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	var old_outer: PackedVector2Array = PackedVector2Array()
	var old_holes: Array[PackedVector2Array] = []
	var outer_size: int = _editing_object.get_outer_points().size()
	
	for i: int in _drag_start_points.size():
		if i < outer_size:
			old_outer.append(_drag_start_points[i])
		else:
			break
	
	var idx: int = outer_size
	for hi: int in _editing_object.get_hole_count():
		var hole_size: int = _editing_object.get_hole(hi).size()
		var hole_pts: PackedVector2Array = PackedVector2Array()
		for i: int in hole_size:
			if idx < _drag_start_points.size():
				hole_pts.append(_drag_start_points[idx])
				idx += 1
		old_holes.append(hole_pts)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.clear_holes()
			obj.set_outer_points_only(new_outer)
			for h: PackedVector2Array in new_holes:
				obj.add_hole(h)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.clear_holes()
			obj.set_outer_points_only(old_outer)
			for h: PackedVector2Array in old_holes:
				obj.add_hole(h)
	)
	history.commit_action()
	
	_dragging_point_index = -1
	set_cursor_shape(Control.CURSOR_ARROW)


func _delete_point(index: int) -> void:
	if not _editing_object or index >= _point_sources.size():
		return
	
	var old_outer: PackedVector2Array = _editing_object.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = _editing_object.get_holes().duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	if _point_sources[index] == PointSource.OUTER:
		if old_outer.size() <= 3:
			return
		
		var outer_idx: int = index
		var new_outer: PackedVector2Array = old_outer.duplicate()
		new_outer.remove_at(outer_idx)
		
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Delete Polygon Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(new_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(old_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.commit_action()
		_editing_object.clear_holes()
		_editing_object.set_outer_points_only(new_outer)
		for h: PackedVector2Array in old_holes:
			_editing_object.add_hole(h)
	else:
		var hole_idx: int = _point_hole_indices[index]
		var hole: PackedVector2Array = _editing_object.get_hole(hole_idx)
		var hi: int = hole_idx
		
		var history: LDHistoryHandler = LD.get_history_handler()
		
		if hole.size() <= 3:
			history.begin_action("Remove Hole")
			history.add_do(func() -> void:
				if is_instance_valid(obj):
					obj.remove_hole(hi)
			)
			history.add_undo(func() -> void:
				if is_instance_valid(obj):
					obj.clear_holes()
					obj.set_outer_points_only(old_outer)
					for h: PackedVector2Array in old_holes:
						obj.add_hole(h)
			)
			history.commit_action()
			_editing_object.remove_hole(hole_idx)
			_hovered_point_index = -1
			_rebuild_vertex_buttons()
			return
		
		var local_idx: int = 0
		for i: int in index:
			if _point_sources[i] == PointSource.HOLE and _point_hole_indices[i] == hole_idx:
				local_idx += 1
		
		var new_hole: PackedVector2Array = hole.duplicate()
		new_hole.remove_at(local_idx)
		
		history.begin_action("Delete Hole Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.set_hole(hi, new_hole)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(old_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.commit_action()
		_editing_object.set_hole(hole_idx, new_hole)
	
	_hovered_point_index = -1
	_rebuild_vertex_buttons()


func _insert_point_on_edge(edge_index: int, is_hole: bool, hole_idx: int, pos: Vector2) -> void:
	if not _editing_object:
		return
	
	var local_pos: Vector2 = _editing_object.to_local(pos)
	var old_outer: PackedVector2Array = _editing_object.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = _editing_object.get_holes().duplicate()
	var obj: LDObjectPolygon = _editing_object
	
	if not is_hole:
		for existing: Vector2 in old_outer:
			if existing.distance_to(local_pos) < POINT_GRAB_RADIUS:
				return
		var new_outer: PackedVector2Array = old_outer.duplicate()
		new_outer.insert(edge_index + 1, local_pos)
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Insert Polygon Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(new_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(old_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.commit_action()
		_editing_object.clear_holes()
		_editing_object.set_outer_points_only(new_outer)
		for h: PackedVector2Array in old_holes:
			_editing_object.add_hole(h)
		_rebuild_vertex_buttons()
		_begin_drag_point(edge_index + 1)
	else:
		if hole_idx >= old_holes.size():
			return
		var hole: PackedVector2Array = old_holes[hole_idx].duplicate()
		for existing: Vector2 in hole:
			if existing.distance_to(local_pos) < POINT_GRAB_RADIUS:
				return
		hole.insert(edge_index + 1, local_pos)
		var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
		new_holes[hole_idx] = hole
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Insert Hole Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(old_outer)
				for h: PackedVector2Array in new_holes:
					obj.add_hole(h)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.set_outer_points_only(old_outer)
				for h: PackedVector2Array in old_holes:
					obj.add_hole(h)
		)
		history.commit_action()
		_editing_object.clear_holes()
		_editing_object.set_outer_points_only(old_outer)
		for h: PackedVector2Array in new_holes:
			_editing_object.add_hole(h)
		_rebuild_vertex_buttons()
		
		var inserted_global_idx: int = old_outer.size()
		for i: int in hole_idx:
			inserted_global_idx += old_holes[i].size()
		inserted_global_idx += edge_index + 1
		_begin_drag_point(inserted_global_idx)


func _rebuild_vertex_buttons() -> void:
	_clear_vertex_buttons()
	if not _editing_object:
		return
	
	var overlay: Control = viewport.get_selection_overlay()
	var all_points: PackedVector2Array = _get_all_display_points()
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	
	for i: int in all_points.size():
		var btn: Button = Button.new()
		var is_hole: bool = _point_sources[i] == PointSource.HOLE
		btn.theme_type_variation = &"PolyVertexHole" if is_hole else &"PolyVertex"
		btn.custom_minimum_size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
		btn.size = Vector2(VERTEX_BUTTON_SIZE, VERTEX_BUTTON_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var screen_pos: Vector2 = _world_to_screen(global_xform * all_points[i])
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
	
	var all_points: PackedVector2Array = _get_all_display_points()
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	
	for i: int in mini(_vertex_buttons.size(), all_points.size()):
		var screen_pos: Vector2 = _world_to_screen(global_xform * all_points[i])
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
	
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var points: PackedVector2Array
	if _hovered_edge_is_hole:
		if _hovered_edge_hole_idx >= _editing_object.get_hole_count():
			_edge_preview_button.visible = false
			return
		points = _editing_object.get_hole(_hovered_edge_hole_idx)
	else:
		points = _editing_object.get_outer_points()
	
	var a: Vector2 = global_xform * points[_hovered_edge_index]
	var b: Vector2 = global_xform * points[(_hovered_edge_index + 1) % points.size()]
	var snapped_world: Vector2 = _get_snapped_mouse_pos()
	var ab: Vector2 = b - a
	var t: float = clampf((snapped_world - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	var projected: Vector2 = a + t * ab
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	_edge_preview_button.position = _world_to_screen(projected) - Vector2(half, half)
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
