extends LDTool


@export var shortcut_handler: LDSelectionShortcutHandler

var _is_box_selecting: bool = false
var _is_shift_selecting: bool = false
var _box_select_origin: Vector2
var _box_select_rect: Rect2
var _overlay: LDSelectionOverlay
var _move_tool: LDToolMove


func get_tool_name() -> String:
	return "Select"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	_overlay = viewport.get_selection_overlay() as LDSelectionOverlay
	LD.get_object_handler().selected_object_changed.connect(_on_selected_object_changed)
	viewport.touch_tap.connect(_on_touch_tap)
	viewport.touch_swipe_began.connect(_on_touch_swipe_began)
	viewport.touch_swipe_moved.connect(_on_touch_swipe_moved)
	viewport.touch_swipe_ended.connect(_on_touch_swipe_ended)


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	
	if shortcut_handler:
		shortcut_handler.handle_input(event)
	
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			_delete_selected()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = _get_mouse_pos()
			var move: LDToolMove = _get_move_tool()
			if move and move.try_begin_drag(mouse_pos, viewport.get_selected_objects()):
				_move_tool = move
				get_tool_handler().select_tool("move")
				return
			_is_box_selecting = true
			_is_shift_selecting = event.shift_pressed
			_box_select_origin = mouse_pos
			_box_select_rect = Rect2(_box_select_origin, Vector2.ZERO)
		else:
			_is_box_selecting = false
			_commit_box_select()
			_overlay.hide_box()
	
	if event is InputEventMouseMotion and _is_box_selecting:
		_box_select_rect = Rect2(_box_select_origin, _get_mouse_pos() - _box_select_origin).abs()
		_overlay.show_box(_box_select_rect)
		_update_hover_states()


func _on_enable() -> void:
	if _move_tool and not _move_tool.is_dragging():
		_move_tool = null


func _on_disable() -> void:
	_overlay.hide_box()
	_is_box_selecting = false


func _on_selected_object_changed(_obj: GameObject) -> void:
	viewport.clear_selection()
	_overlay.hide_box()
	_is_box_selecting = false


func _update_hover_states() -> void:
	for obj: LDObject in viewport.get_all_objects():
		if obj.is_preview:
			continue
		if obj in viewport.get_selected_objects():
			obj.set_selection_state(LDObject.SelectionState.SELECTED)
			continue
		if _object_intersects_box(obj):
			obj.set_selection_state(LDObject.SelectionState.HOVERED)
		else:
			obj.set_selection_state(LDObject.SelectionState.HIDDEN)


func _commit_box_select() -> void:
	var found: Array[LDObject] = []
	for obj: LDObject in viewport.get_all_objects():
		if obj.is_preview:
			continue
		if _object_intersects_box(obj):
			found.append(obj)
	
	if _is_shift_selecting:
		var combined: Array[LDObject] = viewport.get_selected_objects().duplicate()
		for obj: LDObject in found:
			if obj not in combined:
				combined.append(obj)
		viewport.set_selected_objects(combined)
	else:
		viewport.set_selected_objects(found)


func _delete_selected() -> void:
	var to_delete: Array[LDObject] = viewport.get_selected_objects().duplicate()
	viewport.clear_selection()
	for obj: LDObject in to_delete:
		obj.queue_free()


func _object_intersects_box(obj: LDObject) -> bool:
	var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
	if poly_obj and poly_obj.editor_polygon:
		var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * obj.get_global_transform()
		for point: Vector2 in poly_obj.editor_polygon.polygon:
			var screen_point: Vector2 = full_transform * point
			if _box_select_rect.has_point(screen_point):
				return true
		return false
	
	if not obj.editor_shape_area:
		var half: Vector2 = obj.get_stamp_size() * 0.5
		var screen_rect: Rect2 = viewport.world_rect_to_screen(obj.global_position - half, obj.get_stamp_size())
		return _box_select_rect.intersects(screen_rect)
	
	for child: Node in obj.editor_shape_area.get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		if not shape or not shape.shape is RectangleShape2D:
			continue
		var rect: Rect2 = (shape.shape as RectangleShape2D).get_rect()
		var world_top_left: Vector2 = shape.global_position + rect.position * obj.global_scale
		var screen_rect: Rect2 = viewport.world_rect_to_screen(world_top_left, rect.size * obj.global_scale)
		if _box_select_rect.intersects(screen_rect):
			return true
	
	return false


func _get_object_at(mouse_pos: Vector2) -> LDObject:
	for obj: LDObject in viewport.get_all_objects():
		if obj.is_preview:
			continue
		if not obj.editor_shape_area:
			var half: Vector2 = obj.get_stamp_size() * 0.5
			var screen_rect: Rect2 = viewport.world_rect_to_screen(obj.global_position - half, obj.get_stamp_size())
			if screen_rect.has_point(mouse_pos):
				return obj
			continue
		for child: Node in obj.editor_shape_area.get_children():
			var shape: CollisionShape2D = child as CollisionShape2D
			if not shape or not shape.shape is RectangleShape2D:
				continue
			var rect: Rect2 = (shape.shape as RectangleShape2D).get_rect()
			var world_top_left: Vector2 = shape.global_position + rect.position * obj.global_scale
			var screen_rect: Rect2 = viewport.world_rect_to_screen(world_top_left, rect.size * obj.global_scale)
			if screen_rect.has_point(mouse_pos):
				return obj
	return null


func _get_move_tool() -> LDToolMove:
	return get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


func _get_mouse_pos() -> Vector2:
	return _overlay.get_local_mouse_position()


func _on_touch_tap(pos: Vector2) -> void:
	if not is_active():
		return
	var obj: LDObject = _get_object_at(pos)
	if obj:
		viewport.set_selected_objects([obj])
	else:
		viewport.clear_selection()


func _on_touch_swipe_began(pos: Vector2) -> void:
	if not is_active():
		return
	_is_box_selecting = true
	_is_shift_selecting = false
	_box_select_origin = pos
	_box_select_rect = Rect2(pos, Vector2.ZERO)


func _on_touch_swipe_moved(pos: Vector2) -> void:
	if not is_active():
		return
	_box_select_rect = Rect2(_box_select_origin, pos - _box_select_origin).abs()
	_overlay.show_box(_box_select_rect)
	_update_hover_states()


func _on_touch_swipe_ended() -> void:
	if not is_active():
		return
	_is_box_selecting = false
	_commit_box_select()
	_overlay.hide_box()
