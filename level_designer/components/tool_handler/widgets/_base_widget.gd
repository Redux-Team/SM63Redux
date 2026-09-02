class_name LDToolWidget
extends Control

## Scene-instanced overlay for a tool. A widget is authored as a .tscn, instanced under its tool
## in tool_handler.tscn and reached through an @export - never built with .new() in a tool script.
## It binds to one or more [LDObject]s and follows them; the handles it shows come from
## [LDToolHandleSet] children, which pool [LDToolHandle] instances.
##
## Widgets own rendering, positioning and visual state. They do NOT own hit testing through
## Godot's Control input: every handle is MOUSE_FILTER_IGNORE and the viewport's input Control sits
## above the overlay, so the owning tool feeds events in through [method on_input] and the widget
## resolves them against [member LDToolWidgetStyle.grab_radius].

## How long two clicks may be apart and still count as a double click. One threshold for every
## widget; the tools used to carry two different ones.
const DOUBLE_CLICK_SEC: float = 0.4


@export_group("Rendering")
## Applied to every [LDToolHandleSet] child on activation, so a widget declares its render space
## once instead of each set repeating it.
@export var render_space: LDToolWidgetStyle.RenderSpace = LDToolWidgetStyle.RenderSpace.GLOBAL
## Sets whose render space this widget drives. Left empty, every LDToolHandleSet child is used.
@export var _handle_sets: Array[LDToolHandleSet] = []


var _tool: LDTool
var _bound_objects: Array[LDObject] = []
var _tool_node: Node

var _last_click_time: float = -INF
var _last_click_index: int = -1


func _init() -> void:
	hide()


func activate(tool: LDTool, objects: Array[LDObject]) -> void:
	_tool = tool
	_bound_objects = objects
	for handle_set: LDToolHandleSet in get_handle_sets():
		handle_set.render_space = render_space
	var history: LDHistoryHandler = get_history()
	if history and not history.history_changed.is_connected(_on_history_changed):
		history.history_changed.connect(_on_history_changed)
	show()
	_on_activate()


func deactivate() -> void:
	_on_deactivate()
	var history: LDHistoryHandler = get_history()
	if history and history.history_changed.is_connected(_on_history_changed):
		history.history_changed.disconnect(_on_history_changed)
	for handle_set: LDToolHandleSet in get_handle_sets():
		handle_set.clear()
	_last_click_time = -INF
	_last_click_index = -1
	hide()


func refresh(objects: Array[LDObject]) -> void:
	_bound_objects = objects
	_on_refresh(_bound_objects)


func on_input(event: InputEvent) -> void:
	_on_input(event)


func draw_overlay(_draw_node: CanvasItem) -> void:
	pass


func get_bound_objects() -> Array[LDObject]:
	return _bound_objects


## Every [LDToolHandleSet] this widget drives: the explicit export list, else its direct children.
func get_handle_sets() -> Array[LDToolHandleSet]:
	if not _handle_sets.is_empty():
		return _handle_sets
	var found: Array[LDToolHandleSet] = []
	for child: Node in get_children():
		if child is LDToolHandleSet:
			found.append(child)
	return found


## The camera zoom handle sets size themselves against. One number: the editor never zooms its
## axes independently.
func get_camera_zoom() -> float:
	var viewport: LDViewport = get_ld_viewport()
	return viewport.camera_zoom.x if viewport else 1.0


## Screen position of a point expressed in one object's own local space.
func object_to_screen(obj: Node2D, local_point: Vector2) -> Vector2:
	return _tool.viewport.object_transform(obj) * local_point


## Whether the second half of a double click just landed on [param index]. Pass -1 for widgets
## that only care about timing.
func is_double_click(index: int) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var repeated: bool = now - _last_click_time <= DOUBLE_CLICK_SEC and _last_click_index == index
	_last_click_time = now
	_last_click_index = index
	return repeated


## The guard every consumer had its own copy of: no widget acts on an already handled event or
## under touch input. Panning is deliberately not part of this - a pan begun mid-drag must still
## let the button release through, or the drag never ends.
func should_ignore_input() -> bool:
	if get_viewport().is_input_handled():
		return true
	return Singleton.get_input_handler().is_using_touch()


## Whether a new interaction may start. Panning belongs here rather than in
## [method should_ignore_input] so an in-flight drag can always be finished.
func can_begin_interaction() -> bool:
	return not get_ld_viewport().is_panning()


func _on_activate() -> void:
	pass


func _on_deactivate() -> void:
	pass


func _on_refresh(_objects: Array[LDObject]) -> void:
	pass


func _on_input(_event: InputEvent) -> void:
	pass


## Called after an undo or redo. Handle counts go stale against the object's own point count
## otherwise, which is what the mini() guards in the old tools were papering over.
func _on_history_changed() -> void:
	_on_refresh(_bound_objects)


func get_ld_viewport() -> LDViewport:
	return _tool.viewport if _tool else null


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


func world_to_screen(world_pos: Vector2, obj: Node2D = null) -> Vector2:
	return _tool.viewport.world_to_screen(world_pos, obj)


func screen_to_world(screen_pos: Vector2, obj: Node2D = null) -> Vector2:
	return _tool.viewport.screen_to_world(screen_pos, obj)


func get_screen_mouse_pos() -> Vector2:
	return _tool.viewport.get_screen_mouse()


func get_world_mouse_pos(obj: Node2D = null) -> Vector2:
	return screen_to_world(get_screen_mouse_pos(), obj)


func get_snapped_mouse_pos(obj: Node2D = null) -> Vector2:
	return get_world_mouse_pos(obj).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
