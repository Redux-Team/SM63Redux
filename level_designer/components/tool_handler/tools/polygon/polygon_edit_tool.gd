extends LDTool

enum PointSource { OUTER, HOLE }

const DOUBLE_CLICK_SEC: float = 0.4
const POINT_GRAB_RADIUS: float = 18.0
const VERTEX_BUTTON_SIZE: float = 12.0
const BEZIER_STEPS: int = 12
const HANDLE_KNOB_RADIUS: float = 5.0
const HANDLE_HIT_RADIUS: float = 10.0

var _editing_object: LDObjectPolygon
var _dragging_point_index: int = -1
var _drag_start_outer: LDPolygon
var _drag_start_holes: Array[LDPolygon]
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
var _ctrl_outer: LDPolygon = LDPolygon.new()
var _ctrl_holes: Array[LDPolygon] = []
var _drag_handle_source: PointSource = PointSource.OUTER
var _drag_handle_hi: int = -1
var _drag_handle_idx: int = -1
var _drag_handle_side: String = ""
var _overlay: Control


func get_tool_name() -> String:
	return "PolygonEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	_overlay = viewport.get_selection_overlay()
	_overlay.draw.connect(_on_overlay_draw)
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected[0] is LDObjectPolygon:
		_editing_object = selected[0] as LDObjectPolygon
		_load_ctrl_mesh()
		_rebuild_vertex_buttons()
		_create_edge_preview_button()
	else:
		get_tool_handler().select_tool("select")


func _on_disable() -> void:
	if is_instance_valid(_overlay) and _overlay.draw.is_connected(_on_overlay_draw):
		_overlay.draw.disconnect(_on_overlay_draw)
	_ctrl_outer = LDPolygon.new()
	_ctrl_holes.clear()
	_editing_object = null
	_dragging_point_index = -1
	_hovered_point_index = -1
	_hovered_edge_index = -1
	_clear_vertex_buttons()
	_destroy_edge_preview_button()
	super()


func _input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	if event.keycode == KEY_C and _hovered_point_index >= 0:
		_get_all_display_points()
		_toggle_curve(_hovered_point_index)
		_push_flattened()
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _drag_handle_side.is_empty():
				return
			var hit: Dictionary = _hit_test_handles(_get_screen_mouse_pos())
			if hit.get("hit", false):
				_drag_handle_source = hit["source"]
				_drag_handle_hi = hit["hi"]
				_drag_handle_idx = hit["idx"]
				_drag_handle_side = hit["side"]
				return
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
			if not _drag_handle_side.is_empty():
				_drag_handle_source = PointSource.OUTER
				_drag_handle_hi = -1
				_drag_handle_idx = -1
				_drag_handle_side = ""
				return
			if _dragging_point_index >= 0:
				_end_drag_point()
			_pending_polygon_drag = false
	if event is InputEventMouseMotion:
		if not _drag_handle_side.is_empty():
			_drag_handle_by_screen_delta(event.relative)
			_push_flattened()
			_overlay.queue_redraw()
			return
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


func _on_overlay_draw() -> void:
	if not is_active() or not is_instance_valid(_editing_object):
		return
	_draw_curve_segments()
	_draw_handles()


func _load_ctrl_mesh() -> void:
	_ctrl_outer = _editing_object.outer.duplicate()
	_ctrl_holes.clear()
	for h: LDPolygon in _editing_object.holes:
		_ctrl_holes.append(h.duplicate())


func _push_flattened() -> void:
	if not is_instance_valid(_editing_object):
		return
	var new_holes: Array[LDPolygon] = []
	for h: LDPolygon in _ctrl_holes:
		new_holes.append(h.duplicate())
	_editing_object.apply_segments(_ctrl_outer.duplicate(), new_holes)


func _push_flattened_safe() -> void:
	if not is_instance_valid(_editing_object):
		return
	var flat_outer: PackedVector2Array = _ctrl_outer.to_flat()
	var safe_holes: Array[LDPolygon] = []
	for h: LDPolygon in _ctrl_holes:
		var fh: PackedVector2Array = h.to_flat()
		if fh.size() < 3:
			continue
		var hole_ok: bool = true
		for p: Vector2 in fh:
			if not Geometry2D.is_point_in_polygon(p, flat_outer):
				hole_ok = false
				break
		if hole_ok:
			safe_holes.append(h.duplicate())
	_editing_object.apply_segments(_ctrl_outer.duplicate(), safe_holes)


