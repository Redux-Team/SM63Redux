class_name LDToolWidget
extends Control


var _tool: LDTool
var _bound_objects: Array[LDObject] = []
var _tool_node: Node


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
	if not _tool:
		return null
	return _tool.viewport.get_selection_overlay()


func request_redraw() -> void:
	# May be called via deactivate() before the widget was ever activated (e.g. selecting
	# Rotate/Scale with nothing selected, which bounces straight back to Select).
	var overlay: LDSelectionOverlay = get_overlay()
	if overlay:
		overlay.queue_redraw()


func select_tool(tool_name: String) -> void:
	_tool.get_tool_handler().select_tool(tool_name)


func get_history() -> LDHistoryHandler:
	return LD.get_history_handler()


## Returns the shared Move tool, used by widgets to hand off body-drags.
func _get_move_tool() -> LDToolMove:
	return _tool.get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


## Reparent the widget's Control children onto the selection overlay so they
## render above the viewport. Stores the original parent for _detach_from_overlay().
func _attach_to_overlay() -> void:
	if get_parent() != get_overlay():
		_tool_node = get_parent()
		reparent(get_overlay())


## Reparent the widget back under its owning tool node.
func _detach_from_overlay() -> void:
	if _tool_node and is_instance_valid(_tool_node) and get_parent() != _tool_node:
		reparent(_tool_node)


## Hand the current click off to the Move tool so the user can drag the bound
## objects, returning to this widget's tool when the drag ends.
func _begin_move_handoff(return_tool: String, objects: Array[LDObject]) -> void:
	var move_tool: LDToolMove = _get_move_tool()
	if move_tool and move_tool.try_begin_drag(get_screen_mouse_pos(), objects):
		move_tool.return_tool = return_tool
		select_tool("move")


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
