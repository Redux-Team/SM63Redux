class_name LDSelectTool
extends LDTool

@export var move_tool: LDMoveTool
@export var box_color: Color = Color(0.39, 0.59, 0.93, 0.2)
@export var box_outline_color: Color = Color(0.39, 0.59, 0.93, 0.8)

var _box_start: Vector2
var _box_end: Vector2
var _boxing: bool = false


func _deactivate() -> void:
	_boxing = false


func _cancel() -> void:
	_boxing = false
	move_tool._cancel()


func _tool_input(event: InputEvent, world_position: Vector2) -> bool:
	if move_tool.is_dragging():
		return move_tool.handle_drag(event, world_position)
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_press(mouse_button, world_position)
		else:
			_release(mouse_button)
		return true
	
	if event is InputEventMouseMotion and _boxing:
		_box_end = world_position
		return true
	
	return false


func _press(mouse_button: InputEventMouseButton, world_position: Vector2) -> void:
	var selection: LDSelection = editor.object_handler.selection
	var hit: GameObject = editor.viewport_handler.pick(world_position)
	if hit == null:
		_boxing = true
		_box_start = world_position
		_box_end = world_position
		if not (mouse_button.shift_pressed or mouse_button.ctrl_pressed):
			selection.clear()
		return
	
	if mouse_button.ctrl_pressed:
		selection.toggle(hit)
		return
	
	if mouse_button.shift_pressed:
		selection.add([hit])
	elif not selection.has(hit):
		selection.set_objects([hit])
	
	move_tool.begin_drag(world_position)


func _release(mouse_button: InputEventMouseButton) -> void:
	if not _boxing:
		return
	
	_boxing = false
	var found: Array[GameObject] = editor.viewport_handler.objects_in_rect(_get_box())
	if mouse_button.shift_pressed or mouse_button.ctrl_pressed:
		editor.object_handler.selection.add(found)
	else:
		editor.object_handler.selection.set_objects(found)


func _get_box() -> Rect2:
	return Rect2(_box_start, Vector2.ZERO).expand(_box_end)


func _draw_overlay(overlay: LDOverlay) -> void:
	if _boxing:
		overlay.draw_world_rect(_get_box(), box_color, true)
		overlay.draw_world_rect(_get_box(), box_outline_color)
