extends LDTool

const HANDLE_GRAB_RADIUS: float = 18.0
const HANDLE_BUTTON_SIZE: float = 12.0

static var CORNER_ANCHORS: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, 1.0),
]

static var OPPOSITE_CORNER: Array[int] = [2, 3, 0, 1]

static var CORNER_CURSORS: Array[Control.CursorShape] = [
	Control.CURSOR_FDIAGSIZE,
	Control.CURSOR_BDIAGSIZE,
	Control.CURSOR_FDIAGSIZE,
	Control.CURSOR_BDIAGSIZE,
]

var _editing_object: LDObject
var _drag_corner: int = -1
var _drag_start_object_pos: Vector2
var _drag_start_size: Vector2
var _hovered_corner: int = -1
var _handle_buttons: Array[Button] = []
var _pending_block_drag: bool = false


func get_tool_name() -> String:
	return "BlockEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and _is_block(selected[0]):
		_editing_object = selected[0]
		_rebuild_handle_buttons()
	else:
		get_tool_handler().select_tool("select")


func _on_disable() -> void:
	_editing_object = null
	_drag_corner = -1
	_hovered_corner = -1
	_clear_handle_buttons()
	super()


func _on_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if objects.size() == 1 and _is_block(objects[0]):
		_editing_object = objects[0]
		_rebuild_handle_buttons()
	else:
		_editing_object = null
		_clear_handle_buttons()
		get_tool_handler().select_tool("select")


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if is_active():
		_sync_handle_buttons()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		if _drag_corner >= 0:
			_drag_resize(_get_snapped_mouse_pos())
			_sync_handle_buttons()
		else:
			_update_hover(_get_screen_mouse_pos())
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewport.is_panning():
				return
			if _hovered_corner >= 0:
				_begin_drag(_hovered_corner)
			elif _is_mouse_inside_block():
				_pending_block_drag = true
			else:
				viewport.clear_selection()
				get_tool_handler().select_tool("select")
				get_tool_handler().get_selected_tool()._on_viewport_input(event)
		else:
			if _drag_corner >= 0:
				_end_drag()
			_pending_block_drag = false
	
	if event is InputEventMouseMotion and _pending_block_drag:
		_pending_block_drag = false
		var move: LDToolMove = _get_move_tool()
		if move and move.try_begin_drag(_get_screen_mouse_pos(), [_editing_object]):
			move.return_tool = "block_edit"
			get_tool_handler().select_tool("move")
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _drag_corner >= 0:
			_cancel_drag()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	if event.keycode == KEY_ESCAPE and _drag_corner >= 0:
		_cancel_drag()
		get_viewport().set_input_as_handled()


func _is_mouse_inside_block() -> bool:
	if not _editing_object:
		return false
	var size: Vector2 = _get_block_size()
	var center: Vector2 = _editing_object.global_position
	var world_rect: Rect2 = Rect2(center - size * 0.5, size)
	var screen_rect: Rect2 = Rect2(
		_world_to_screen(world_rect.position),
		_world_to_screen(world_rect.position + world_rect.size) - _world_to_screen(world_rect.position)
	)
	return screen_rect.has_point(_get_screen_mouse_pos())


func _get_move_tool() -> LDToolMove:
	return get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


func _begin_drag(corner: int) -> void:
	_drag_corner = corner
	_drag_start_object_pos = _editing_object.global_position
	_drag_start_size = _get_block_size()
	set_cursor_shape(CORNER_CURSORS[corner])


func _drag_resize(mouse_pos: Vector2) -> void:
	if not _editing_object or _drag_corner < 0:
		return
	
	var snapping: float = LDViewport.SNAPPING_SIZE
	var opp: int = OPPOSITE_CORNER[_drag_corner]
	var fixed_world: Vector2 = _drag_start_object_pos + (CORNER_ANCHORS[opp] - Vector2(0.5, 0.5)) * _drag_start_size
	
	var new_size_x: float = maxf(snapping, snappedf(absf(mouse_pos.x - fixed_world.x), snapping))
	var new_size_y: float = maxf(snapping, snappedf(absf(mouse_pos.y - fixed_world.y), snapping))
	var new_center: Vector2 = Vector2(
		minf(fixed_world.x, mouse_pos.x) + new_size_x * 0.5,
		minf(fixed_world.y, mouse_pos.y) + new_size_y * 0.5,
	)
	
	_editing_object.global_position = new_center
	if _editing_object.has_property(&"b_size_x"):
		_editing_object.set_property(&"b_size_x", int(new_size_x))
	if _editing_object.has_property(&"b_size_y"):
		_editing_object.set_property(&"b_size_y", int(new_size_y))
	if _editing_object.has_property(&"position"):
		_editing_object.set_property(&"position", new_center)


