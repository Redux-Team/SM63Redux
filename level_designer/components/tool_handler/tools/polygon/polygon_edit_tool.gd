extends LDTool

enum PointSource { OUTER, HOLE }

const DOUBLE_CLICK_SEC: float = 0.4
const POINT_GRAB_RADIUS: float = 18.0
const VERTEX_BUTTON_SIZE: float = 12.0
const BEZIER_STEPS: int = 12
const HANDLE_KNOB_RADIUS: float = 5.0
const HANDLE_HIT_RADIUS: float = 10.0
const META_KEY: StringName = &"curve_handles"

var _editing_object: LDObjectPolygon
var _dragging_point_index: int = -1
var _drag_start_outer: PackedVector2Array
var _drag_start_holes: Array[PackedVector2Array]
var _drag_start_meta: Dictionary
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

var _handles: Dictionary = {}
var _ctrl_outer: PackedVector2Array = PackedVector2Array()
var _ctrl_holes: Array[PackedVector2Array] = []
var _dragging_handle_key: String = ""
var _dragging_handle_side: String = ""
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
	if is_instance_valid(_editing_object):
		_save_meta()
	_handles.clear()
	_ctrl_outer = PackedVector2Array()
	_ctrl_holes.clear()
	_dragging_handle_key = ""
	_dragging_handle_side = ""
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
		_toggle_handle(_hovered_point_index)
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
			if not _dragging_handle_key.is_empty():
				return
			var hit: Dictionary = _hit_test_handles(_get_screen_mouse_pos())
			if hit.get("hit", false):
				_dragging_handle_key = hit["key"]
				_dragging_handle_side = hit["side"]
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
			if not _dragging_handle_key.is_empty():
				_dragging_handle_key = ""
				_dragging_handle_side = ""
				return
			if _dragging_point_index >= 0:
				_end_drag_point()
			_pending_polygon_drag = false
	
	if event is InputEventMouseMotion:
		if not _dragging_handle_key.is_empty():
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


# ---- meta persistence ----

func _snapshot_meta() -> Dictionary:
	var data: Dictionary = {
		"ctrl_outer": _ctrl_outer.duplicate(),
		"hole_count": _ctrl_holes.size(),
	}
	for hi: int in _ctrl_holes.size():
		data["ctrl_hole_" + str(hi)] = _ctrl_holes[hi].duplicate()
	for key: String in _handles.keys():
		var h: LDCurveHandle = _handles[key] as LDCurveHandle
		data["hk_" + key] = [h.in_offset.x, h.in_offset.y, h.out_offset.x, h.out_offset.y]
	return data


func _apply_meta_snapshot(snap: Dictionary) -> void:
	_ctrl_outer = (snap["ctrl_outer"] as PackedVector2Array).duplicate()
	_ctrl_holes.clear()
	var hole_count: int = int(snap.get("hole_count", 0))
	for hi: int in hole_count:
		_ctrl_holes.append((snap["ctrl_hole_" + str(hi)] as PackedVector2Array).duplicate())
	_handles.clear()
	for key: String in snap.keys():
		if not key.begins_with("hk_"):
			continue
		var handle_key: String = key.substr(3)
		var arr: Array = snap[key] as Array
		if arr.size() == 4:
			_handles[handle_key] = LDCurveHandle.new(
				Vector2(float(arr[0]), float(arr[1])),
				Vector2(float(arr[2]), float(arr[3]))
			)


func _save_meta() -> void:
	var data: Dictionary = {
		"ctrl_outer": _ctrl_outer,
		"hole_count": _ctrl_holes.size(),
	}
	for hi: int in _ctrl_holes.size():
		data["ctrl_hole_" + str(hi)] = _ctrl_holes[hi]
	for key: String in _handles.keys():
		var h: LDCurveHandle = _handles[key] as LDCurveHandle
		data["hk_" + key] = [h.in_offset.x, h.in_offset.y, h.out_offset.x, h.out_offset.y]
	_editing_object.set_meta(META_KEY, data)


