extends LDTool

const POINT_MERGE_DISTANCE: float = 18.0


@export var _widget: LDPolygonWidget


var _editing_object: LDObjectPolygon
var _drag_start_outer: PackedVector2Array = PackedVector2Array()
var _drag_start_holes: Array[PackedVector2Array] = []
var _dragging_point_index: int = -1
var _pending_polygon_drag: bool = false


func get_tool_name() -> String:
	return "PolygonEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func wants_overlay() -> bool:
	return true


func _on_enable() -> void:
	super()
	_editing_object = _get_selected_polygon()
	if not _editing_object:
		get_tool_handler().select_tool("select")
		return
	var objects: Array[LDObject] = [_editing_object]
	_widget.activate(self, objects)


func _on_disable() -> void:
	_finish_drag()
	_widget.deactivate()
	_editing_object = null
	_pending_polygon_drag = false
	super()


func draw_overlay(draw_node: CanvasItem) -> void:
	if is_active():
		_widget.draw_overlay(draw_node)


func _on_overlay_selection_changed(_objects: Array[LDObject]) -> void:
	if not is_active():
		return
	
	_finish_drag()
	_editing_object = _get_selected_polygon()
	if not _editing_object:
		get_tool_handler().select_tool("select")
		return
	
	var objects: Array[LDObject] = [_editing_object]
	_widget.refresh(objects)
	viewport.get_selection_overlay().queue_redraw()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if _widget.should_ignore_input():
		return
	
	if event is InputEventMouseButton:
		_handle_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_motion()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.is_pressed() and not key.echo and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
			_delete_point(_widget.get_hovered_point())


func _handle_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and _widget.can_begin_interaction():
			_delete_point(_widget.get_hovered_point())
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if not event.pressed:
		_finish_drag()
		_pending_polygon_drag = false
		return
	
	if not _widget.can_begin_interaction():
		return
	
	var point: int = _widget.get_hovered_point()
	var edge: int = _widget.get_hovered_edge()
	if point >= 0:
		if _widget.is_double_click(point):
			_delete_point(point)
		else:
			_begin_drag_point(point)
	elif edge >= 0:
		_insert_point_on_edge(edge, _widget.get_hovered_edge_hole())
	elif _widget.is_mouse_inside():
		_pending_polygon_drag = true
	else:
		viewport.clear_selection()
		get_tool_handler().select_tool("select")
		get_tool_handler().get_selected_tool()._on_viewport_input(event)


func _handle_motion() -> void:
	if _pending_polygon_drag:
		_pending_polygon_drag = false
		var move: LDToolMove = get_move_tool()
		if move and move.try_begin_drag(viewport.get_screen_mouse(), [_editing_object]):
			move.return_tool = "polygon_edit"
			get_tool_handler().select_tool("move")
		return
	
	if _dragging_point_index >= 0:
		_drag_point(viewport.get_snapped_mouse(_editing_object))
		return
	
	_widget.update_hover()
	_update_cursor()


func _update_cursor() -> void:
	if _dragging_point_index >= 0:
		set_cursor_shape(Control.CURSOR_DRAG)
	elif _widget.get_hovered_point() >= 0 or _widget.get_hovered_edge() >= 0:
		set_cursor_shape(Control.CURSOR_POINTING_HAND)
	else:
		set_cursor_shape(Control.CURSOR_ARROW)


func _get_selected_polygon() -> LDObjectPolygon:
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() != 1:
		return null
	return selected.front() as LDObjectPolygon


func _begin_drag_point(index: int) -> void:
	_dragging_point_index = index
	_drag_start_outer = _editing_object.get_outer_points().duplicate()
	_drag_start_holes = _editing_object.get_holes().duplicate()
	# Rescattering decorations dominates the cost of every motion event, so they are suppressed
	# until release. Set on the surface directly; _sync_style() would restore the saved property.
	_editing_object.surface.decorations_enabled = false
	_widget.set_pressed_point(index)
	set_cursor_shape(Control.CURSOR_DRAG)


func _drag_point(pos: Vector2) -> void:
	if _dragging_point_index < 0 or _dragging_point_index >= _widget.get_point_count():
		return
	
	var local_pos: Vector2 = world_to_object(_editing_object, pos)
	
	if not _widget.is_hole_point(_dragging_point_index):
		var outer: PackedVector2Array = _editing_object.get_outer_points()
		outer.set(_dragging_point_index, local_pos)
		_editing_object.apply_points(outer)
	else:
		if not Geometry2D.is_point_in_polygon(local_pos, _editing_object.get_outer_points()):
			return
		var hole_idx: int = _widget.get_hole_of(_dragging_point_index)
		var hole: PackedVector2Array = _editing_object.get_hole(hole_idx)
		hole.set(_widget.get_ring_index(_dragging_point_index), local_pos)
		_editing_object.set_hole(hole_idx, hole)
	
	_widget.sync()


