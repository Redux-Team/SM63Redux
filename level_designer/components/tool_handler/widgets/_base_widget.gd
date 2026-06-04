class_name LDWidget
extends Control


var _tool: LDTool
var _bound_objects: Array[LDObject] = []


func _init() -> void:
	hide()


func activate(tool: LDTool, objects: Array[LDObject]) -> void:
	_tool = tool
	_bound_objects = objects
	show()
	_on_activate()


func deactivate() -> void:
	_on_deactivate()
	hide()


func refresh(objects: Array[LDObject]) -> void:
	_bound_objects = objects
	_on_refresh(_bound_objects)


func on_input(event: InputEvent) -> void:
	_on_input(event)


func draw_overlay(_draw_node: CanvasItem) -> void:
	pass


func _on_activate() -> void:
	pass


func _on_deactivate() -> void:
	pass


func _on_refresh(_objects: Array[LDObject]) -> void:
	pass


func _on_input(_event: InputEvent) -> void:
	pass


func get_ld_viewport() -> LDViewport:
	return _tool.viewport


func get_overlay() -> LDSelectionOverlay:
	return _tool.viewport.get_selection_overlay()


func request_redraw() -> void:
	get_overlay().queue_redraw()


func select_tool(tool_name: String) -> void:
	_tool.get_tool_handler().select_tool(tool_name)


func get_history() -> LDHistoryHandler:
	return LD.get_history_handler()


func world_to_screen(world_pos: Vector2) -> Vector2:
	var vp: LDViewport = _tool.viewport
	var xform: Transform2D = vp.get_viewport().get_canvas_transform() * vp.get_root().get_global_transform()
	return xform * world_pos


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp: LDViewport = _tool.viewport
	var xform: Transform2D = vp.get_viewport().get_canvas_transform() * vp.get_root().get_global_transform()
	return xform.affine_inverse() * screen_pos


func get_screen_mouse_pos() -> Vector2:
	return get_overlay().get_local_mouse_position()


func get_world_mouse_pos() -> Vector2:
	return screen_to_world(get_screen_mouse_pos())


func get_snapped_mouse_pos() -> Vector2:
	return get_world_mouse_pos().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