func _load_ctrl_mesh() -> void:
	_handles.clear()
	_ctrl_outer = PackedVector2Array()
	_ctrl_holes.clear()
	
	if _editing_object.has_meta(META_KEY):
		var data: Dictionary = _editing_object.get_meta(META_KEY) as Dictionary
		var raw_outer: Variant = data.get("ctrl_outer")
		var saved_outer: PackedVector2Array = PackedVector2Array(raw_outer) if raw_outer != null else PackedVector2Array()
		var saved_hole_count: int = int(data.get("hole_count", 0))
		
		if saved_outer.size() >= 3 and saved_hole_count == _editing_object.get_hole_count():
			var holes_valid: bool = true
			for hi: int in saved_hole_count:
				var raw_hole: Variant = data.get("ctrl_hole_" + str(hi))
				var hole_pts: PackedVector2Array = PackedVector2Array(raw_hole) if raw_hole != null else PackedVector2Array()
				if hole_pts.size() < 3:
					holes_valid = false
					break
				_ctrl_holes.append(hole_pts)
			
			if holes_valid:
				_ctrl_outer = saved_outer
				for key: String in data.keys():
					if not key.begins_with("hk_"):
						continue
					var handle_key: String = key.substr(3)
					var arr: Array = data[key] as Array
					if arr.size() == 4:
						_handles[handle_key] = LDCurveHandle.new(
							Vector2(float(arr[0]), float(arr[1])),
							Vector2(float(arr[2]), float(arr[3]))
						)
				return
			
			_ctrl_holes.clear()
	
	_ctrl_outer = _editing_object.get_outer_points().duplicate()
	for hi: int in _editing_object.get_hole_count():
		_ctrl_holes.append(_editing_object.get_hole(hi).duplicate())
	_save_meta()


func _push_flattened() -> void:
	if not is_instance_valid(_editing_object):
		return
	var flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
	var flat_holes: Array[PackedVector2Array] = []
	for hi: int in _ctrl_holes.size():
		flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS))
	_editing_object.apply_points_raw(flat_outer, flat_holes)


func _push_flattened_safe() -> void:
	if not is_instance_valid(_editing_object):
		return
	var flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
	var flat_holes: Array[PackedVector2Array] = []
	for hi: int in _ctrl_holes.size():
		var flat_hole: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS)
		if flat_hole.size() < 3:
			continue
		var hole_ok: bool = true
		for p: Vector2 in flat_hole:
			if not Geometry2D.is_point_in_polygon(p, flat_outer):
				hole_ok = false
				break
		if hole_ok:
			flat_holes.append(flat_hole)
	_editing_object.apply_points_raw(flat_outer, flat_holes)


# ---- handle toggle ----

func _toggle_handle(flat_index: int) -> void:
	if flat_index >= _point_sources.size():
		return
	var key: String = _handle_key_for_flat(flat_index)
	if _handles.has(key):
		_handles.erase(key)
		return
	var ring: PackedVector2Array
	var local_idx: int
	var ring_handles: Dictionary
	if _point_sources[flat_index] == PointSource.OUTER:
		ring = _ctrl_outer
		local_idx = flat_index
		ring_handles = _outer_handles()
	else:
		var hi: int = _point_hole_indices[flat_index]
		ring = _ctrl_holes[hi]
		local_idx = _flat_to_local_idx(flat_index)
		ring_handles = _hole_handles(hi)
	var angle: float = LDCurveUtil.auto_tangent_angle(ring, local_idx, ring_handles)
	_handles[key] = LDCurveHandle.from_tangent(angle)


# ---- key helpers ----

func _handle_key_for_flat(flat_index: int) -> String:
	if _point_sources[flat_index] == PointSource.OUTER:
		return "o:" + str(flat_index)
	var hi: int = _point_hole_indices[flat_index]
	return "h:" + str(hi) + ":" + str(_flat_to_local_idx(flat_index))


func _outer_key(index: int) -> String:
	return "o:" + str(index)


func _hole_key(hi: int, index: int) -> String:
	return "h:" + str(hi) + ":" + str(index)


func _outer_handles() -> Dictionary:
	var result: Dictionary = {}
	for i: int in _ctrl_outer.size():
		var h: LDCurveHandle = _handles.get(_outer_key(i)) as LDCurveHandle
		if h:
			result[i] = h
	return result


func _hole_handles(hi: int) -> Dictionary:
	var result: Dictionary = {}
	if hi >= _ctrl_holes.size():
		return result
	for i: int in _ctrl_holes[hi].size():
		var h: LDCurveHandle = _handles.get(_hole_key(hi, i)) as LDCurveHandle
		if h:
			result[i] = h
	return result