func _toggle_curve(flat_index: int) -> void:
	if flat_index >= _point_sources.size():
		return
	var seg: LDSegment = _segment_for_flat(flat_index)
	if seg == null:
		return
	if seg.is_curve:
		seg.is_curve = false
		seg.handle_out = Vector2.ZERO
		seg.handle_in = Vector2.ZERO
	else:
		seg.is_curve = true
		var ring: LDPolygon = _ring_for_flat(flat_index)
		var local_idx: int = _flat_to_local_idx(flat_index)
		var angle: float = LDCurveUtil.auto_tangent_angle(ring.segments, local_idx)
		var handle: LDCurveHandle = LDCurveHandle.from_tangent(angle)
		seg.handle_out = handle.out_offset
		seg.handle_in = handle.in_offset


func _ring_for_flat(flat_index: int) -> LDPolygon:
	if _point_sources[flat_index] == PointSource.OUTER:
		return _ctrl_outer
	return _ctrl_holes[_point_hole_indices[flat_index]]


func _segment_for_flat(flat_index: int) -> LDSegment:
	var ring: LDPolygon = _ring_for_flat(flat_index)
	var local_idx: int = _flat_to_local_idx(flat_index)
	if local_idx < ring.segments.size():
		return ring.segments[local_idx]
	return null


func _flat_to_local_idx(flat_index: int) -> int:
	if _point_sources[flat_index] == PointSource.OUTER:
		return flat_index
	var hi: int = _point_hole_indices[flat_index]
	var local_idx: int = 0
	for i: int in flat_index:
		if _point_sources[i] == PointSource.HOLE and _point_hole_indices[i] == hi:
			local_idx += 1
	return local_idx


func _hit_test_handles(screen_pos: Vector2) -> Dictionary:
	if not is_instance_valid(_editing_object):
		return {"hit": false}
	var xform: Transform2D = _editing_object.get_global_transform()
	for i: int in _ctrl_outer.segments.size():
		var seg: LDSegment = _ctrl_outer.segments[i]
		if not seg.is_curve:
			continue
		if screen_pos.distance_to(_world_to_screen(xform * (seg.point + seg.handle_in))) < HANDLE_HIT_RADIUS:
			return {"hit": true, "source": PointSource.OUTER, "hi": -1, "idx": i, "side": "in"}
		if screen_pos.distance_to(_world_to_screen(xform * (seg.point + seg.handle_out))) < HANDLE_HIT_RADIUS:
			return {"hit": true, "source": PointSource.OUTER, "hi": -1, "idx": i, "side": "out"}
	for hi: int in _ctrl_holes.size():
		for i: int in _ctrl_holes[hi].segments.size():
			var seg: LDSegment = _ctrl_holes[hi].segments[i]
			if not seg.is_curve:
				continue
			if screen_pos.distance_to(_world_to_screen(xform * (seg.point + seg.handle_in))) < HANDLE_HIT_RADIUS:
				return {"hit": true, "source": PointSource.HOLE, "hi": hi, "idx": i, "side": "in"}
			if screen_pos.distance_to(_world_to_screen(xform * (seg.point + seg.handle_out))) < HANDLE_HIT_RADIUS:
				return {"hit": true, "source": PointSource.HOLE, "hi": hi, "idx": i, "side": "out"}
	return {"hit": false}


func _drag_handle_by_screen_delta(screen_delta: Vector2) -> void:
	if _drag_handle_idx < 0:
		return
	var xform: Transform2D = _editing_object.get_global_transform()
	var local_delta: Vector2 = screen_delta / (xform.get_scale() * viewport.get_viewport().get_canvas_transform().get_scale())
	var ring: LDPolygon = _ctrl_outer if _drag_handle_source == PointSource.OUTER else _ctrl_holes[_drag_handle_hi]
	if _drag_handle_idx >= ring.segments.size():
		return
	var seg: LDSegment = ring.segments[_drag_handle_idx]
	if not seg.is_curve:
		return
	var tmp: LDCurveHandle = LDCurveHandle.new(seg.handle_in, seg.handle_out)
	if _drag_handle_side == "in":
		tmp.move_in(local_delta)
	else:
		tmp.move_out(local_delta)
	seg.handle_in = tmp.in_offset
	seg.handle_out = tmp.out_offset


func _draw_curve_segments() -> void:
	var xform: Transform2D = _editing_object.get_global_transform()
	_draw_ring_curves(_ctrl_outer, xform)
	for hi: int in _ctrl_holes.size():
		_draw_ring_curves(_ctrl_holes[hi], xform)


