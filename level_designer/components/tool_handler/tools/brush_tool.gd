extends LDTool


var _preview_cursor: LDObject
var _stroke: Array[LDObject] = []
var _stroke_origin: Vector2
var _last_cell_x: int = 0
var _last_cell_y: Dictionary[int, float] = {}
var _column_objects: Dictionary[int, Array] = {}
var _is_painting: bool = false


func get_tool_name() -> String:
	return "Brush"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	get_tool_handler().select_tool(self)
	
	LD.get_editor_viewport().viewport_moved.connect(_on_viewport_moved)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_enable() -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj:
		_spawn_cursor(obj)


func _on_disable() -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	_clear_stroke()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	
	if event is InputEventMouseMotion:
		var pos: Vector2 = _get_snapped_mouse_pos()
		if _preview_cursor:
			_preview_cursor.position = pos
		if _is_painting:
			_stamp_line_to(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_painting = true
			_stroke_origin = _get_snapped_mouse_pos()
			_last_cell_x = _pos_to_cell_x(_stroke_origin)
			var start_pos: Vector2 = Vector2(_cell_x_to_pos(_last_cell_x), _stroke_origin.y)
			_add_stroke_preview(start_pos)
			if not _column_objects.has(_last_cell_x):
				_column_objects[_last_cell_x] = []
			_column_objects[_last_cell_x].append(start_pos.y)
		else:
			_commit_stroke()
			_is_painting = false


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	_on_viewport_input(InputEventMouseMotion.new())


func _on_object_changed(obj: GameObject) -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	_clear_stroke()
	if not is_active():
		return
	_spawn_cursor(obj)


func _spawn_cursor(obj: GameObject) -> void:
	if not obj.ld_editor_instance:
		return
	_preview_cursor = obj.ld_editor_instance.instantiate() as LDObject
	_preview_cursor.is_preview = true
	LD.get_editor_viewport().add_object(_preview_cursor)
	_preview_cursor.init_properties(obj.ld_properties)


func _stamp_line_to(pos: Vector2) -> void:
	var target_cell_x: int = _pos_to_cell_x(pos)
	
	if target_cell_x == _last_cell_x:
		var stamp_pos: Vector2 = Vector2(_cell_x_to_pos(target_cell_x), pos.y)
		var last_y: float = _last_cell_y.get(target_cell_x, pos.y - INF)
		var stamp_size: Vector2 = _preview_cursor.get_stamp_size() if _preview_cursor else Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
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
	var stamp_size: Vector2 = _preview_cursor.get_stamp_size() if _preview_cursor else Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	for existing_y: float in _column_objects[cell_x]:
		if absf(y - existing_y) < stamp_size.y:
			return true
	return false


func _pos_to_cell_x(pos: Vector2) -> int:
	var stamp_size: Vector2 = _preview_cursor.get_stamp_size() if _preview_cursor else Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return floori((pos.x - _stroke_origin.x) / stamp_size.x)


func _cell_x_to_pos(cell_x: int) -> float:
	var stamp_size: Vector2 = _preview_cursor.get_stamp_size() if _preview_cursor else Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
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
