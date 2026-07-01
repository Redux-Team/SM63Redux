class_name LDTelescopingWidget
extends LDToolWidget


const POINT_GRAB_RADIUS: float = 18.0


@export var point_a: Button
@export var point_b: Button


var _dragging_idx: int = -1
var _hovered_idx: int = -1
var _drag_start_units: int = 0
var _drag_start_screen_pos: Vector2 = Vector2.ZERO
var _drag_start_endpoint_screen: Vector2 = Vector2.ZERO
var _drag_start_object_pos: Vector2 = Vector2.ZERO
var _pending_object_drag: bool = false



func _on_activate() -> void:
	_attach_to_overlay()
	show()
	_sync_buttons()


func _on_deactivate() -> void:
	hide()
	_detach_from_overlay()
	_dragging_idx = -1
	_hovered_idx = -1
	_pending_object_drag = false


func _on_refresh(_objects: Array[LDObject]) -> void:
	_sync_buttons()


func _on_input(event: InputEvent) -> void:
	if _bound_objects.is_empty():
		return
	
	var obj: LDObjectTelescoping = _bound_objects.get(0) as LDObjectTelescoping
	
	if event is InputEventMouseMotion:
		if _pending_object_drag:
			_pending_object_drag = false
			_begin_move_handoff("TelescopingEdit", [obj])
			return
		
		if _dragging_idx >= 0:
			_update_drag(obj)
			_sync_buttons()
			_update_cursor(obj)
			return
		
		var prev: int = _hovered_idx
		_hovered_idx = _get_handle_at(obj)
		if _hovered_idx != prev:
			_sync_button_states()
		_update_cursor(obj)
	
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if get_ld_viewport().is_panning():
				return
			var hit: int = _get_handle_at(obj)
			if hit >= 0:
				_dragging_idx = hit
				_drag_start_units = _get_current_units(obj)
				_drag_start_object_pos = obj.global_position
				var endpoints: Array[Vector2] = _get_endpoints(obj)
				_drag_start_endpoint_screen = world_to_screen(endpoints.get(hit))
				_hovered_idx = -1
				_sync_button_states()
				_update_cursor(obj)
			elif _is_mouse_near_body(obj):
				_pending_object_drag = true
			else:
				select_tool("select")
		else:
			if _dragging_idx >= 0:
				_commit_drag(obj)
				_dragging_idx = -1
				_hovered_idx = _get_handle_at(obj)
				_sync_button_states()
				_update_cursor(obj)
			_pending_object_drag = false


func draw_overlay(_draw_node: CanvasItem) -> void:
	if _bound_objects.is_empty():
		return
	_sync_buttons()


func _sync_buttons() -> void:
	if _bound_objects.is_empty():
		return
	var obj: LDObjectTelescoping = _bound_objects.get(0) as LDObjectTelescoping
	var endpoints: Array[Vector2] = _get_endpoints(obj)
	
	if is_instance_valid(point_a):
		point_a.position = world_to_screen(endpoints.get(0)) - point_a.size * 0.5
		point_a.visible = true
	if is_instance_valid(point_b):
		point_b.position = world_to_screen(endpoints.get(1)) - point_b.size * 0.5
		point_b.visible = true
	
	_sync_button_states()


func _sync_button_states() -> void:
	_sync_single_button(point_a, 0)
	_sync_single_button(point_b, 1)


func _sync_single_button(btn: Button, idx: int) -> void:
	if not is_instance_valid(btn):
		return
	btn.set(&"theme_override_styles/normal", null)
	if _dragging_idx == idx:
		btn.set_pressed_no_signal(true)
	else:
		btn.set_pressed_no_signal(false)
		btn.mouse_exited.emit()
		if _hovered_idx == idx:
			btn.mouse_entered.emit()