func _flat_to_local_idx(flat_index: int) -> int:
	if _point_sources[flat_index] == PointSource.OUTER:
		return flat_index
	var hi: int = _point_hole_indices[flat_index]
	var local_idx: int = 0
	for i: int in flat_index:
		if _point_sources[i] == PointSource.HOLE and _point_hole_indices[i] == hi:
			local_idx += 1
	return local_idx


# ---- handle hit test and drag ----

func _hit_test_handles(screen_pos: Vector2) -> Dictionary:
	if not is_instance_valid(_editing_object):
		return {"hit": false}
	var xform: Transform2D = _editing_object.get_global_transform()
	for i: int in _ctrl_outer.size():
		var h: LDCurveHandle = _handles.get(_outer_key(i)) as LDCurveHandle
		if not h:
			continue
		if screen_pos.distance_to(_world_to_screen(xform * (_ctrl_outer[i] + h.in_offset))) < HANDLE_HIT_RADIUS:
			return {"hit": true, "key": _outer_key(i), "side": "in"}
		if screen_pos.distance_to(_world_to_screen(xform * (_ctrl_outer[i] + h.out_offset))) < HANDLE_HIT_RADIUS:
			return {"hit": true, "key": _outer_key(i), "side": "out"}
	for hi: int in _ctrl_holes.size():
		for i: int in _ctrl_holes[hi].size():
			var h: LDCurveHandle = _handles.get(_hole_key(hi, i)) as LDCurveHandle
			if not h:
				continue
			if screen_pos.distance_to(_world_to_screen(xform * (_ctrl_holes[hi][i] + h.in_offset))) < HANDLE_HIT_RADIUS:
				return {"hit": true, "key": _hole_key(hi, i), "side": "in"}
			if screen_pos.distance_to(_world_to_screen(xform * (_ctrl_holes[hi][i] + h.out_offset))) < HANDLE_HIT_RADIUS:
				return {"hit": true, "key": _hole_key(hi, i), "side": "out"}
	return {"hit": false}


func _drag_handle_by_screen_delta(screen_delta: Vector2) -> void:
	var h: LDCurveHandle = _handles.get(_dragging_handle_key) as LDCurveHandle
	if not h:
		return
	var xform: Transform2D = _editing_object.get_global_transform()
	var local_delta: Vector2 = screen_delta / (xform.get_scale() * viewport.get_viewport().get_canvas_transform().get_scale())
	if _dragging_handle_side == "in":
		h.move_in(local_delta)
	else:
		h.move_out(local_delta)


# ---- draw ----

func _draw_curve_segments() -> void:
	var xform: Transform2D = _editing_object.get_global_transform()
	_draw_ring_curves(_ctrl_outer, _outer_handles(), xform)
	for hi: int in _ctrl_holes.size():
		_draw_ring_curves(_ctrl_holes[hi], _hole_handles(hi), xform)


func _draw_ring_curves(ring: PackedVector2Array, ring_handles: Dictionary, xform: Transform2D) -> void:
	var count: int = ring.size()
	for i: int in count:
		var ni: int = (i + 1) % count
		var h_curr: LDCurveHandle = ring_handles.get(i) as LDCurveHandle
		var h_next: LDCurveHandle = ring_handles.get(ni) as LDCurveHandle
		if h_curr == null and h_next == null:
			continue
		var p0: Vector2 = _world_to_screen(xform * ring[i])
		var p3: Vector2 = _world_to_screen(xform * ring[ni])
		var p1: Vector2 = _world_to_screen(xform * (ring[i] + (h_curr.out_offset if h_curr else Vector2.ZERO)))
		var p2: Vector2 = _world_to_screen(xform * (ring[ni] + (h_next.in_offset if h_next else Vector2.ZERO)))
		var prev_pt: Vector2 = p0
		for s: int in range(1, BEZIER_STEPS + 1):
			var t: float = float(s) / float(BEZIER_STEPS)
			var curr_pt: Vector2 = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
			_overlay.draw_line(prev_pt, curr_pt, Color(0.3, 0.8, 1.0, 0.9), 1.5)
			prev_pt = curr_pt


func _draw_handles() -> void:
	var xform: Transform2D = _editing_object.get_global_transform()
	_draw_ring_handle_knobs(_ctrl_outer, _outer_handles(), xform)
	for hi: int in _ctrl_holes.size():
		_draw_ring_handle_knobs(_ctrl_holes[hi], _hole_handles(hi), xform)


