extends LDTool


var _active_object: LDObjectPolygon
var _points: PackedVector2Array
var _cursor_pos: Vector2


func get_tool_name() -> String:
	return "Polygon"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_enable() -> void:
	super()
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj and _is_polygon_object(obj):
		_begin_polygon(obj)


func _on_disable() -> void:
	_cancel_polygon()
	super()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	
	match event.keycode:
		KEY_ENTER:
			if _points.size() >= 3:
				_commit_polygon()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_cancel_polygon()
			get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			_remove_last_point()
			get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	
	if event is InputEventKey and event.is_pressed() and not event.echo:
		match event.keycode:
			KEY_ENTER:
				if _points.size() >= 3:
					_commit_polygon()
				return
			KEY_ESCAPE:
				_cancel_polygon()
				return
			KEY_BACKSPACE:
				_remove_last_point()
				return
	
	if event is InputEventMouseMotion:
		_cursor_pos = _get_snapped_mouse_pos()
		if _active_object:
			_update_preview()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not viewport.is_panning():
				_add_point(_get_snapped_mouse_pos())
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _points.size() >= 3:
				_commit_polygon()
			else:
				_cancel_polygon()


func _on_object_changed(obj: GameObject) -> void:
	_cancel_polygon()
	if not is_active():
		return
	if not _is_polygon_object(obj):
		get_tool_handler().select_tool("brush")
		return
	_begin_polygon(obj)


func _begin_polygon(obj: GameObject) -> void:
	if not obj.ld_editor_instance:
		return
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	if not instance is LDObjectPolygon:
		instance.queue_free()
		return
	_active_object = instance as LDObjectPolygon
	_active_object.is_preview = true
	_active_object.init_properties(obj.ld_properties)
	viewport.add_object(_active_object)
	_points = PackedVector2Array()


func _add_point(pos: Vector2) -> void:
	if not _active_object:
		return
	_points.append(pos)
	_update_preview()


func _remove_last_point() -> void:
	if _points.is_empty():
		return
	_points.resize(_points.size() - 1)
	_update_preview()


func _update_preview() -> void:
	if not _active_object:
		return
	var preview_points: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview_points.is_empty() or preview_points[preview_points.size() - 1] != _cursor_pos):
		preview_points.append(_cursor_pos)
	_active_object.apply_points(preview_points)


func _commit_polygon() -> void:
	if not _active_object or _points.size() < 3:
		return
	
	var local_points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _points:
		local_points.append(_active_object.to_local(p))
	
	_active_object.apply_points(local_points)
	
	var placed: LDObjectPolygon = _active_object
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Polygon")
	history.add_do(func() -> void:
		if is_instance_valid(placed):
			placed.show()
	)
	history.add_undo(func() -> void:
		if is_instance_valid(placed):
			placed.hide()
	)
	history.commit_action()
	
	placed.place()
	_active_object = null
	_points = PackedVector2Array()
	
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj:
		_begin_polygon(obj)


func _cancel_polygon() -> void:
	if _active_object:
		_active_object.queue_free()
		_active_object = null
	_points = PackedVector2Array()


func _get_closed_points(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	return closed


func _is_polygon_object(obj: GameObject) -> bool:
	if not obj or not obj.ld_editor_instance:
		return false
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	var result: bool = instance is LDObjectPolygon
	instance.queue_free()
	return result


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