func _draw_ring_curves(ring: LDPolygon, xform: Transform2D) -> void:
	var count: int = ring.segments.size()
	for i: int in count:
		var ni: int = (i + 1) % count
		var seg: LDSegment = ring.segments[i]
		var next_seg: LDSegment = ring.segments[ni]
		if not seg.is_curve and not next_seg.is_curve:
			continue
		var p0: Vector2 = _world_to_screen(xform * seg.point)
		var p3: Vector2 = _world_to_screen(xform * next_seg.point)
		var p1: Vector2 = _world_to_screen(xform * (seg.point + seg.handle_out))
		var p2: Vector2 = _world_to_screen(xform * (next_seg.point + next_seg.handle_in))
		var prev_pt: Vector2 = p0
		for s: int in range(1, BEZIER_STEPS + 1):
			var t: float = float(s) / float(BEZIER_STEPS)
			var curr_pt: Vector2 = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
			_overlay.draw_line(prev_pt, curr_pt, Color(0.3, 0.8, 1.0, 0.9), 1.5)
			prev_pt = curr_pt


func _draw_handles() -> void:
	var xform: Transform2D = _editing_object.get_global_transform()
	_draw_ring_handle_knobs(_ctrl_outer, xform)
	for hi: int in _ctrl_holes.size():
		_draw_ring_handle_knobs(_ctrl_holes[hi], xform)


func _draw_ring_handle_knobs(ring: LDPolygon, xform: Transform2D) -> void:
	for i: int in ring.segments.size():
		var seg: LDSegment = ring.segments[i]
		if not seg.is_curve:
			continue
		var v: Vector2 = _world_to_screen(xform * seg.point)
		var in_s: Vector2 = _world_to_screen(xform * (seg.point + seg.handle_in))
		var out_s: Vector2 = _world_to_screen(xform * (seg.point + seg.handle_out))
		_overlay.draw_line(v, in_s, Color(1.0, 0.85, 0.2, 0.8), 1.0)
		_overlay.draw_line(v, out_s, Color(1.0, 0.85, 0.2, 0.8), 1.0)
		_overlay.draw_circle(in_s, HANDLE_KNOB_RADIUS, Color(1.0, 0.85, 0.2, 1.0))
		_overlay.draw_circle(out_s, HANDLE_KNOB_RADIUS, Color(1.0, 0.85, 0.2, 1.0))


func _get_all_display_points() -> PackedVector2Array:
	if not _editing_object:
		return PackedVector2Array()
	var result: PackedVector2Array = PackedVector2Array()
	_point_sources.clear()
	_point_hole_indices.clear()
	for seg: LDSegment in _ctrl_outer.segments:
		result.append(seg.point)
		_point_sources.append(PointSource.OUTER)
		_point_hole_indices.append(-1)
	for hi: int in _ctrl_holes.size():
		for seg: LDSegment in _ctrl_holes[hi].segments:
			result.append(seg.point)
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
	var screen_pos: Vector2 = _get_screen_mouse_pos()
	if _hit_test_handles(screen_pos).get("hit", false):
		set_cursor_shape(Control.CURSOR_POINTING_HAND)
		return
	var all_points: PackedVector2Array = _get_all_display_points()
	for i: int in all_points.size():
		if _world_to_screen(global_xform * all_points[i]).distance_to(screen_pos) <= POINT_GRAB_RADIUS:
			_hovered_point_index = i
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	for i: int in _ctrl_outer.segments.size():
		var ni: int = (i + 1) % _ctrl_outer.segments.size()
		if _point_near_curve_edge(screen_pos, _ctrl_outer, i, ni, global_xform, POINT_GRAB_RADIUS):
			_hovered_edge_index = i
			_hovered_edge_is_hole = false
			_hovered_edge_hole_idx = -1
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	for hi: int in _ctrl_holes.size():
		for i: int in _ctrl_holes[hi].segments.size():
			var ni: int = (i + 1) % _ctrl_holes[hi].segments.size()
			if _point_near_curve_edge(screen_pos, _ctrl_holes[hi], i, ni, global_xform, POINT_GRAB_RADIUS):
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
	_drag_start_outer = _ctrl_outer.duplicate()
	_drag_start_holes.clear()
	for h: LDPolygon in _ctrl_holes:
		_drag_start_holes.append(h.duplicate())
	set_cursor_shape(Control.CURSOR_DRAG)


