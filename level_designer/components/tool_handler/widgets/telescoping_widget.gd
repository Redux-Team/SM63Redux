class_name LDTelescopingWidget
extends LDToolWidget


const BODY_GRAB_RADIUS: float = 18.0


@export var caps: LDToolHandleSet
@export var head_style: LDToolWidgetStyle
## The tail cap wears whichever of these matches the object's axis, so a horizontal telescope and
## a vertical one can carry different art.
@export var style_x: LDToolWidgetStyle
@export var style_y: LDToolWidgetStyle


var _dragging_idx: int = -1
var _hovered_idx: int = -1
var _drag_start_units: int = 0
var _drag_start_endpoint_screen: Vector2 = Vector2.ZERO
var _drag_start_object_pos: Vector2 = Vector2.ZERO
var _pending_object_drag: bool = false


func _on_activate() -> void:
	_attach_to_overlay()
	show()
	_sync_handles()


func _on_deactivate() -> void:
	hide()
	_detach_from_overlay()
	_dragging_idx = -1
	_hovered_idx = -1
	_pending_object_drag = false


func _on_refresh(_objects: Array[LDObject]) -> void:
	_sync_handles()


func _on_input(event: InputEvent) -> void:
	if _bound_objects.is_empty():
		return
	
	var obj: LDObjectTelescoping = _bound_objects.get(0) as LDObjectTelescoping
	_sync_handles()
	
	if event is InputEventMouseMotion:
		if _pending_object_drag:
			_pending_object_drag = false
			_begin_move_handoff("TelescopingEdit", [obj])
			return
		
		if _dragging_idx >= 0:
			_update_drag(obj)
			_sync_handles()
			_update_cursor(obj)
			return
		
		var prev: int = _hovered_idx
		_hovered_idx = caps.find_at(get_screen_mouse_pos())
		if _hovered_idx != prev:
			_sync_handle_states()
		_update_cursor(obj)
	
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if get_ld_viewport().is_panning():
				return
			var hit: int = caps.find_at(get_screen_mouse_pos())
			if hit >= 0:
				_dragging_idx = hit
				_drag_start_units = _get_current_units(obj)
				_drag_start_object_pos = obj.position
				var endpoints: Array[Vector2] = _get_endpoints(obj)
				_drag_start_endpoint_screen = world_to_screen(endpoints.get(hit), obj)
				_hovered_idx = -1
				_sync_handle_states()
				_update_cursor(obj)
			elif _is_mouse_near_body(obj):
				_pending_object_drag = true
			else:
				select_tool("select")
		else:
			if _dragging_idx >= 0:
				_commit_drag(obj)
				_dragging_idx = -1
				_hovered_idx = caps.find_at(get_screen_mouse_pos())
				_sync_handle_states()
				_update_cursor(obj)
			_pending_object_drag = false


func draw_overlay(_draw_node: CanvasItem) -> void:
	if _bound_objects.is_empty():
		return
	_sync_handles()


func _sync_handles() -> void:
	if _bound_objects.is_empty():
		return
	var obj: LDObjectTelescoping = _bound_objects.get(0) as LDObjectTelescoping
	var endpoints: Array[Vector2] = _get_endpoints(obj)
	var zoom: float = get_camera_zoom()
	
	caps.resize_to(2)
	var head: LDToolHandle = caps.get_handle(0)
	if head_style and head.style != head_style:
		head.style = head_style
	var tail_style: LDToolWidgetStyle = style_x if obj.is_telescoping_x() else style_y
	var tail: LDToolHandle = caps.get_handle(1)
	if tail_style and tail.style != tail_style:
		tail.style = tail_style
	for i: int in 2:
		caps.place(i, world_to_screen(endpoints.get(i), obj), zoom)
	
	_sync_handle_states()


func _sync_handle_states() -> void:
	caps.set_active(_hovered_idx, _dragging_idx)


