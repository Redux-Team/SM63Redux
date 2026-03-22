class_name LDRotateTool
extends LDTool


const RING_RADIUS: float = 48.0
const HANDLE_RADIUS: float = 6.0
const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const HANDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const HANDLE_HOVER_COLOR: Color = Color(0.4, 0.8, 1.0, 1.0)
const DOUBLE_CLICK_THRESHOLD: float = 0.3


var _is_dragging: bool = false
var _did_drag: bool = false
var _last_click_time: float = 0.0
var _drag_start_angle: float = 0.0
var _drag_start_rotations: Array[float] = []
var _is_handle_hovered: bool = false
var _overlay: LDSelectionOverlay


func get_tool_name() -> String:
	return "Rotate"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_ARROW


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	_overlay = viewport.get_selection_overlay()
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if not is_active():
		return
	_overlay.queue_redraw()


func _on_enable() -> void:
	super()
	if _get_rotatable_objects().is_empty():
		get_tool_handler().select_tool("select")
		return
	_overlay.queue_redraw()


func _on_disable() -> void:
	_is_dragging = false
	_overlay.queue_redraw()
	super()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	
	var objects: Array[LDObject] = _get_rotatable_objects()
	if objects.is_empty():
		get_tool_handler().select_tool("select")
		return
	
	var center: Vector2 = _get_center_screen(objects)
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = _get_mouse_pos()
		var was_hovered: bool = _is_handle_hovered
		_is_handle_hovered = mouse_pos.distance_to(_get_handle_pos(center, _get_current_angle(objects))) <= HANDLE_RADIUS * 2.0
		if was_hovered != _is_handle_hovered:
			_overlay.queue_redraw()
		
		if _is_dragging:
			_did_drag = true
			var angle: float = (mouse_pos - center).angle()
			var delta_deg: float = rad_to_deg(angle - _drag_start_angle)
			if not event.alt_pressed:
				delta_deg = snappedf(delta_deg, 15.0)
			for i: int in objects.size():
				objects[i].set_property(&"rotation", _drag_start_rotations[i] + delta_deg)
			_overlay.queue_redraw()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = _get_mouse_pos()
			if mouse_pos.distance_to(_get_handle_pos(center, _get_current_angle(objects))) <= HANDLE_RADIUS * 2.0:
				_is_dragging = true
				_did_drag = false
				_drag_start_angle = (mouse_pos - center).angle()
				_drag_start_rotations.clear()
				for obj: LDObject in objects:
					_drag_start_rotations.append(obj.get_property(&"rotation") if obj.get_property(&"rotation") != null else 0.0)
			else:
				get_tool_handler().select_tool("select")
		else:
			if _is_dragging:
				if _did_drag:
					_commit_rotation(objects)
				else:
					var now: float = Time.get_ticks_msec() / 1000.0
					if now - _last_click_time <= DOUBLE_CLICK_THRESHOLD:
						_reset_rotation(objects)
					_last_click_time = now
			_is_dragging = false
			_did_drag = false


func _reset_rotation(objects: Array[LDObject]) -> void:
	var old_rotations: Array[float] = []
	for obj: LDObject in objects:
		old_rotations.append(obj.get_property(&"rotation") if obj.get_property(&"rotation") != null else 0.0)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Reset Rotation")
	history.add_do(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj):
				obj.set_property(&"rotation", 0.0)
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].set_property(&"rotation", old_rotations[i])
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.set_property(&"rotation", 0.0)
	_overlay.queue_redraw()


func _on_selection_changed(_objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if _get_rotatable_objects().is_empty():
		get_tool_handler().select_tool("select")
		return
	_overlay.queue_redraw()


func draw_overlay(draw_node: CanvasItem) -> void:
	if not is_active():
		return
	
	var objects: Array[LDObject] = _get_rotatable_objects()
	if objects.is_empty():
		return
	
	var center: Vector2 = _get_center_screen(objects)
	var current_angle: float = _get_current_angle(objects)
	var handle_pos: Vector2 = _get_handle_pos(center, current_angle)
	var handle_color: Color = HANDLE_HOVER_COLOR if _is_handle_hovered or _is_dragging else HANDLE_COLOR
	
	draw_node.draw_arc(center, RING_RADIUS, 0.0, TAU, 64, RING_COLOR, 1.0)
	draw_node.draw_circle(handle_pos, HANDLE_RADIUS, handle_color)
	draw_node.draw_line(center, handle_pos, RING_COLOR, 1.0)


func _commit_rotation(objects: Array[LDObject]) -> void:
	var old_rotations: Array[float] = _drag_start_rotations.duplicate()
	var new_rotations: Array[float] = []
	for obj: LDObject in objects:
		new_rotations.append(obj.get_property(&"rotation") if obj.get_property(&"rotation") != null else 0.0)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Rotate Objects")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].set_property(&"rotation", new_rotations[i])
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].set_property(&"rotation", old_rotations[i])
	)
	history.commit_action()


func _get_rotatable_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		if obj.get_property(&"rotation") != null:
			result.append(obj)
	return result


func _get_center_screen(objects: Array[LDObject]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		sum += _world_to_screen(obj.global_position)
	return sum / objects.size()


func _get_current_angle(objects: Array[LDObject]) -> float:
	if objects.is_empty():
		return 0.0
	var rotation_val: Variant = objects[0].get_property(&"rotation")
	return deg_to_rad(rotation_val if rotation_val != null else 0.0)


func _get_handle_pos(center: Vector2, angle: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * RING_RADIUS


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform * world_pos


func _get_mouse_pos() -> Vector2:
	return _overlay.get_local_mouse_position()
