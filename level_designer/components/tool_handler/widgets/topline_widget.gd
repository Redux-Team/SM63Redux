class_name LDToplineWidget
extends LDToolWidget

## Per-edge topline toggles for one polygon. Every edge of the shape carries a handle on its
## midpoint, shaded by whether that edge currently counts as a topline, and clicking one pushes an
## override. The shape itself is never touched, so the handles are the whole of the tool.


## Shade for an edge that is not a topline. Dimmed rather than hidden, because a dark handle is
## still the thing you click to turn the edge back on.
const SHADE_OFF: Color = Color(0.5, 0.5, 0.55, 0.6)


@export var _edge_handles: LDToolHandleSet


var _edges: Array[Dictionary] = []


func _on_activate() -> void:
	_attach_to_overlay()
	_rebuild()


func _on_deactivate() -> void:
	_edges.clear()
	_detach_from_overlay()


func _on_refresh(_objects: Array[LDObject]) -> void:
	_rebuild()


## The overlay redraws on every camera move, so it doubles as this widget's tick: the handles are
## re-placed here rather than the tool wiring a viewport_moved hook of its own.
func draw_overlay(_draw_node: CanvasItem) -> void:
	sync()


## Re-places the handles against the edges already read. Cheap enough to run on every pan because
## it re-transforms what it has rather than re-walking the polygon.
func sync() -> void:
	var polygon: LDObjectPolygon = _get_polygon()
	if not polygon:
		return
	var zoom: float = get_camera_zoom()
	for i: int in _edges.size():
		var mid: Vector2 = _edges.get(i).get("mid") as Vector2
		_edge_handles.place(i, object_to_screen(polygon, mid), zoom)


func _on_input(event: InputEvent) -> void:
	if should_ignore_input():
		return
	var hovered: int = _edge_handles.find_at(get_screen_mouse_pos())
	if event is InputEventMouseMotion:
		_edge_handles.set_active(hovered)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if not button or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if hovered < 0 or not can_begin_interaction():
		return
	_toggle_edge(hovered)
	get_viewport().set_input_as_handled()


## Overrides the edge's topline state. The push emits history_changed, which the base widget turns
## back into a refresh - so the handle re-shades itself off the shape rather than off a guess.
func _toggle_edge(index: int) -> void:
	var polygon: LDObjectPolygon = _get_polygon()
	var edge: Dictionary = _edges.get(index)
	var key: String = edge.get("key")
	var old_state: bool = bool(edge.get("on"))
	var had_key: bool = polygon.get_topline_overrides().has(key)
	get_history().push("Toggle Topline Edge",
		func() -> void:
			if is_instance_valid(polygon):
				polygon.set_topline_override(key, not old_state),
		func() -> void:
			if is_instance_valid(polygon):
				if had_key:
					polygon.set_topline_override(key, old_state)
				else:
					polygon.clear_topline_override(key)
	)


func _rebuild() -> void:
	var polygon: LDObjectPolygon = _get_polygon()
	_edges.clear()
	if polygon:
		_edges = polygon.get_topline_edges()
	_edge_handles.resize_to(_edges.size())
	for i: int in _edges.size():
		_edge_handles.set_shade(i, Color.WHITE if bool(_edges.get(i).get("on")) else SHADE_OFF)
	sync()


func _get_polygon() -> LDObjectPolygon:
	var objects: Array[LDObject] = get_bound_objects()
	if objects.is_empty():
		return null
	return objects.front() as LDObjectPolygon
