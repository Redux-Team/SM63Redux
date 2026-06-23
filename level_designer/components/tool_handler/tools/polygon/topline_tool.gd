extends LDTool


const HANDLE_SIZE: float = 14.0
const GRAB_RADIUS: float = 12.0


var _editing_object: LDObjectPolygon
var _handles: Array[ColorRect] = []
var _edges: Array[Dictionary] = []


func get_tool_name() -> String:
	return "Topline"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)
	var history: LDHistoryHandler = LD.get_history_handler()
	if history and not history.history_changed.is_connected(_on_history_changed):
		history.history_changed.connect(_on_history_changed)


func _on_enable() -> void:
	super()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected[0] is LDObjectPolygon:
		_editing_object = selected[0] as LDObjectPolygon
		_rebuild_handles()
	else:
		get_tool_handler().select_tool("select")


func _on_disable() -> void:
	_editing_object = null
	_clear_handles()
	super()


func _on_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	if objects.size() == 1 and objects[0] is LDObjectPolygon:
		_editing_object = objects[0] as LDObjectPolygon
		_rebuild_handles()
	else:
		_editing_object = null
		_clear_handles()
		get_tool_handler().select_tool("select")


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if is_active():
		_sync_handles()


func _on_history_changed() -> void:
	if is_active() and _editing_object:
		_rebuild_handles()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or not _editing_object:
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var screen_mouse: Vector2 = _get_screen_mouse_pos()
		var global_xform: Transform2D = _editing_object.get_global_transform()
		var best: int = -1
		var best_dist: float = GRAB_RADIUS
		for i: int in _edges.size():
			var mid_screen: Vector2 = _world_to_screen(global_xform * (_edges[i].get("mid") as Vector2))
			var d: float = mid_screen.distance_to(screen_mouse)
			if d <= best_dist:
				best_dist = d
				best = i
		if best >= 0:
			_toggle_edge(best)
			viewport.get_viewport().set_input_as_handled()


func _toggle_edge(index: int) -> void:
	var edge: Dictionary = _edges[index]
	var key: String = edge.get("key")
	var old_state: bool = bool(edge.get("on"))
	var new_state: bool = not old_state
	var obj: LDObjectPolygon = _editing_object
	var had_key: bool = obj.get_topline_forced().has(key)
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Toggle Topline Edge")
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.toggle_topline_edge(key, new_state)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			if had_key:
				obj.toggle_topline_edge(key, old_state)
			else:
				obj.clear_topline_edge(key)
	)
	history.commit_action()
	obj.toggle_topline_edge(key, new_state)
	_rebuild_handles()


func _rebuild_handles() -> void:
	_clear_handles()
	if not _editing_object:
		return
	_edges = _editing_object.get_topline_edges()
	var overlay: Control = viewport.get_selection_overlay()
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = HANDLE_SIZE * 0.5
	for i: int in _edges.size():
		var handle: ColorRect = ColorRect.new()
		handle.custom_minimum_size = Vector2(HANDLE_SIZE, HANDLE_SIZE)
		handle.size = Vector2(HANDLE_SIZE, HANDLE_SIZE)
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		handle.color = Color(0.2, 0.9, 0.35, 0.85) if bool(_edges[i].get("on")) else Color(0.25, 0.25, 0.28, 0.7)
		var mid_screen: Vector2 = _world_to_screen(global_xform * (_edges[i].get("mid") as Vector2))
		handle.position = mid_screen - Vector2(half, half)
		overlay.add_child(handle)
		_handles.append(handle)


func _sync_handles() -> void:
	if not _editing_object:
		return
	var global_xform: Transform2D = _editing_object.get_global_transform()
	var half: float = HANDLE_SIZE * 0.5
	for i: int in mini(_handles.size(), _edges.size()):
		var mid_screen: Vector2 = _world_to_screen(global_xform * (_edges[i].get("mid") as Vector2))
		_handles[i].position = mid_screen - Vector2(half, half)


func _clear_handles() -> void:
	for handle: ColorRect in _handles:
		if is_instance_valid(handle):
			handle.queue_free()
	_handles.clear()
	_edges.clear()


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_transform * world_pos


func _get_screen_mouse_pos() -> Vector2:
	return viewport.get_selection_overlay().get_local_mouse_position()
