extends LDTool

var _active_object: LDObject
var _origin: Vector2
var _is_dragging: bool = false


func get_tool_name() -> String:
	return "Block"


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
	if obj:
		_spawn_block_preview(obj)


func _on_disable() -> void:
	_cancel()
	super()


func _on_object_changed(obj: GameObject) -> void:
	_cancel()
	if not is_active():
		return
	if obj:
		_spawn_block_preview(obj)


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		var pos: Vector2 = _get_snapped_mouse_pos()
		if not _is_dragging:
			if _active_object:
				var default_x: float = float(_active_object.get_property(&"b_size_x") if _active_object.has_property(&"b_size_x") else LDViewport.SNAPPING_SIZE)
				var default_y: float = float(_active_object.get_property(&"b_size_y") if _active_object.has_property(&"b_size_y") else LDViewport.SNAPPING_SIZE)
				_active_object.position = pos + Vector2(default_x, default_y) * 0.5
		else:
			_update_block(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewport.is_panning():
				return
			if not _is_dragging:
				_origin = _get_snapped_mouse_pos()
				_is_dragging = true
				if _active_object:
					_active_object.position = _origin
				_update_block(_origin)
		else:
			if _is_dragging:
				_commit()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()


func _spawn_block_preview(obj: GameObject) -> void:
	_active_object = spawn_preview(obj)
	_is_dragging = false
	if _active_object:
		_active_object.position = _get_snapped_mouse_pos()


func _update_block(pos: Vector2) -> void:
	if not _active_object:
		return
	
	var delta: Vector2 = pos - _origin
	var snapping: float = LDViewport.SNAPPING_SIZE
	
	var size_x: float = maxf(snapping, snappedf(absf(delta.x), snapping))
	var size_y: float = maxf(snapping, snappedf(absf(delta.y), snapping))
	
	var anchor: Vector2 = Vector2(
		_origin.x if delta.x >= 0.0 else _origin.x - size_x + snapping,
		_origin.y if delta.y >= 0.0 else _origin.y - size_y + snapping
	)
	
	var center: Vector2 = anchor + Vector2(size_x, size_y) * 0.5
	_active_object.position = center
	
	if _active_object.has_property(&"b_size_x"):
		_active_object.set_property(&"b_size_x", int(size_x))
	if _active_object.has_property(&"b_size_y"):
		_active_object.set_property(&"b_size_y", int(size_y))


func _commit() -> void:
	if not _active_object:
		return
	
	var placed: LDObject = release_preview()
	var parent: Node = placed.get_parent()
	
	if placed.has_property(&"position"):
		placed.set_property(&"position", placed.global_position)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Block")
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
	_is_dragging = false
	
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj:
		_spawn_block_preview(obj)


func _cancel() -> void:
	_destroy_preview()
	_active_object = null
	_is_dragging = false


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
