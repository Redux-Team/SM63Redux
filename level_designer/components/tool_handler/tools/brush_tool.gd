extends LDTool


var _preview_cursor: LDObject
var _stroke: Array[LDObject] = []
var _stroke_origin: Vector2
var _last_cell_x: int = 0
var _last_cell_y: Dictionary[int, float] = {}
var _column_objects: Dictionary[int, Array] = {}
var _is_painting: bool = false
var _cached_stamp_size: Vector2 = Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)


func get_tool_name() -> String:
	return "Brush"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	get_tool_handler().select_tool(self)
	
	LD.get_editor_viewport().viewport_moved.connect(_on_viewport_moved)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	
	viewport.touch_tap.connect(_on_touch_tap)
	viewport.touch_swipe_began.connect(_on_touch_swipe_began)
	viewport.touch_swipe_moved.connect(_on_touch_swipe_moved)
	viewport.touch_swipe_ended.connect(_on_touch_swipe_ended)
	
	Singleton.input_type_changed.connect(_on_input_type_changed)
	
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_enable() -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	_on_object_changed(obj)


func _on_disable() -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	_clear_stroke()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	
	if event is InputEventMouseMotion:
		var pos: Vector2 = _get_snapped_mouse_pos()
		if _preview_cursor:
			_preview_cursor.position = pos
		if _is_painting and not viewport.is_panning():
			_stamp_line_to(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewport.is_panning():
				return
			_is_painting = true
			_stroke_origin = _get_snapped_mouse_pos()
			_column_objects.clear()
			_last_cell_x = _pos_to_cell_x(_stroke_origin)
			_last_cell_y.clear()
			var start_pos: Vector2 = Vector2(_cell_x_to_pos(_last_cell_x), _stroke_origin.y)
			_add_stroke_preview(start_pos)
			if not _column_objects.has(_last_cell_x):
				_column_objects[_last_cell_x] = []
			_column_objects[_last_cell_x].append(start_pos.y)
		else:
			if _is_painting:
				_commit_stroke()
			_is_painting = false


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	_on_viewport_input(InputEventMouseMotion.new())


func _on_object_changed(obj: GameObject) -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	_clear_stroke()
	
	if not obj:
		return
	
	if _is_telescoping_object(obj):
		get_tool_handler().select_tool.call_deferred("telescoping")
		return
	
	if Singleton.current_input_device != Singleton.InputType.TOUCHSCREEN:
		_spawn_cursor(obj)
	else:
		_cache_stamp_size(obj)


func _is_telescoping_object(obj: GameObject) -> bool:
	if not obj:
		return false
	return obj.has_property(&"t_size_x") or obj.has_property(&"t_size_y")


func _cache_stamp_size(obj: GameObject) -> void:
	if not obj or not obj.ld_editor_instance:
		_cached_stamp_size = Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
		return
	var temp: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	_cached_stamp_size = temp.get_stamp_size()
	temp.free()


func _spawn_cursor(obj: GameObject) -> void:
	if not obj.ld_editor_instance:
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	_preview_cursor = obj.ld_editor_instance.instantiate() as LDObject
	_preview_cursor.is_preview = true
	_preview_cursor.init_properties(obj.ld_properties)
	LD.get_editor_viewport().add_object(_preview_cursor)


func _get_stamp_size() -> Vector2:
	if _preview_cursor:
		return _preview_cursor.get_stamp_size()
	return _cached_stamp_size


func _stamp_line_to(pos: Vector2) -> void:
	var target_cell_x: int = _pos_to_cell_x(pos)
	var stamp_size: Vector2 = _get_stamp_size()

	if target_cell_x == _last_cell_x:
		var stamp_pos: Vector2 = Vector2(_cell_x_to_pos(target_cell_x), pos.y)
		var last_y: float = _last_cell_y.get(target_cell_x, pos.y - INF)
		if absf(pos.y - last_y) >= stamp_size.y and not _column_has_overlap(target_cell_x, pos.y):
			_add_stroke_preview(stamp_pos)
			if not _column_objects.has(target_cell_x):
				_column_objects[target_cell_x] = []
			_column_objects[target_cell_x].append(pos.y)
			_last_cell_y[target_cell_x] = pos.y
		return

	for cell_x: int in _columns_between(_last_cell_x, target_cell_x):
		var stamp_pos: Vector2 = Vector2(_cell_x_to_pos(cell_x), pos.y)
		if not _column_has_overlap(cell_x, stamp_pos.y):
			_add_stroke_preview(stamp_pos)
			if not _column_objects.has(cell_x):
				_column_objects[cell_x] = []
			_column_objects[cell_x].append(stamp_pos.y)
			_last_cell_y[cell_x] = stamp_pos.y

	_last_cell_x = target_cell_x


func _add_stroke_preview(pos: Vector2) -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if not obj or not obj.ld_editor_instance:
		return
	
	var preview: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	preview.is_preview = true
	LD.get_editor_viewport().add_object(preview, Vector2i(pos))
	preview.init_properties(obj.ld_properties)
	if obj.has_property(&"position"):
		preview.set_property(&"position", pos)
	_stroke.append(preview)


func _commit_stroke() -> void:
	if _stroke.is_empty():
		return
	
	for obj: LDObject in _stroke:
		obj.place()
	
	var placed: Array[LDObject] = _stroke.duplicate()
	var history: LDHistoryHandler = LD.get_history_handler()
	
	history.begin_action("Place Objects")
	history.add_do(func() -> void:
		for obj: LDObject in placed:
			if is_instance_valid(obj):
				obj.show()
	)
	history.add_undo(func() -> void:
		for obj: LDObject in placed:
			if is_instance_valid(obj):
				obj.hide()
	)
	history.commit_action()
	
	_stroke.clear()
	_column_objects.clear()
	_last_cell_y.clear()


func _clear_stroke() -> void:
	for obj: LDObject in _stroke:
		obj.queue_free()
	_stroke.clear()
	_column_objects.clear()
	_last_cell_y.clear()


func _column_has_overlap(cell_x: int, y: float) -> bool:
	if not _column_objects.has(cell_x):
		return false
	var stamp_size: Vector2 = _get_stamp_size()
	for existing_y: float in _column_objects[cell_x]:
		if absf(y - existing_y) < stamp_size.y:
			return true
	return false


func _pos_to_cell_x(pos: Vector2) -> int:
	var stamp_size: Vector2 = _get_stamp_size()
	return floori((pos.x - _stroke_origin.x) / stamp_size.x)


func _cell_x_to_pos(cell_x: int) -> float:
	var stamp_size: Vector2 = _get_stamp_size()
	return _stroke_origin.x + cell_x * stamp_size.x


func _columns_between(from_x: int, to_x: int) -> Array[int]:
	var columns: Array[int] = []
	var step: int = 1 if to_x > from_x else -1
	var x: int = from_x
	while x != to_x + step:
		columns.append(x)
		x += step
	return columns


func _get_snapped_mouse_pos() -> Vector2:
	return LD.get_editor_viewport().get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))


