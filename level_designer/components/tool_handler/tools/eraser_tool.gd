extends LDTool

## Freeform eraser. Left-click-dragging marks any object under the cursor red; releasing the button
## deletes the marked objects, while pressing Escape cancels the pending deletion. The brush tool's
## right-drag erasing shares the same LDEraseStroke mechanic.


var _stroke: LDEraseStroke = LDEraseStroke.new()
var _is_erasing: bool = false


func get_tool_name() -> String:
	return "Eraser"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func _on_disable() -> void:
	_stroke.cancel()
	_is_erasing = false
	super()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventKey and event.is_pressed() and not event.echo and event.keycode == KEY_ESCAPE:
		if _is_erasing or not _stroke.is_empty():
			_stroke.cancel()
			_is_erasing = false
			get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if Singleton.get_input_handler().is_using_touch():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewport.is_panning():
				return
			_is_erasing = true
			_mark_at_cursor()
		elif _is_erasing:
			_is_erasing = false
			_stroke.commit()

	if event is InputEventMouseMotion and _is_erasing and not viewport.is_panning():
		_mark_at_cursor()


func _mark_at_cursor() -> void:
	_stroke.mark(_get_object_at(_get_overlay_mouse_pos()))
