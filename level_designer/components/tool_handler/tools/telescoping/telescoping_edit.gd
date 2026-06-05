class_name LDTelescopingEdit
extends LDTool


@export var _widget: LDTelescopingWidget


func get_tool_name() -> String:
	return "TelescopingEdit"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.selection_changed.connect(_on_selection_changed)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	var objects: Array[LDObject] = _get_telescoping_objects()
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
	_widget.on_input(event)


func draw_overlay(draw_node: CanvasItem) -> void:
	if not is_active():
		return
	_widget.draw_overlay(draw_node)


func _on_selection_changed(_objects: Array[LDObject]) -> void:
	if not is_active():
		return
	var objects: Array[LDObject] = _get_telescoping_objects()
	if objects.is_empty():
		get_tool_handler().select_tool("select")
		return
	_widget.refresh(objects)


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if not is_active():
		return
	_widget.request_redraw()


func _get_telescoping_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		if is_instance_valid(obj) and obj is LDObjectTelescoping:
			result.append(obj)
	return result
