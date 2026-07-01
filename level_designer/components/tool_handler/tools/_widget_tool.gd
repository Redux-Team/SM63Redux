@abstract class_name LDWidgetTool
extends LDTool


## Shared base for tools that drive an LDToolWidget over the current selection
## (Rotate, Scale, TelescopingEdit). Subclasses only declare their name and which
## of the selected objects they apply to via _get_target_objects().


@export var _widget: LDToolWidget


@abstract func _get_target_objects() -> Array[LDObject]


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func wants_overlay() -> bool:
	return true


func _on_enable() -> void:
	super()
	var objects: Array[LDObject] = _get_target_objects()
	if objects.is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.activate(self, objects)


func _on_disable() -> void:
	_widget.deactivate()
	super()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or get_viewport().is_input_handled():
		return
	if _get_target_objects().is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.on_input(event)


func draw_overlay(draw_node: CanvasItem) -> void:
	if not is_active():
		return
	_widget.draw_overlay(draw_node)


func _on_overlay_selection_changed(_objects: Array[LDObject]) -> void:
	if not is_active():
		return
	var objects: Array[LDObject] = _get_target_objects()
	if objects.is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.refresh(objects)
	viewport.get_selection_overlay().queue_redraw()
