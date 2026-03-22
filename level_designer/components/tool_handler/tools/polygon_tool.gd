extends LDTool

const MIN_POINT_DISTANCE: float = 8.0

var _active_object: LDObjectPolygon
var _points: PackedVector2Array
var _cursor_pos: Vector2
var _is_valid: bool = false


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
	set_cursor_shape(Control.CURSOR_CROSS)
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
			var commit_points: PackedVector2Array = _points.duplicate()
			if _cursor_pos != Vector2.ZERO and (commit_points.is_empty() or commit_points[commit_points.size() - 1] != _cursor_pos):
				var test_points: PackedVector2Array = commit_points.duplicate()
				test_points.append(_cursor_pos)
				if test_points.size() >= 3 and _check_valid(test_points):
					commit_points.append(_cursor_pos)
			if commit_points.size() >= 3 and _check_valid(commit_points):
				_points = commit_points
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
	
	if event is InputEventMouseMotion:
		_cursor_pos = _get_snapped_mouse_pos()
		if _active_object:
			_update_preview()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not viewport.is_panning():
				var pos: Vector2 = _get_snapped_mouse_pos()
				var test_points: PackedVector2Array = _points.duplicate()
				test_points.append(pos)
				if _check_valid(test_points) and _check_min_distance(pos):
					_add_point(pos)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _points.size() >= 3 and _is_valid:
				_commit_polygon()
			else:
				_cancel_polygon()


func _check_min_distance(pos: Vector2) -> bool:
	for existing: Vector2 in _points:
		if existing.distance_to(pos) < MIN_POINT_DISTANCE:
			return false
	return true


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
	_active_object.init_properties(obj)
	viewport.add_object(_active_object)
	_points = PackedVector2Array()
	_is_valid = false
	set_cursor_shape(Control.CURSOR_CROSS)


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
	
	_is_valid = preview_points.size() < 3 or _check_valid(preview_points)
	_active_object.set_preview_valid(_is_valid)
	_active_object.apply_points(preview_points)


func _commit_polygon() -> void:
	if not _active_object or _points.size() < 3:
		return
	if not _check_valid(_points):
		return
	
	var local_points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _points:
		local_points.append(_active_object.to_local(p))
	
	_active_object.apply_points(local_points)
	_active_object.set_preview_valid(true)
	
	var placed: LDObjectPolygon = _active_object
	var parent: Node = placed.get_parent()
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Polygon")
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
	_is_valid = false
	
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj:
		_begin_polygon(obj)


func _cancel_polygon() -> void:
	if _active_object:
		_active_object.queue_free()
		_active_object = null
	_points = PackedVector2Array()
	_is_valid = false


func _check_valid(points: PackedVector2Array) -> bool:
	var count: int = points.size()
	if count < 2:
		return true
	
	for i: int in count:
		var a1: Vector2 = points[i]
		var a2: Vector2 = points[(i + 1) % count]
		for j: int in range(i + 2, count):
			if j == count - 1 and i == 0:
				continue
			var b1: Vector2 = points[j]
			var b2: Vector2 = points[(j + 1) % count]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return false
	
	return true


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