## Ends a point drag wherever it is interrupted - release, a selection change or the tool being
## swapped out under it - restoring the decorations the drag suppressed and recording the move.
func _finish_drag() -> void:
	if _dragging_point_index < 0:
		return
	
	var obj: LDObjectPolygon = _editing_object
	if is_instance_valid(obj):
		obj.surface.decorations_enabled = obj.get_decorations_enabled()
		obj.apply_points(obj.get_outer_points())
		_push_action("Move Polygon Point", obj, obj.get_outer_points().duplicate(), obj.get_holes().duplicate())
	
	_dragging_point_index = -1
	_widget.set_pressed_point(-1)
	set_cursor_shape(Control.CURSOR_ARROW)


func _delete_point(index: int) -> void:
	if not _editing_object or index < 0 or index >= _widget.get_point_count():
		return
	
	var old_outer: PackedVector2Array = _editing_object.get_outer_points()
	var new_outer: PackedVector2Array = old_outer.duplicate()
	var new_holes: Array[PackedVector2Array] = _editing_object.get_holes().duplicate()
	var action: String = "Delete Polygon Point"
	
	if not _widget.is_hole_point(index):
		if old_outer.size() <= 3:
			return
		new_outer.remove_at(index)
	else:
		var hole_idx: int = _widget.get_hole_of(index)
		var hole: PackedVector2Array = new_holes.get(hole_idx).duplicate()
		if hole.size() <= 3:
			new_holes.remove_at(hole_idx)
			action = "Remove Hole"
		else:
			hole.remove_at(_widget.get_ring_index(index))
			new_holes.set(hole_idx, hole)
			action = "Delete Hole Point"
	
	_widget.forget_last_click()
	_push_action(action, _editing_object, new_outer, new_holes)


## Splits the hovered edge at the snapped cursor and hands the new point straight to a drag, so an
## edge click turns into "add and place" in one gesture.
func _insert_point_on_edge(edge_index: int, hole_index: int) -> void:
	if not _editing_object:
		return
	
	_widget.forget_last_click()
	
	var local_pos: Vector2 = world_to_object(_editing_object, viewport.get_snapped_mouse(_editing_object))
	var old_outer: PackedVector2Array = _editing_object.get_outer_points()
	var new_outer: PackedVector2Array = old_outer.duplicate()
	var new_holes: Array[PackedVector2Array] = _editing_object.get_holes().duplicate()
	var drag_index: int = edge_index + 1
	var action: String = "Insert Polygon Point"
	
	if hole_index < 0:
		if _has_point_near(old_outer, local_pos):
			return
		new_outer.insert(drag_index, local_pos)
	else:
		if hole_index >= new_holes.size():
			return
		var hole: PackedVector2Array = new_holes.get(hole_index).duplicate()
		if _has_point_near(hole, local_pos):
			return
		hole.insert(drag_index, local_pos)
		new_holes.set(hole_index, hole)
		action = "Insert Hole Point"
		drag_index += old_outer.size()
		for i: int in hole_index:
			drag_index += new_holes.get(i).size()
	
	_push_action(action, _editing_object, new_outer, new_holes)
	_begin_drag_point(drag_index)


func _has_point_near(points: PackedVector2Array, target: Vector2) -> bool:
	for point: Vector2 in points:
		if point.distance_to(target) < POINT_MERGE_DISTANCE:
			return true
	return false


## Every edit this tool makes is the same undoable step: the polygon's rings before against the
## rings after, applied whole.
func _push_action(action: String, obj: LDObjectPolygon, new_outer: PackedVector2Array, new_holes: Array[PackedVector2Array]) -> void:
	var old_outer: PackedVector2Array = _drag_start_outer if _dragging_point_index >= 0 else obj.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = _drag_start_holes if _dragging_point_index >= 0 else obj.get_holes().duplicate()
	LD.get_history_handler().push(action,
		_apply_rings.bind(obj, new_outer, new_holes),
		_apply_rings.bind(obj, old_outer, old_holes)
	)


func _apply_rings(obj: LDObjectPolygon, outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	if not is_instance_valid(obj):
		return
	obj.clear_holes()
	obj.apply_points(outer)
	for hole: PackedVector2Array in holes:
		obj.add_hole(hole)
