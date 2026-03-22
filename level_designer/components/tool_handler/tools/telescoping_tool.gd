extends LDTool


var _sizing_object: LDObjectTelescoping
var _sizing_anchor_left: Vector2
var _sizing_anchor_right: Vector2
var _sizing_dir: float = 1.0
var _is_sizing: bool = false
var _preview_cursor: LDObjectTelescoping


func get_tool_name() -> String:
	return "Telescoping"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_HSIZE


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_enable() -> void:
	super()
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if obj and _is_telescoping_object(obj):
		_spawn_cursor(obj)


func _on_disable() -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	if _is_sizing:
		_cancel_sizing()
	super()


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
		if _is_sizing:
			_update_sizing(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not viewport.is_panning():
			_begin_sizing(_get_snapped_mouse_pos())
		elif not event.pressed and _is_sizing:
			_commit_sizing()


func _on_object_changed(obj: GameObject) -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null
	if not is_active():
		return
	if not _is_telescoping_object(obj):
		get_tool_handler().select_tool.call_deferred("brush")
		return
	_spawn_cursor(obj)


func _spawn_cursor(obj: GameObject) -> void:
	if not obj.ld_editor_instance:
		return
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	if not instance is LDObjectTelescoping:
		instance.queue_free()
		return
	_preview_cursor = instance as LDObjectTelescoping
	_preview_cursor.is_preview = true
	_preview_cursor.init_properties(obj)
	viewport.add_object(_preview_cursor)


func _begin_sizing(pos: Vector2) -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if not obj or not obj.ld_editor_instance:
		return
	
	var instance: LDObject = obj.ld_editor_instance.instantiate() as LDObject
	if not instance is LDObjectTelescoping:
		instance.queue_free()
		return
	
	_sizing_object = instance as LDObjectTelescoping
	_sizing_object.is_preview = true
	_sizing_object.init_properties(obj)
	viewport.add_object(_sizing_object, Vector2i(pos))
	if obj.has_property(&"position"):
		_sizing_object.set_property(&"position", pos)
	
	var half_caps: float = _sizing_object.get_end_collision_width() / 2.0
	_sizing_anchor_left = Vector2(pos.x - half_caps, pos.y)
	_sizing_anchor_right = Vector2(pos.x + half_caps, pos.y)
	_sizing_dir = 1.0
	_is_sizing = true
	
	if _preview_cursor:
		_preview_cursor.visible = false


func _update_sizing(pos: Vector2) -> void:
	if not _sizing_object:
		return
	
	if _sizing_object.is_telescoping_x():
		var anchor: Vector2 = _sizing_anchor_left if _sizing_dir >= 0.0 else _sizing_anchor_right
		var delta_x: float = pos.x - anchor.x
		if delta_x != 0.0:
			_sizing_dir = signf(delta_x)
			anchor = _sizing_anchor_left if _sizing_dir >= 0.0 else _sizing_anchor_right
		var seg: float = float(_sizing_object.get_middle_segment_width())
		var raw_units: int = int(absf(delta_x) / seg)
		var clamped_units: int = _sizing_object.clamp_units(raw_units)
		_sizing_object.set_property(&"t_size_x", clamped_units)
		var total: float = _sizing_object.get_total_width(raw_units)
		_sizing_object.position.x = anchor.x + (total / 2.0) * _sizing_dir
	
	if _sizing_object.is_telescoping_y():
		var anchor: Vector2 = _sizing_anchor_left if _sizing_dir >= 0.0 else _sizing_anchor_right
		var delta_y: float = pos.y - anchor.y
		if delta_y != 0.0:
			_sizing_dir = signf(delta_y)
			anchor = _sizing_anchor_left if _sizing_dir >= 0.0 else _sizing_anchor_right
		var seg: float = float(_sizing_object.get_middle_segment_width())
		var raw_units: int = int(absf(delta_y) / seg)
		var clamped_units: int = _sizing_object.clamp_units(raw_units)
		_sizing_object.set_property(&"t_size_y", clamped_units)
		var total: float = _sizing_object.get_total_height(raw_units)
		_sizing_object.position.y = anchor.y + (total / 2.0) * _sizing_dir


func _commit_sizing() -> void:
	if not _sizing_object:
		return
	
	var placed: LDObjectTelescoping = _sizing_object
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Telescoping Object")
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
	_sizing_object = null
	_is_sizing = false
	
	if _preview_cursor:
		_preview_cursor.visible = true


func _cancel_sizing() -> void:
	if _sizing_object:
		_sizing_object.queue_free()
		_sizing_object = null
	_is_sizing = false
	if _preview_cursor:
		_preview_cursor.visible = true


func _is_telescoping_object(obj: GameObject) -> bool:
	return obj != null and (obj.has_property(&"t_size_x") or obj.has_property(&"t_size_y"))


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