func _draw_ring_handle_knobs(ring: PackedVector2Array, ring_handles: Dictionary, xform: Transform2D) -> void:
	for i: int in ring.size():
		var h: LDCurveHandle = ring_handles.get(i) as LDCurveHandle
		if not h:
			continue
		var v: Vector2 = _world_to_screen(xform * ring[i])
		var in_s: Vector2 = _world_to_screen(xform * (ring[i] + h.in_offset))
		var out_s: Vector2 = _world_to_screen(xform * (ring[i] + h.out_offset))
		_overlay.draw_line(v, in_s, Color(1.0, 0.85, 0.2, 0.8), 1.0)
		_overlay.draw_line(v, out_s, Color(1.0, 0.85, 0.2, 0.8), 1.0)
		_overlay.draw_circle(in_s, HANDLE_KNOB_RADIUS, Color(1.0, 0.85, 0.2, 1.0))
		_overlay.draw_circle(out_s, HANDLE_KNOB_RADIUS, Color(1.0, 0.85, 0.2, 1.0))


# ---- remap handles ----

func _remap_handles_after_insert(source: PointSource, hi: int, inserted_local_idx: int) -> void:
	var new_handles: Dictionary = {}
	for key: String in _handles.keys():
		var h: LDCurveHandle = _handles[key] as LDCurveHandle
		if source == PointSource.OUTER and key.begins_with("o:"):
			var idx: int = int(key.substr(2))
			new_handles["o:" + str(idx + 1 if idx >= inserted_local_idx else idx)] = h
		elif source == PointSource.HOLE and key.begins_with("h:" + str(hi) + ":"):
			var prefix: String = "h:" + str(hi) + ":"
			var idx: int = int(key.substr(prefix.length()))
			new_handles[prefix + str(idx + 1 if idx >= inserted_local_idx else idx)] = h
		else:
			new_handles[key] = h
	_handles = new_handles


func _remap_handles_after_delete(source: PointSource, hi: int, deleted_local_idx: int) -> void:
	var new_handles: Dictionary = {}
	for key: String in _handles.keys():
		var h: LDCurveHandle = _handles[key] as LDCurveHandle
		if source == PointSource.OUTER and key.begins_with("o:"):
			var idx: int = int(key.substr(2))
			if idx == deleted_local_idx:
				continue
			new_handles["o:" + str(idx - 1 if idx > deleted_local_idx else idx)] = h
		elif source == PointSource.HOLE and key.begins_with("h:" + str(hi) + ":"):
			var prefix: String = "h:" + str(hi) + ":"
			var idx: int = int(key.substr(prefix.length()))
			if idx == deleted_local_idx:
				continue
			new_handles[prefix + str(idx - 1 if idx > deleted_local_idx else idx)] = h
		else:
			new_handles[key] = h
	_handles = new_handles


# ---- display points ----

func _get_all_display_points() -> PackedVector2Array:
	if not _editing_object:
		return PackedVector2Array()
	var result: PackedVector2Array = PackedVector2Array()
	_point_sources.clear()
	_point_hole_indices.clear()
	for p: Vector2 in _ctrl_outer:
		result.append(p)
		_point_sources.append(PointSource.OUTER)
		_point_hole_indices.append(-1)
	for hi: int in _ctrl_holes.size():
		for p: Vector2 in _ctrl_holes[hi]:
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
	
	var outer_handles: Dictionary = _outer_handles()
	for i: int in _ctrl_outer.size():
		var ni: int = (i + 1) % _ctrl_outer.size()
		if _point_near_curve_edge(screen_pos, _ctrl_outer, i, ni, outer_handles, global_xform, POINT_GRAB_RADIUS):
			_hovered_edge_index = i
			_hovered_edge_is_hole = false
			_hovered_edge_hole_idx = -1
			set_cursor_shape(Control.CURSOR_POINTING_HAND)
			_sync_vertex_button_states()
			_sync_edge_preview_button()
			return
	
	for hi: int in _ctrl_holes.size():
		var hole_handles: Dictionary = _hole_handles(hi)
		for i: int in _ctrl_holes[hi].size():
			var ni: int = (i + 1) % _ctrl_holes[hi].size()
			if _point_near_curve_edge(screen_pos, _ctrl_holes[hi], i, ni, hole_handles, global_xform, POINT_GRAB_RADIUS):
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


# ---- drag point ----