func _end_drag() -> void:
	if not _editing_object or _drag_corner < 0:
		return
	
	var obj: LDObject = _editing_object
	var new_pos: Vector2 = obj.global_position
	var new_sx: int = int(obj.get_property(&"b_size_x")) if obj.has_property(&"b_size_x") else 0
	var new_sy: int = int(obj.get_property(&"b_size_y")) if obj.has_property(&"b_size_y") else 0
	var old_pos: Vector2 = _drag_start_object_pos
	var old_size: Vector2 = _drag_start_size
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Resize Block")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.global_position = new_pos
			if obj.has_property(&"b_size_x"):
				obj.set_property(&"b_size_x", new_sx)
			if obj.has_property(&"b_size_y"):
				obj.set_property(&"b_size_y", new_sy)
			if obj.has_property(&"position"):
				obj.set_property(&"position", new_pos)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.global_position = old_pos
			if obj.has_property(&"b_size_x"):
				obj.set_property(&"b_size_x", int(old_size.x))
			if obj.has_property(&"b_size_y"):
				obj.set_property(&"b_size_y", int(old_size.y))
			if obj.has_property(&"position"):
				obj.set_property(&"position", old_pos)
	)
	history.commit_action()
	
	_drag_corner = -1
	set_cursor_shape(Control.CURSOR_ARROW)
	_rebuild_handle_buttons()


func _cancel_drag() -> void:
	if not _editing_object or _drag_corner < 0:
		return
	
	_editing_object.global_position = _drag_start_object_pos
	if _editing_object.has_property(&"b_size_x"):
		_editing_object.set_property(&"b_size_x", int(_drag_start_size.x))
	if _editing_object.has_property(&"b_size_y"):
		_editing_object.set_property(&"b_size_y", int(_drag_start_size.y))
	if _editing_object.has_property(&"position"):
		_editing_object.set_property(&"position", _drag_start_object_pos)
	
	_drag_corner = -1
	set_cursor_shape(Control.CURSOR_ARROW)
	_rebuild_handle_buttons()


func _update_hover(screen_pos: Vector2) -> void:
	if not _editing_object or _drag_corner >= 0:
		return
	
	_hovered_corner = -1
	var corners: Array[Vector2] = _get_corner_screen_positions()
	for i: int in 4:
		if screen_pos.distance_to(corners[i]) <= HANDLE_GRAB_RADIUS:
			_hovered_corner = i
			set_cursor_shape(CORNER_CURSORS[i])
			_sync_handle_button_states()
			return
	
	set_cursor_shape(Control.CURSOR_ARROW)
	_sync_handle_button_states()


func _rebuild_handle_buttons() -> void:
	_clear_handle_buttons()
	if not _editing_object:
		return
	
	var overlay: Control = viewport.get_selection_overlay()
	var half: float = HANDLE_BUTTON_SIZE * 0.5
	var corners: Array[Vector2] = _get_corner_screen_positions()
	for i: int in 4:
		var btn: Button = Button.new()
		btn.theme_type_variation = &"PolyVertex"
		btn.custom_minimum_size = Vector2(HANDLE_BUTTON_SIZE, HANDLE_BUTTON_SIZE)
		btn.size = Vector2(HANDLE_BUTTON_SIZE, HANDLE_BUTTON_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.position = corners[i] - Vector2(half, half)
		overlay.add_child(btn)
		_handle_buttons.append(btn)


func _clear_handle_buttons() -> void:
	for btn: Button in _handle_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_handle_buttons.clear()


func _sync_handle_buttons() -> void:
	if not _editing_object:
		return
	var corners: Array[Vector2] = _get_corner_screen_positions()
	var half: float = HANDLE_BUTTON_SIZE * 0.5
	for i: int in mini(_handle_buttons.size(), 4):
		_handle_buttons[i].position = corners[i] - Vector2(half, half)


func _sync_handle_button_states() -> void:
	for i: int in _handle_buttons.size():
		_handle_buttons[i].set_pressed_no_signal(i == _hovered_corner)


func _get_block_size() -> Vector2:
	var sx: float = float(_editing_object.get_property(&"b_size_x") if _editing_object.has_property(&"b_size_x") else LDViewport.SNAPPING_SIZE)
	var sy: float = float(_editing_object.get_property(&"b_size_y") if _editing_object.has_property(&"b_size_y") else LDViewport.SNAPPING_SIZE)
	return Vector2(sx, sy)


func _get_corner_screen_positions() -> Array[Vector2]:
	var size: Vector2 = _get_block_size()
	var center: Vector2 = _editing_object.global_position
	var corners: Array[Vector2] = []
	for i: int in 4:
		corners.append(_world_to_screen(center + (CORNER_ANCHORS[i] - Vector2(0.5, 0.5)) * size))
	return corners


func _is_block(obj: LDObject) -> bool:
	return obj != null and (obj.has_property(&"b_size_x") or obj.has_property(&"b_size_y"))


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform * world_pos


func _get_screen_mouse_pos() -> Vector2:
	return viewport.get_selection_overlay().get_local_mouse_position()


func _get_snapped_mouse_pos() -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return (full_transform.affine_inverse() * _get_screen_mouse_pos()).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