func _screen_to_world(pos: Vector2) -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform.affine_inverse() * pos


func _on_touch_tap(pos: Vector2) -> void:
	if not is_active():
		return
	var world_pos: Vector2 = _screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_stroke_origin = world_pos
	_column_objects.clear()
	_last_cell_x = _pos_to_cell_x(world_pos)
	_last_cell_y.clear()
	var start_pos: Vector2 = Vector2(_cell_x_to_pos(_last_cell_x), world_pos.y)
	_add_stroke_preview(start_pos)
	if not _column_objects.has(_last_cell_x):
		_column_objects[_last_cell_x] = []
	_column_objects[_last_cell_x].append(start_pos.y)
	_commit_stroke()


func _on_touch_swipe_began(pos: Vector2) -> void:
	if not is_active():
		return
	var world_pos: Vector2 = _screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_is_painting = true
	_stroke_origin = world_pos
	_column_objects.clear()
	_last_cell_x = _pos_to_cell_x(world_pos)
	_last_cell_y.clear()
	var start_pos: Vector2 = Vector2(_cell_x_to_pos(_last_cell_x), world_pos.y)
	_add_stroke_preview(start_pos)
	if not _column_objects.has(_last_cell_x):
		_column_objects[_last_cell_x] = []
	_column_objects[_last_cell_x].append(start_pos.y)


func _on_touch_swipe_moved(pos: Vector2) -> void:
	if not is_active() or not _is_painting:
		return
	var world_pos: Vector2 = _screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_stamp_line_to(world_pos)


func _on_touch_swipe_ended() -> void:
	if not is_active():
		return
	if _is_painting:
		_commit_stroke()
	_is_painting = false


func _on_input_type_changed() -> void:
	if not is_active():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		if _preview_cursor:
			_preview_cursor.queue_free()
			_preview_cursor = null
		var obj: GameObject = LD.get_object_handler().get_selected_object()
		if obj:
			_cache_stamp_size(obj)
	else:
		var obj: GameObject = LD.get_object_handler().get_selected_object()
		if obj:
			_spawn_cursor(obj)
