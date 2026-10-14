@abstract class_name LDWidgetTool
extends LDTool

const DOUBLE_CLICK_TIME: float = 0.4
const DRAG_THRESHOLD: float = 3.0

@export var select_tool: LDSelectTool

var targets: Array[GameObject] = []
var _handles: Dictionary[Variant, LDHandle] = {}
var _hovered: LDHandle
var _pressed: LDHandle
var _press_screen: Vector2
var _moved: bool = false
var _forwarding: bool = false
var _last_click_key: Variant
var _last_click_time: float = -INF


@abstract func _get_targets(objects: Array[GameObject]) -> Array[GameObject]
@abstract func _layout_handles() -> void


func _setup() -> void:
	editor.object_handler.selection.changed.connect(refresh)
	editor.history_handler.changed.connect(_on_history_changed)


func _activate() -> void:
	refresh()


func _deactivate() -> void:
	if _pressed:
		_release()
	_forwarding = false
	editor.viewport_handler.set_cursor(cursor)


func _cancel() -> void:
	if _pressed:
		var handle: LDHandle = _pressed
		_pressed = null
		_on_handle_cancelled(handle)


func _input(event: InputEvent) -> void:
	if is_active() and _pressed and editor.is_shortcut(event, &"ld_back"):
		_cancel()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_active() and _hovered and not _pressed and editor.is_shortcut(event, &"ld_delete") and _on_handle_deleted(_hovered):
		_hovered = null
		get_viewport().set_input_as_handled()


func _tool_input(event: InputEvent, world_position: Vector2) -> bool:
	if _forwarding or targets.is_empty():
		return _forward(event, world_position)
	
	if event is InputEventMouseMotion:
		if _pressed == null:
			_update_hover()
			return false
		
		_moved = _moved or (event as InputEventMouseMotion).position.distance_to(_press_screen) > DRAG_THRESHOLD
		if _moved:
			_on_handle_dragged(_pressed, world_position)
		return true
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null:
		return false
	
	if _pressed:
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
		elif not mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_release()
		return true
	
	if not mouse_button.pressed:
		return false
	
	_update_hover()
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		return _hovered != null and _on_handle_deleted(_hovered)
	
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	
	if _hovered and _hovered.enabled:
		if _hovered.key == _last_click_key and Time.get_ticks_msec() / 1000.0 - _last_click_time <= DOUBLE_CLICK_TIME:
			_last_click_key = null
			_on_handle_reset(_hovered)
		else:
			press_handle(_hovered, mouse_button.position)
		return true
	
	if _on_empty_pressed(world_position, mouse_button.position):
		return true
	
	_forwarding = true
	return _forward(event, world_position)


func continue_forwarding() -> void:
	_forwarding = select_tool.move_tool.is_dragging()


func refresh() -> void:
	if _pressed:
		return
	
	targets.assign(_get_targets(editor.object_handler.selection.get_objects()))
	_handles.clear()
	_hovered = null
	if targets.is_empty() and is_active() and not _forwarding:
		_leave_if_empty.call_deferred()


func press_handle(handle: LDHandle, screen: Vector2) -> void:
	_pressed = handle
	_press_screen = screen
	_moved = false
	_on_handle_pressed(handle)


func place_handle(key: Variant, world: Vector2, style: LDHandleStyle) -> LDHandle:
	var handle: LDHandle = _handles.get(key)
	if handle == null or handle.style != style:
		handle = LDHandle.new(key, style)
		_handles.set(key, handle)
	
	handle.world = world
	handle.alive = true
	return handle


func get_handle(key: Variant) -> LDHandle:
	return _handles.get(key)


func is_hovered(key: Variant) -> bool:
	return _hovered != null and _hovered.key == key


func is_pressed(key: Variant) -> bool:
	return _pressed != null and _pressed.key == key


func is_dragging() -> bool:
	return _pressed != null


func to_parent(object: GameObject, world_position: Vector2, snap: bool = true) -> Vector2:
	var local: Vector2 = (object.get_parent() as Node2D).get_global_transform().affine_inverse() * world_position
	return editor.viewport_handler.snap(local) if snap else local


func screen_distance(world_a: Vector2, world_b: Vector2) -> float:
	return editor.viewport_handler.to_screen(world_a).distance_to(editor.viewport_handler.to_screen(world_b))


func _draw_overlay(overlay: LDOverlay) -> void:
	if targets.is_empty():
		return
	
	_sync_handles()
	_draw_guides(overlay)
	var delta: float = get_process_delta_time()
	for handle: LDHandle in _handles.values():
		handle.draw(overlay.canvas, editor.viewport_handler.to_screen(handle.world), handle.get_state(handle == _hovered, handle == _pressed), delta)


func _draw_guides(_overlay: LDOverlay) -> void:
	pass


func _on_handle_pressed(_handle: LDHandle) -> void:
	pass


func _on_handle_dragged(_handle: LDHandle, _world_position: Vector2) -> void:
	pass


func _on_handle_released(_handle: LDHandle) -> void:
	pass


func _on_handle_cancelled(_handle: LDHandle) -> void:
	pass


func _on_handle_reset(_handle: LDHandle) -> void:
	pass


func _on_handle_deleted(_handle: LDHandle) -> bool:
	return false


func _on_empty_pressed(_world_position: Vector2, _screen: Vector2) -> bool:
	return false


func _release() -> void:
	var handle: LDHandle = _pressed
	_pressed = null
	if not _moved:
		_last_click_key = handle.key
		_last_click_time = Time.get_ticks_msec() / 1000.0
	_on_handle_released(handle)
	refresh()


func _sync_handles() -> void:
	for handle: LDHandle in _handles.values():
		handle.alive = false
	_layout_handles()
	for key: Variant in _handles.keys():
		if not _handles.get(key).alive:
			_handles.erase(key)


func _update_hover() -> void:
	_sync_handles()
	var mouse: Vector2 = editor.viewport_handler.to_screen(editor.viewport_handler.get_world_mouse())
	var nearest: float = INF
	_hovered = null
	for handle: LDHandle in _handles.values():
		var distance: float = editor.viewport_handler.to_screen(handle.world).distance_to(mouse)
		if distance <= handle.style.grab_radius and distance < nearest:
			nearest = distance
			_hovered = handle
	
	editor.viewport_handler.set_cursor(_hovered.cursor if _hovered else _get_idle_cursor())


func _get_idle_cursor() -> Control.CursorShape:
	return Control.CURSOR_POINTING_HAND if editor.viewport_handler.pick(editor.viewport_handler.get_world_mouse()) else cursor


func _forward(event: InputEvent, world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	var handled: bool = select_tool._tool_input(event, world_position)
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed and _forwarding:
		_forwarding = false
		refresh()
		if targets.is_empty() and is_active():
			editor.tool_handler.set_tool(select_tool)
	
	return handled


func _leave_if_empty() -> void:
	if targets.is_empty() and is_active() and not _forwarding:
		editor.tool_handler.set_tool(select_tool)


func _on_history_changed() -> void:
	if is_active():
		refresh()
