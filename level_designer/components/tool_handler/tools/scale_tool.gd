class_name LDScaleTool
extends LDTool


@export var _widget: LDScaleWidget


func get_tool_name() -> String:
	return "Scale"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func wants_overlay() -> bool:
	return true


func _on_enable() -> void:
	super()
	var objects: Array[LDObject] = _get_scalable_objects()
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
	if _get_scalable_objects().is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.on_input(event)


func draw_overlay(draw_node: CanvasItem) -> void:
	_widget.draw_overlay(draw_node)


func _on_overlay_selection_changed(objects: Array[LDObject]) -> void:
	if not is_active():
		return
	var scalable: Array[LDObject] = _get_scalable_objects()
	if scalable.is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.refresh(scalable)


func _get_scalable_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		for prop: LDProperty in obj.get_properties():
			if prop.key == &"scale":
				result.append(obj)
				break
	return result
