extends LDTool

const MIN_POINT_DISTANCE: float = 8.0

var _active_object: LDObjectPath
var _points: PackedVector2Array
var _cursor_pos: Vector2
var _head_placed: bool = false
var _is_valid: bool = false


func get_tool_name() -> String:
	return "Path"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_enable() -> void:
	super()
	set_cursor_shape(Control.CURSOR_CROSS)
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj and _is_path_object(obj):
		_begin_path(obj)


func _on_disable() -> void:
	_cancel_path()
	super()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	
	match event.keycode:
		KEY_ENTER:
			if _head_placed and _points.size() >= 2:
				var commit_points: PackedVector2Array = _points.duplicate()
				if _cursor_pos != Vector2.ZERO and (commit_points.is_empty() or commit_points[commit_points.size() - 1] != _cursor_pos):
					if _check_min_distance_all(_cursor_pos, commit_points):
						commit_points.append(_cursor_pos)
				if commit_points.size() >= 2:
					_points = commit_points
					_commit_path()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_cancel_path()
			get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			_remove_last_point()
			get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		_cursor_pos = _get_snapped_mouse_pos()
		if not _head_placed and _active_object:
			_active_object.apply_points(PackedVector2Array([_cursor_pos]))
		elif _head_placed and _active_object:
			_update_preview()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if viewport.is_panning():
			return
		var pos: Vector2 = _get_snapped_mouse_pos()
		if not _head_placed:
			_place_head(pos)
		else:
			if _check_min_distance_all(pos, _points):
				_add_point(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _head_placed:
			_cancel_path()
		elif _points.size() >= 2:
			_commit_path()
		else:
			_cancel_path()


func _check_min_distance_all(pos: Vector2, against: PackedVector2Array) -> bool:
	for existing: Vector2 in against:
		if existing.distance_to(pos) < MIN_POINT_DISTANCE:
			return false
	return true


func _on_object_changed(obj: GameObject) -> void:
	_cancel_path()
	if not is_active():
		return
	if not _is_path_object(obj):
		return
	_begin_path(obj)


func _begin_path(obj: GameObject) -> void:
	if not obj.ld_editor_instance:
		return
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	if not instance is LDObjectPath:
		instance.queue_free()
		return
	_active_object = instance as LDObjectPath
	_active_object.is_preview = true
	_active_object.init_properties(obj)
	viewport.add_object(_active_object)
	_points = PackedVector2Array()
	_head_placed = false
	_is_valid = false
	if _cursor_pos != Vector2.ZERO:
		_active_object.apply_points(PackedVector2Array([_cursor_pos]))


func _place_head(pos: Vector2) -> void:
	if not _active_object:
		return
	_points.append(pos)
	_head_placed = true
	_update_preview()


func _add_point(pos: Vector2) -> void:
	if not _active_object:
		return
	_points.append(pos)
	_update_preview()


func _remove_last_point() -> void:
	if not _head_placed:
		return
	if _points.size() <= 1:
		_points.clear()
		_head_placed = false
		if _active_object and _cursor_pos != Vector2.ZERO:
			_active_object.apply_points(PackedVector2Array([_cursor_pos]))
		return
	_points.resize(_points.size() - 1)
	_update_preview()


func _update_preview() -> void:
	if not _active_object:
		return
	
	var preview_points: PackedVector2Array = _points.duplicate()
	if _head_placed and _cursor_pos != Vector2.ZERO:
		if preview_points.is_empty() or preview_points[preview_points.size() - 1] != _cursor_pos:
			preview_points.append(_cursor_pos)
	
	_is_valid = preview_points.size() >= 2
	_active_object.set_preview_valid(_is_valid)
	_active_object.apply_points(preview_points)


func _commit_path() -> void:
	if not _active_object or _points.size() < 2:
		return
	
	var local_points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _points:
		local_points.append(_active_object.to_local(p))
	
	_active_object.apply_points(local_points)
	_active_object.set_preview_valid(true)
	
	var placed: LDObjectPath = _active_object
	var parent: Node = placed.get_parent()
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Path")
	history.add_do(func() -> void:
		if is_instance_valid(placed) and not placed.is_inside_tree():
			parent.add_child(placed)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(placed) and placed.is_inside_tree():
			viewport.clear_selection()
			placed.get_parent().remove_child(placed)
	)
	history.commit_action()
	
	placed.place()
	_active_object = null
	_points = PackedVector2Array()
	_head_placed = false
	_is_valid = false
	
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj:
		_begin_path(obj)


func _cancel_path() -> void:
	if is_instance_valid(_active_object):
		_active_object.queue_free()
		_active_object = null
	_points = PackedVector2Array()
	_head_placed = false
	_is_valid = false


func _is_path_object(obj: GameObject) -> bool:
	if not obj or not obj.ld_editor_instance:
		return false
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	var result: bool = instance is LDObjectPath
	instance.queue_free()
	return result


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