func _begin_drag_point(index: int) -> void:
	_dragging_point_index = index
	_drag_start_outer = _ctrl_outer.duplicate()
	_drag_start_holes.clear()
	for hi: int in _ctrl_holes.size():
		_drag_start_holes.append(_ctrl_holes[hi].duplicate())
	_drag_start_meta = _snapshot_meta()
	set_cursor_shape(Control.CURSOR_DRAG)


func _drag_point(pos: Vector2) -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	if _dragging_point_index >= _point_sources.size():
		return
	var local_pos: Vector2 = _editing_object.to_local(pos)
	if _point_sources[_dragging_point_index] == PointSource.OUTER:
		_ctrl_outer[_dragging_point_index] = local_pos
	else:
		var hole_idx: int = _point_hole_indices[_dragging_point_index]
		if not Geometry2D.is_point_in_polygon(local_pos, _ctrl_outer):
			return
		_ctrl_holes[hole_idx][_flat_to_local_idx(_dragging_point_index)] = local_pos
	_push_flattened_safe()
	_sync_vertex_buttons()
	_overlay.queue_redraw()


func _end_drag_point() -> void:
	if not _editing_object or _dragging_point_index < 0:
		return
	var new_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
	var new_flat_holes: Array[PackedVector2Array] = []
	for hi: int in _ctrl_holes.size():
		new_flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS))
	var old_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_drag_start_outer, _outer_handles(), BEZIER_STEPS)
	var old_flat_holes: Array[PackedVector2Array] = []
	for hi: int in _drag_start_holes.size():
		old_flat_holes.append(LDCurveUtil.flatten_ring(_drag_start_holes[hi], _hole_handles(hi), BEZIER_STEPS))
	var new_meta: Dictionary = _snapshot_meta()
	var old_meta: Dictionary = _drag_start_meta
	var obj: LDObjectPolygon = _editing_object
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Polygon Point")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.clear_holes()
			obj.apply_points_raw(new_flat_outer, new_flat_holes)
			obj.set_meta(META_KEY, _pack_meta_for_storage(new_meta))
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.clear_holes()
			obj.apply_points_raw(old_flat_outer, old_flat_holes)
			obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
	)
	history.commit_action()
	_dragging_point_index = -1
	set_cursor_shape(Control.CURSOR_ARROW)


# ---- delete / insert ----

func _delete_point(index: int) -> void:
	if not _editing_object or index >= _point_sources.size():
		return
	var obj: LDObjectPolygon = _editing_object
	var old_meta: Dictionary = _snapshot_meta()
	if _point_sources[index] == PointSource.OUTER:
		if _ctrl_outer.size() <= 3:
			return
		_remap_handles_after_delete(PointSource.OUTER, -1, index)
		_ctrl_outer.remove_at(index)
		var new_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
		var old_flat_holes: Array[PackedVector2Array] = []
		for hi: int in _ctrl_holes.size():
			old_flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS))
		var new_meta: Dictionary = _snapshot_meta()
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Delete Polygon Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.apply_points_raw(new_flat_outer, old_flat_holes)
				obj.set_meta(META_KEY, _pack_meta_for_storage(new_meta))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				_apply_meta_snapshot(old_meta)
				_push_flattened()
				obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
		)
		history.commit_action()
	else:
		var hole_idx: int = _point_hole_indices[index]
		var hi: int = hole_idx
		var local_idx: int = _flat_to_local_idx(index)
		if _ctrl_holes[hole_idx].size() <= 3:
			var old_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
			var old_flat_holes: Array[PackedVector2Array] = []
			for h: int in _ctrl_holes.size():
				old_flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[h], _hole_handles(h), BEZIER_STEPS))
			var history: LDHistoryHandler = LD.get_history_handler()
			history.begin_action("Remove Hole")
			history.add_do(func() -> void:
				if is_instance_valid(obj):
					obj.remove_hole(hi)
			)
			history.add_undo(func() -> void:
				if is_instance_valid(obj):
					obj.clear_holes()
					obj.apply_points_raw(old_flat_outer, old_flat_holes)
					obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
			)
			history.commit_action()
			_editing_object.remove_hole(hole_idx)
			_ctrl_holes.remove_at(hole_idx)
			var cleaned: Dictionary = {}
			for key: String in _handles.keys():
				if not key.begins_with("h:" + str(hole_idx) + ":"):
					cleaned[key] = _handles[key]
			_handles = cleaned
			_hovered_point_index = -1
			_push_flattened()
			_rebuild_vertex_buttons()
			return
		_remap_handles_after_delete(PointSource.HOLE, hole_idx, local_idx)
		_ctrl_holes[hole_idx].remove_at(local_idx)
		var new_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
		var new_flat_holes: Array[PackedVector2Array] = []
		for h: int in _ctrl_holes.size():
			new_flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[h], _hole_handles(h), BEZIER_STEPS))
		var new_meta: Dictionary = _snapshot_meta()
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Delete Hole Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.apply_points_raw(new_flat_outer, new_flat_holes)
				obj.set_meta(META_KEY, _pack_meta_for_storage(new_meta))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				_apply_meta_snapshot(old_meta)
				_push_flattened()
				obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
		)
		history.commit_action()
	_push_flattened()
	_hovered_point_index = -1
	_rebuild_vertex_buttons()