func _drag_point(pos: Vector2) -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	if _dragging_point_index >= _point_sources.size():
		return
	var local_pos: Vector2 = _editing_object.to_local(pos)
	var seg: LDSegment = _segment_for_flat(_dragging_point_index)
	if seg == null:
		return
	if _point_sources[_dragging_point_index] == PointSource.OUTER:
		seg.point = local_pos
	else:
		if not Geometry2D.is_point_in_polygon(local_pos, _ctrl_outer.to_flat()):
			return
		seg.point = local_pos
	_push_flattened_safe()
	_sync_vertex_buttons()
	_overlay.queue_redraw()


func _end_drag_point() -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	var new_outer: LDPolygon = _ctrl_outer.duplicate()
	var new_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
	var old_outer: LDPolygon = _drag_start_outer.duplicate()
	var old_holes: Array[LDPolygon] = _dup_holes(_drag_start_holes)
	var obj: LDObjectPolygon = _editing_object
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.apply_segments(new_outer.duplicate(), _dup_holes(new_holes))
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.apply_segments(old_outer.duplicate(), _dup_holes(old_holes))
	)
	history.commit_action()
	_dragging_point_index = -1
	set_cursor_shape(Control.CURSOR_ARROW)


func _delete_point(index: int) -> void:
	if not _editing_object or index >= _point_sources.size():
		return
	var obj: LDObjectPolygon = _editing_object
	if _point_sources[index] == PointSource.OUTER:
		if _ctrl_outer.segments.size() <= 3:
			return
		var old_outer: LDPolygon = _ctrl_outer.duplicate()
		var old_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
		_ctrl_outer.segments.remove_at(index)
		var new_outer: LDPolygon = _ctrl_outer.duplicate()
		var new_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Delete Polygon Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.apply_segments(new_outer.duplicate(), _dup_holes(new_holes))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.apply_segments(old_outer.duplicate(), _dup_holes(old_holes))
		)
		history.commit_action()
	else:
		var hole_idx: int = _point_hole_indices[index]
		var local_idx: int = _flat_to_local_idx(index)
		var old_outer: LDPolygon = _ctrl_outer.duplicate()
		var old_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
		var history: LDHistoryHandler = LD.get_history_handler()
		if _ctrl_holes[hole_idx].segments.size() <= 3:
			_ctrl_holes.remove_at(hole_idx)
			var new_outer: LDPolygon = _ctrl_outer.duplicate()
			var new_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
			history.begin_action("Remove Hole")
			history.add_do(func() -> void:
				if is_instance_valid(obj):
					obj.apply_segments(new_outer.duplicate(), _dup_holes(new_holes))
			)
			history.add_undo(func() -> void:
				if is_instance_valid(obj):
					obj.apply_segments(old_outer.duplicate(), _dup_holes(old_holes))
			)
			history.commit_action()
			_hovered_point_index = -1
			_push_flattened()
			_rebuild_vertex_buttons()
			return
		_ctrl_holes[hole_idx].segments.remove_at(local_idx)
		var new_outer: LDPolygon = _ctrl_outer.duplicate()
		var new_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
		history.begin_action("Delete Hole Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.apply_segments(new_outer.duplicate(), _dup_holes(new_holes))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.apply_segments(old_outer.duplicate(), _dup_holes(old_holes))
		)
		history.commit_action()
	_push_flattened()
	_hovered_point_index = -1
	_rebuild_vertex_buttons()