func _update_drag(obj: LDObjectTelescoping) -> void:
	var mouse: Vector2 = get_screen_mouse_pos()
	
	if obj.is_telescoping_x():
		var sign_x: float = -1.0 if _dragging_idx == 0 else 1.0
		var delta_screen: float = (mouse.x - _drag_start_endpoint_screen.x) * sign_x
		var delta_world: float = _screen_dist_to_world(delta_screen, true)
		var segment_w: float = float(obj.get_middle_segment_width())
		var unit_delta: int = int(delta_world / segment_w)
		var new_units: int = obj.clamp_units(_drag_start_units + unit_delta)
		var old_units: int = _get_current_units(obj)
		var old_width: float = obj.get_total_width(old_units)
		var new_width: float = obj.get_total_width(new_units)
		var width_delta: float = (new_width - old_width) * 0.5 * sign_x
		obj.set_property(&"t_size_x", new_units)
		obj.global_position.x += width_delta
		if obj.has_property(&"position"):
			obj.set_property(&"position", obj.global_position)
	
	elif obj.is_telescoping_y():
		var sign_y: float = -1.0 if _dragging_idx == 0 else 1.0
		var delta_screen: float = (mouse.y - _drag_start_endpoint_screen.y) * sign_y
		var delta_world: float = _screen_dist_to_world(delta_screen, false)
		var segment_h: float = float(obj.get_middle_segment_height())
		var unit_delta: int = int(delta_world / segment_h)
		var new_units: int = obj.clamp_units(_drag_start_units + unit_delta)
		var old_units: int = _get_current_units(obj)
		var old_height: float = obj.get_total_height(old_units)
		var new_height: float = obj.get_total_height(new_units)
		var height_delta: float = (new_height - old_height) * 0.5 * sign_y
		obj.set_property(&"t_size_y", new_units)
		obj.global_position.y += height_delta
		if obj.has_property(&"position"):
			obj.set_property(&"position", obj.global_position)


func _commit_drag(obj: LDObjectTelescoping) -> void:
	var prop_name: StringName = &"t_size_x" if obj.is_telescoping_x() else &"t_size_y"
	var old_units: int = _drag_start_units
	var old_pos: Vector2 = _drag_start_object_pos
	var new_units: int = _get_current_units(obj)
	var new_pos: Vector2 = obj.global_position
	
	var history: LDHistoryHandler = get_history()
	history.begin_action("Resize Telescoping Object")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.set_property(prop_name, new_units)
			obj.global_position = new_pos
			if obj.has_property(&"position"):
				obj.set_property(&"position", new_pos)
			_sync_buttons()
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.set_property(prop_name, old_units)
			obj.global_position = old_pos
			if obj.has_property(&"position"):
				obj.set_property(&"position", old_pos)
			_sync_buttons()
	)
	history.commit_action()


func _get_handle_at(obj: LDObjectTelescoping) -> int:
	var endpoints: Array[Vector2] = _get_endpoints(obj)
	var mouse: Vector2 = get_screen_mouse_pos()
	for i: int in 2:
		if mouse.distance_to(world_to_screen(endpoints.get(i))) <= POINT_GRAB_RADIUS:
			return i
	return -1


func _get_endpoints(obj: LDObjectTelescoping) -> Array[Vector2]:
	var center: Vector2 = obj.global_position
	if obj.is_telescoping_x():
		var half_w: float = obj.get_total_width(_get_current_units(obj)) * 0.5
		return [center + Vector2(-half_w, 0.0), center + Vector2(half_w, 0.0)]
	var half_h: float = obj.get_total_height(_get_current_units(obj)) * 0.5
	return [center + Vector2(0.0, -half_h), center + Vector2(0.0, half_h)]


func _get_current_units(obj: LDObjectTelescoping) -> int:
	var prop: StringName = &"t_size_x" if obj.is_telescoping_x() else &"t_size_y"
	var val: Variant = obj.get_property(prop)
	return int(val) if val != null else 0


func _is_mouse_near_body(obj: LDObjectTelescoping) -> bool:
	var endpoints: Array[Vector2] = _get_endpoints(obj)
	var a: Vector2 = world_to_screen(endpoints.get(0))
	var b: Vector2 = world_to_screen(endpoints.get(1))
	var ab: Vector2 = b - a
	var mouse: Vector2 = get_screen_mouse_pos()
	var t: float = clampf((mouse - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return mouse.distance_to(a + t * ab) <= POINT_GRAB_RADIUS


func _update_cursor(obj: LDObjectTelescoping) -> void:
	if _dragging_idx >= 0:
		_tool.set_cursor_shape(Control.CURSOR_HSIZE if obj.is_telescoping_x() else Control.CURSOR_VSIZE)
	elif _hovered_idx >= 0:
		_tool.set_cursor_shape(Control.CURSOR_HSIZE if obj.is_telescoping_x() else Control.CURSOR_VSIZE)
	elif _is_mouse_near_body(obj):
		_tool.set_cursor_shape(Control.CURSOR_MOVE)
	else:
		_tool.set_cursor_shape(Control.CURSOR_ARROW)


func _screen_dist_to_world(screen_dist: float, is_x: bool) -> float:
	var vp: LDViewport = get_ld_viewport()
	var xform: Transform2D = vp.get_viewport().get_canvas_transform() * vp.get_root().get_global_transform()
	var origin: Vector2 = xform.affine_inverse() * Vector2.ZERO
	var unit: Vector2 = xform.affine_inverse() * (Vector2(screen_dist, 0.0) if is_x else Vector2(0.0, screen_dist))
	return (unit - origin).length() * signf(screen_dist)