func _insert_point_on_edge(edge_index: int, is_hole: bool, hole_idx: int, pos: Vector2) -> void:
	if not _editing_object:
		return
	var obj: LDObjectPolygon = _editing_object
	var old_meta: Dictionary = _snapshot_meta()
	if not is_hole:
		var outer_rh: Dictionary = _outer_handles()
		var h_ci: LDCurveHandle = outer_rh.get(edge_index) as LDCurveHandle
		var h_ni: LDCurveHandle = outer_rh.get((edge_index + 1) % _ctrl_outer.size()) as LDCurveHandle
		var raw_local: Vector2 = _editing_object.to_local(pos)
		var local_pos: Vector2
		if h_ci != null or h_ni != null:
			var p0: Vector2 = _ctrl_outer[edge_index]
			var p3: Vector2 = _ctrl_outer[(edge_index + 1) % _ctrl_outer.size()]
			var p1: Vector2 = p0 + (h_ci.out_offset if h_ci else Vector2.ZERO)
			var p2: Vector2 = p3 + (h_ni.in_offset if h_ni else Vector2.ZERO)
			var t: float = LDCurveUtil.closest_t_on_segment(p0, p1, p2, p3, raw_local)
			local_pos = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
		else:
			local_pos = raw_local
		for existing: Vector2 in _ctrl_outer:
			if existing.distance_to(local_pos) < POINT_GRAB_RADIUS:
				return
		_remap_handles_after_insert(PointSource.OUTER, -1, edge_index + 1)
		_ctrl_outer.insert(edge_index + 1, local_pos)
		var new_flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
		var flat_holes: Array[PackedVector2Array] = []
		for hi: int in _ctrl_holes.size():
			flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS))
		var new_meta: Dictionary = _snapshot_meta()
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Insert Polygon Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.apply_points_raw(new_flat_outer, flat_holes)
				obj.set_meta(META_KEY, _pack_meta_for_storage(new_meta))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				_apply_meta_snapshot(old_meta)
				_push_flattened()
				obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
		)
		history.commit_action()
		_push_flattened()
		_rebuild_vertex_buttons()
		_begin_drag_point(edge_index + 1)
	else:
		if hole_idx >= _ctrl_holes.size():
			return
		var hole_rh: Dictionary = _hole_handles(hole_idx)
		var h_hci: LDCurveHandle = hole_rh.get(edge_index) as LDCurveHandle
		var h_hni: LDCurveHandle = hole_rh.get((edge_index + 1) % _ctrl_holes[hole_idx].size()) as LDCurveHandle
		var world_mouse_h: Vector2 = _editing_object.to_local(pos)
		var local_pos: Vector2
		if h_hci != null or h_hni != null:
			var p0: Vector2 = _ctrl_holes[hole_idx][edge_index]
			var p3: Vector2 = _ctrl_holes[hole_idx][(edge_index + 1) % _ctrl_holes[hole_idx].size()]
			var p1: Vector2 = p0 + (h_hci.out_offset if h_hci else Vector2.ZERO)
			var p2: Vector2 = p3 + (h_hni.in_offset if h_hni else Vector2.ZERO)
			var t: float = LDCurveUtil.closest_t_on_segment(p0, p1, p2, p3, world_mouse_h)
			local_pos = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
		else:
			local_pos = world_mouse_h
		for existing: Vector2 in _ctrl_holes[hole_idx]:
			if existing.distance_to(local_pos) < POINT_GRAB_RADIUS:
				return
		_remap_handles_after_insert(PointSource.HOLE, hole_idx, edge_index + 1)
		_ctrl_holes[hole_idx].insert(edge_index + 1, local_pos)
		var flat_outer: PackedVector2Array = LDCurveUtil.flatten_ring(_ctrl_outer, _outer_handles(), BEZIER_STEPS)
		var new_flat_holes: Array[PackedVector2Array] = []
		for hi: int in _ctrl_holes.size():
			new_flat_holes.append(LDCurveUtil.flatten_ring(_ctrl_holes[hi], _hole_handles(hi), BEZIER_STEPS))
		var new_meta: Dictionary = _snapshot_meta()
		var history: LDHistoryHandler = LD.get_history_handler()
		history.begin_action("Insert Hole Point")
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.clear_holes()
				obj.apply_points_raw(flat_outer, new_flat_holes)
				obj.set_meta(META_KEY, _pack_meta_for_storage(new_meta))
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				_apply_meta_snapshot(old_meta)
				_push_flattened()
				obj.set_meta(META_KEY, _pack_meta_for_storage(old_meta))
		)
		history.commit_action()
		_push_flattened()
		_rebuild_vertex_buttons()
		var inserted_global_idx: int = _ctrl_outer.size()
		for i: int in hole_idx:
			inserted_global_idx += _ctrl_holes[i].size()
		inserted_global_idx += edge_index + 1
		_begin_drag_point(inserted_global_idx)