func _insert_point_on_edge(edge_index: int, is_hole: bool, hole_idx: int, pos: Vector2) -> void:
	if not _editing_object:
		return
	var obj: LDObjectPolygon = _editing_object
	var old_outer: LDPolygon = _ctrl_outer.duplicate()
	var old_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
	var ring: LDPolygon = _ctrl_outer if not is_hole else _ctrl_holes[hole_idx]
	var count: int = ring.segments.size()
	var ni: int = (edge_index + 1) % count
	var seg_curr: LDSegment = ring.segments[edge_index]
	var seg_next: LDSegment = ring.segments[ni]
	var raw_local: Vector2 = _editing_object.to_local(pos)
	var local_pos: Vector2
	if seg_curr.is_curve:
		var p0: Vector2 = seg_curr.point
		var p3: Vector2 = seg_next.point
		var p1: Vector2 = p0 + seg_curr.handle_out
		var p2: Vector2 = p3 + seg_next.handle_in
		var t: float = LDCurveUtil.closest_t_on_segment(p0, p1, p2, p3, raw_local)
		local_pos = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
	else:
		local_pos = raw_local
	for existing_seg: LDSegment in ring.segments:
		if existing_seg.point.distance_to(local_pos) < POINT_GRAB_RADIUS:
			return
	ring.segments.insert(edge_index + 1, LDSegment.new(local_pos))
	var new_outer: LDPolygon = _ctrl_outer.duplicate()
	var new_holes: Array[LDPolygon] = _dup_holes(_ctrl_holes)
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Insert Hole Point" if is_hole else "Insert Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.apply_segments(new_outer.duplicate(), _dup_holes(new_holes))
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.apply_segments(old_outer.duplicate(), _dup_holes(old_holes))
	)
	history.commit_action()
	_push_flattened()
	_rebuild_vertex_buttons()
	if not is_hole:
		_begin_drag_point(edge_index + 1)
	else:
		var inserted_global_idx: int = _ctrl_outer.segments.size()
		for i: int in hole_idx:
			inserted_global_idx += _ctrl_holes[i].segments.size()
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
		btn.position = _world_to_screen(global_xform * all_points[i]) - Vector2(half, half)
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
		_vertex_buttons[i].position = _world_to_screen(global_xform * all_points[i]) - Vector2(half, half)


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
	var ring: LDPolygon
	if _hovered_edge_is_hole:
		if _hovered_edge_hole_idx >= _ctrl_holes.size():
			_edge_preview_button.visible = false
			return
		ring = _ctrl_holes[_hovered_edge_hole_idx]
	else:
		ring = _ctrl_outer
	var i: int = _hovered_edge_index
	var ni: int = (i + 1) % ring.segments.size()
	var seg_curr: LDSegment = ring.segments[i]
	var seg_next: LDSegment = ring.segments[ni]
	var local_mouse: Vector2 = _editing_object.to_local(_get_world_mouse_pos())
	var preview_local: Vector2
	if seg_curr.is_curve:
		var p0: Vector2 = seg_curr.point
		var p3: Vector2 = seg_next.point
		var p1: Vector2 = p0 + seg_curr.handle_out
		var p2: Vector2 = p3 + seg_next.handle_in
		var t: float = LDCurveUtil.closest_t_on_segment(p0, p1, p2, p3, local_mouse)
		preview_local = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
	else:
		var a: Vector2 = seg_curr.point
		var b: Vector2 = seg_next.point
		var ab: Vector2 = b - a
		var t: float = clampf((local_mouse - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
		preview_local = a + t * ab
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	_edge_preview_button.position = _world_to_screen(global_xform * preview_local) - Vector2(half, half)
	_edge_preview_button.visible = true


func _dup_holes(src: Array[LDPolygon]) -> Array[LDPolygon]:
	var result: Array[LDPolygon] = []
	for h: LDPolygon in src:
		result.append(h.duplicate())
	return result


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
		_ctrl_outer = LDPolygon.new()
		_ctrl_holes.clear()
		_load_ctrl_mesh()
		_rebuild_vertex_buttons()
		_create_edge_preview_button()
	else:
		_editing_object = null
		_clear_vertex_buttons()
		_destroy_edge_preview_button()
		get_tool_handler().select_tool("select")


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if not is_active():
		return
	_sync_vertex_buttons()
	_sync_edge_preview_button()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _point_near_curve_edge(screen_pos: Vector2, ring: LDPolygon, i: int, ni: int, xform: Transform2D, threshold: float) -> bool:
	var seg: LDSegment = ring.segments[i]
	var next_seg: LDSegment = ring.segments[ni]
	if not seg.is_curve:
		var a: Vector2 = _world_to_screen(xform * seg.point)
		var b: Vector2 = _world_to_screen(xform * next_seg.point)
		return _point_near_segment(screen_pos, a, b, threshold)
	var p0: Vector2 = seg.point
	var p3: Vector2 = next_seg.point
	var p1: Vector2 = p0 + seg.handle_out
	var p2: Vector2 = p3 + next_seg.handle_in
	for s: int in range(BEZIER_STEPS + 1):
		var t: float = float(s) / float(BEZIER_STEPS)
		var pt: Vector2 = _world_to_screen(xform * LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t))
		if screen_pos.distance_to(pt) <= threshold:
			return true
	return false


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
	return viewport.get_root().get_local_mouse_position()
