class_name LDToolMove
extends LDTool


var _drag_offsets: Array[Vector2] = []
var _drag_start_positions: Array[Vector2] = []
var _objects: Array[LDObject] = []
var _is_dragging: bool = false
var _return_to_select: bool = false


func get_tool_name() -> String:
	return "Move"


func get_cursor_shape() -> Input.CursorShape:
	return Input.CURSOR_DRAG


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _try_begin_drag_at(_get_mouse_pos()):
				return
		else:
			if _is_dragging:
				end_drag()
	
	if event is InputEventMouseMotion and _is_dragging:
		update_drag(_get_mouse_pos())


func _on_disable() -> void:
	if _is_dragging:
		end_drag()
	super()


func try_begin_drag(mouse_pos: Vector2, objects: Array[LDObject]) -> bool:
	for obj: LDObject in objects:
		if _object_contains_point(obj, mouse_pos):
			_begin_drag(mouse_pos, objects, true)
			return true
	return false


func update_drag(mouse_pos: Vector2) -> void:
	if not _is_dragging:
		return
	
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	var world_mouse: Vector2 = full_transform.affine_inverse() * mouse_pos
	
	for i: int in _objects.size():
		var new_pos: Vector2 = (world_mouse + _drag_offsets[i]).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
		_objects[i].position = new_pos
		if _objects[i]._properties.size() > 0:
			_objects[i].set_property(&"position", new_pos)


func end_drag() -> void:
	if not _is_dragging:
		return
	
	var old_positions: Array[Vector2] = _drag_start_positions.duplicate()
	var new_positions: Array[Vector2] = []
	var objects: Array[LDObject] = _objects.duplicate()
	for obj: LDObject in objects:
		new_positions.append(obj.position)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Move Objects")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = new_positions[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	_is_dragging = false
	_objects.clear()
	_drag_start_positions.clear()
	_drag_offsets.clear()
	
	if _return_to_select:
		_return_to_select = false
		get_tool_handler().select_tool("select")
	else:
		viewport.clear_selection()


func is_dragging() -> bool:
	return _is_dragging


func _try_begin_drag_at(mouse_pos: Vector2) -> bool:
	var selected: Array[LDObject] = viewport.get_selected_objects()
	
	if not selected.is_empty():
		if try_begin_drag(mouse_pos, selected):
			return true
	
	var obj: LDObject = _get_object_at(mouse_pos)
	if not obj:
		return false
	
	viewport.set_selected_objects([obj])
	_begin_drag(mouse_pos, [obj], false)
	return true


func _begin_drag(mouse_pos: Vector2, objects: Array[LDObject], return_to_select: bool) -> void:
	_is_dragging = true
	_return_to_select = return_to_select
	_objects = objects.duplicate()
	_drag_start_positions.clear()
	_drag_offsets.clear()
	
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	var world_mouse: Vector2 = full_transform.affine_inverse() * mouse_pos
	
	for obj: LDObject in _objects:
		_drag_start_positions.append(obj.position)
		_drag_offsets.append(obj.position - world_mouse)


func _get_object_at(mouse_pos: Vector2) -> LDObject:
	for obj: LDObject in viewport.get_all_objects():
		if obj.is_preview:
			continue
		if _object_contains_point(obj, mouse_pos):
			return obj
	return null


func _object_contains_point(obj: LDObject, mouse_pos: Vector2) -> bool:
	if not obj.editor_shape_area:
		var half: Vector2 = obj.get_stamp_size() * 0.5
		var screen_rect: Rect2 = viewport.world_rect_to_screen(obj.global_position - half, obj.get_stamp_size())
		return screen_rect.has_point(mouse_pos)
	
	for child: Node in obj.editor_shape_area.get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		if not shape or not shape.shape is RectangleShape2D:
			continue
		var rect: Rect2 = (shape.shape as RectangleShape2D).get_rect()
		var world_top_left: Vector2 = shape.global_position + rect.position * obj.global_scale
		var screen_rect: Rect2 = viewport.world_rect_to_screen(world_top_left, rect.size * obj.global_scale)
		if screen_rect.has_point(mouse_pos):
			return true
	
	return false


func _get_mouse_pos() -> Vector2:
	return viewport.get_selection_overlay().get_local_mouse_position()