# ---- meta storage helper ----

func _pack_meta_for_storage(snap: Dictionary) -> Dictionary:
	return snap


# ---- vertex buttons ----

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


# ---- edge preview button ----

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
		if _hovered_edge_hole_idx >= _ctrl_holes.size():
			_edge_preview_button.visible = false
			return
		points = _ctrl_holes[_hovered_edge_hole_idx]
	else:
		points = _ctrl_outer
	var i: int = _hovered_edge_index
	var ni: int = (i + 1) % points.size()
	var rh: Dictionary = _outer_handles() if not _hovered_edge_is_hole else _hole_handles(_hovered_edge_hole_idx)
	var h_curr: LDCurveHandle = rh.get(i) as LDCurveHandle
	var h_next: LDCurveHandle = rh.get(ni) as LDCurveHandle
	var world_mouse: Vector2 = _get_world_mouse_pos()
	var local_mouse: Vector2 = _editing_object.to_local(world_mouse)
	var preview_local: Vector2
	if h_curr != null or h_next != null:
		var p0: Vector2 = points[i]
		var p3: Vector2 = points[ni]
		var p1: Vector2 = p0 + (h_curr.out_offset if h_curr else Vector2.ZERO)
		var p2: Vector2 = p3 + (h_next.in_offset if h_next else Vector2.ZERO)
		var t: float = LDCurveUtil.closest_t_on_segment(p0, p1, p2, p3, local_mouse)
		preview_local = LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t)
	else:
		var a: Vector2 = points[i]
		var b: Vector2 = points[ni]
		var ab: Vector2 = b - a
		var t: float = clampf((local_mouse - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
		preview_local = a + t * ab
	var half: float = VERTEX_BUTTON_SIZE * 0.5
	_edge_preview_button.position = _world_to_screen(global_xform * preview_local) - Vector2(half, half)
	_edge_preview_button.visible = true


# ---- misc ----

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
		if is_instance_valid(_editing_object):
			_save_meta()
		_editing_object = objects[0] as LDObjectPolygon
		_handles.clear()
		_load_ctrl_mesh()
		_rebuild_vertex_buttons()
		_create_edge_preview_button()
	else:
		if is_instance_valid(_editing_object):
			_save_meta()
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


func _point_near_curve_edge(screen_pos: Vector2, ring: PackedVector2Array, i: int, ni: int, ring_handles: Dictionary, xform: Transform2D, threshold: float) -> bool:
	var h_curr: LDCurveHandle = ring_handles.get(i) as LDCurveHandle
	var h_next: LDCurveHandle = ring_handles.get(ni) as LDCurveHandle
	if h_curr == null and h_next == null:
		var a: Vector2 = _world_to_screen(xform * ring[i])
		var b: Vector2 = _world_to_screen(xform * ring[ni])
		return _point_near_segment(screen_pos, a, b, threshold)
	var p0: Vector2 = ring[i]
	var p3: Vector2 = ring[ni]
	var p1: Vector2 = p0 + (h_curr.out_offset if h_curr else Vector2.ZERO)
	var p2: Vector2 = p3 + (h_next.in_offset if h_next else Vector2.ZERO)
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
	return _get_world_mouse_pos().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