func _update_drag(obj: LDObjectTelescoping) -> void:
	var mouse: Vector2 = get_screen_mouse_pos()
	
	if obj.is_telescoping_x():
		var sign_x: float = -1.0 if _dragging_idx == 0 else 1.0
		var delta_screen: float = (mouse.x - _drag_start_endpoint_screen.x) * sign_x
		var delta_world: float = _screen_dist_to_world(obj, delta_screen, true)
		var segment_w: float = float(obj.get_middle_segment_width())
		var unit_delta: int = int(delta_world / segment_w)
		var new_units: int = obj.clamp_units(_drag_start_units + unit_delta)
		var old_units: int = _get_current_units(obj)
		var old_width: float = obj.get_total_width(old_units)
		var new_width: float = obj.get_total_width(new_units)
		var width_delta: float = (new_width - old_width) * 0.5 * sign_x
		obj.set_property(&"t_size_x", new_units)
		obj.position.x += width_delta
		if obj.has_property(&"position"):
			obj.set_property(&"position", obj.position)
	
	elif obj.is_telescoping_y():
		var sign_y: float = -1.0 if _dragging_idx == 0 else 1.0
		var delta_screen: float = (mouse.y - _drag_start_endpoint_screen.y) * sign_y
		var delta_world: float = _screen_dist_to_world(obj, delta_screen, false)
		var segment_h: float = float(obj.get_middle_segment_height())
		var unit_delta: int = int(delta_world / segment_h)
		var new_units: int = obj.clamp_units(_drag_start_units + unit_delta)
		var old_units: int = _get_current_units(obj)
		var old_height: float = obj.get_total_height(old_units)
		var new_height: float = obj.get_total_height(new_units)
		var height_delta: float = (new_height - old_height) * 0.5 * sign_y
		obj.set_property(&"t_size_y", new_units)
		obj.position.y += height_delta
		if obj.has_property(&"position"):
			obj.set_property(&"position", obj.position)


func _commit_drag(obj: LDObjectTelescoping) -> void:
	var prop_name: StringName = &"t_size_x" if obj.is_telescoping_x() else &"t_size_y"
	var old_units: int = _drag_start_units
	var old_pos: Vector2 = _drag_start_object_pos
	var new_units: int = _get_current_units(obj)
	var new_pos: Vector2 = obj.position
	
	get_history().push("Resize Telescoping Object",
		func() -> void:
			if is_instance_valid(obj):
				obj.set_property(prop_name, new_units)
				obj.position = new_pos
				if obj.has_property(&"position"):
					obj.set_property(&"position", new_pos)
				_sync_handles(),
		func() -> void:
			if is_instance_valid(obj):
				obj.set_property(prop_name, old_units)
				obj.position = old_pos
				if obj.has_property(&"position"):
					obj.set_property(&"position", old_pos)
				_sync_handles()
	)


func _get_endpoints(obj: LDObjectTelescoping) -> Array[Vector2]:
	var center: Vector2 = obj.position
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
	var a: Vector2 = world_to_screen(endpoints.get(0), obj)
	var b: Vector2 = world_to_screen(endpoints.get(1), obj)
	var ab: Vector2 = b - a
	var mouse: Vector2 = get_screen_mouse_pos()
	var t: float = clampf((mouse - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return mouse.distance_to(a + t * ab) <= BODY_GRAB_RADIUS


func _update_cursor(obj: LDObjectTelescoping) -> void:
	if _dragging_idx >= 0 or _hovered_idx >= 0:
		_tool.set_cursor_shape(Control.CURSOR_HSIZE if obj.is_telescoping_x() else Control.CURSOR_VSIZE)
	elif _is_mouse_near_body(obj):
		_tool.set_cursor_shape(Control.CURSOR_MOVE)
	else:
		_tool.set_cursor_shape(Control.CURSOR_ARROW)


func _screen_dist_to_world(obj: LDObjectTelescoping, screen_dist: float, is_x: bool) -> float:
	var vp: LDViewport = get_ld_viewport()
	var origin: Vector2 = vp.screen_to_world(Vector2.ZERO, obj)
	var unit: Vector2 = vp.screen_to_world(Vector2(screen_dist, 0.0) if is_x else Vector2(0.0, screen_dist), obj)
	return (unit - origin).length() * signf(screen_dist)
