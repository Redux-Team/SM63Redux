class_name LDBlockWidget
extends LDToolWidget


static var CORNER_ANCHORS: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, 1.0),
]

static var OPPOSITE_CORNER: Array[int] = [2, 3, 0, 1]

static var CORNER_CURSORS: Array[Control.CursorShape] = [
	Control.CURSOR_FDIAGSIZE,
	Control.CURSOR_BDIAGSIZE,
	Control.CURSOR_FDIAGSIZE,
	Control.CURSOR_BDIAGSIZE,
]


@export var corners: LDToolHandleSet


var _drag_corner: int = -1
var _hovered_corner: int = -1
var _drag_start_object_pos: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO
var _drag_start_border: Vector2 = Vector2.ZERO
var _pending_body_drag: bool = false


func _on_activate() -> void:
	_attach_to_overlay()
	_sync_handles()


func _on_deactivate() -> void:
	_detach_from_overlay()
	_drag_corner = -1
	_hovered_corner = -1
	_pending_body_drag = false


func _on_refresh(_objects: Array[LDObject]) -> void:
	_sync_handles()


func draw_overlay(_draw_node: CanvasItem) -> void:
	_sync_handles()


func _on_input(event: InputEvent) -> void:
	var obj: LDObject = _get_object()
	if not obj:
		return
	
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE and _drag_corner >= 0:
			_cancel_drag(obj)
			get_viewport().set_input_as_handled()
		return
	
	if should_ignore_input():
		return
	
	if event is InputEventMouseMotion:
		if _drag_corner >= 0:
			_drag_resize(obj, get_snapped_mouse_pos(obj))
			_sync_handles()
		elif _pending_body_drag:
			_pending_body_drag = false
			_begin_move_handoff("block_edit", [obj])
		else:
			_update_hover()
		return
	
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_press(obj, event)
			else:
				if _drag_corner >= 0:
					_end_drag(obj)
				_pending_body_drag = false
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and _drag_corner >= 0:
			_cancel_drag(obj)


func _press(obj: LDObject, event: InputEvent) -> void:
	if not can_begin_interaction():
		return
	var hit: int = corners.find_at(get_screen_mouse_pos())
	if hit >= 0:
		_begin_drag(obj, hit)
	elif _is_mouse_inside_block(obj):
		_pending_body_drag = true
	else:
		var handler: LDToolHandler = _tool.get_tool_handler()
		get_ld_viewport().clear_selection()
		handler.select_tool("select")
		handler.get_selected_tool()._on_viewport_input(event)


func _begin_drag(obj: LDObject, corner: int) -> void:
	_drag_corner = corner
	_hovered_corner = -1
	_drag_start_object_pos = obj.position
	_drag_start_size = _get_block_size(obj)
	_drag_start_border = _get_visual_border(obj)
	_tool.set_cursor_shape(CORNER_CURSORS.get(corner))
	_sync_handles()


func _drag_resize(obj: LDObject, mouse_pos: Vector2) -> void:
	var snapping: float = LDViewport.SNAPPING_SIZE
	var minimum: Vector2 = _get_minimum_block_size(obj)
	var maximum: Vector2 = _get_maximum_block_size(obj)
	var opposite: int = OPPOSITE_CORNER.get(_drag_corner)
	var visual_start: Vector2 = _drag_start_size + _drag_start_border
	var fixed: Vector2 = _drag_start_object_pos + (CORNER_ANCHORS.get(opposite) - Vector2(0.5, 0.5)) * visual_start
	
	var new_size: Vector2 = Vector2(
		clampf(snappedf(absf(mouse_pos.x - fixed.x) - _drag_start_border.x, snapping), minimum.x, maximum.x),
		clampf(snappedf(absf(mouse_pos.y - fixed.y) - _drag_start_border.y, snapping), minimum.y, maximum.y)
	)
	var direction: Vector2 = Vector2(
		1.0 if mouse_pos.x >= fixed.x else -1.0,
		1.0 if mouse_pos.y >= fixed.y else -1.0
	)
	var new_center: Vector2 = fixed + direction * (new_size + _drag_start_border) * 0.5
	
	obj.position = new_center
	if obj.has_property(&"b_size_x"):
		obj.set_property(&"b_size_x", int(new_size.x))
	if obj.has_property(&"b_size_y"):
		obj.set_property(&"b_size_y", int(new_size.y))
	if obj.has_property(&"position"):
		obj.set_property(&"position", new_center)


func _end_drag(obj: LDObject) -> void:
	var new_pos: Vector2 = obj.position
	var new_size: Vector2 = _get_block_size(obj)
	var old_pos: Vector2 = _drag_start_object_pos
	var old_size: Vector2 = _drag_start_size
	
	get_history().push("Resize Block",
		func() -> void:
			_apply_block(obj, new_pos, new_size),
		func() -> void:
			_apply_block(obj, old_pos, old_size)
	)
	
	_drag_corner = -1
	_tool.set_cursor_shape(Control.CURSOR_ARROW)
	_sync_handles()


func _cancel_drag(obj: LDObject) -> void:
	_apply_block(obj, _drag_start_object_pos, _drag_start_size)
	_drag_corner = -1
	_tool.set_cursor_shape(Control.CURSOR_ARROW)
	_sync_handles()


func _apply_block(obj: LDObject, pos: Vector2, size: Vector2) -> void:
	if not is_instance_valid(obj):
		return
	obj.position = pos
	if obj.has_property(&"b_size_x"):
		obj.set_property(&"b_size_x", int(size.x))
	if obj.has_property(&"b_size_y"):
		obj.set_property(&"b_size_y", int(size.y))
	if obj.has_property(&"position"):
		obj.set_property(&"position", pos)


func _update_hover() -> void:
	var hit: int = corners.find_at(get_screen_mouse_pos())
	if hit != _hovered_corner:
		_hovered_corner = hit
		corners.set_active(_hovered_corner, _drag_corner)
	if hit >= 0:
		_tool.set_cursor_shape(CORNER_CURSORS.get(hit))
	else:
		_tool.set_cursor_shape(Control.CURSOR_ARROW)


func _sync_handles() -> void:
	var obj: LDObject = _get_object()
	if not obj:
		corners.clear()
		return
	
	var zoom: float = get_camera_zoom()
	var screen_corners: Array[Vector2] = _get_corner_screen_positions(obj)
	corners.resize_to(4)
	for i: int in 4:
		corners.place(i, screen_corners.get(i), zoom)
	corners.set_active(_hovered_corner, _drag_corner)


func _get_corner_screen_positions(obj: LDObject) -> Array[Vector2]:
	var size: Vector2 = _get_visual_size(obj)
	var xform: Transform2D = get_ld_viewport().world_transform(obj)
	var result: Array[Vector2] = []
	for i: int in 4:
		result.append(xform * (obj.position + (CORNER_ANCHORS.get(i) - Vector2(0.5, 0.5)) * size))
	return result


func _is_mouse_inside_block(obj: LDObject) -> bool:
	var screen_corners: Array[Vector2] = _get_corner_screen_positions(obj)
	var rect: Rect2 = Rect2(screen_corners.front(), Vector2.ZERO)
	for i: int in range(1, 4):
		rect = rect.expand(screen_corners.get(i))
	return rect.has_point(get_screen_mouse_pos())


## The size the block actually draws at. Its scene pads the property size by a one pixel border
## on every side, so corner handles keyed off the raw property sat inside the visible edges.
func _get_visual_size(obj: LDObject) -> Vector2:
	var points: PackedVector2Array = obj.get_shape_points()
	if points.size() < 4:
		return _get_block_size(obj)
	return (points.get(2) - points.get(0)).abs()


## How much wider the drawn block is than the size its properties store.
func _get_visual_border(obj: LDObject) -> Vector2:
	return _get_visual_size(obj) - _get_block_size(obj)


func _get_block_size(obj: LDObject) -> Vector2:
	var snapping: float = LDViewport.SNAPPING_SIZE
	var size_x: float = float(obj.get_property(&"b_size_x")) if obj.has_property(&"b_size_x") else snapping
	var size_y: float = float(obj.get_property(&"b_size_y")) if obj.has_property(&"b_size_y") else snapping
	return Vector2(size_x, size_y)


func _get_minimum_block_size(obj: LDObject) -> Vector2:
	var snapping: float = LDViewport.SNAPPING_SIZE
	return Vector2(_get_axis_minimum(obj, &"b_size_x", snapping), _get_axis_minimum(obj, &"b_size_y", snapping))


func _get_axis_minimum(obj: LDObject, key: StringName, snapping: float) -> float:
	var prop: LDProperty = obj.get_ld_property(key)
	if not prop or not is_finite(prop.min_value):
		return snapping
	return maxf(snapping, ceilf(prop.min_value / snapping) * snapping)


func _get_maximum_block_size(obj: LDObject) -> Vector2:
	var snapping: float = LDViewport.SNAPPING_SIZE
	return Vector2(_get_axis_maximum(obj, &"b_size_x", snapping), _get_axis_maximum(obj, &"b_size_y", snapping))


func _get_axis_maximum(obj: LDObject, key: StringName, snapping: float) -> float:
	var prop: LDProperty = obj.get_ld_property(key)
	if not prop or not is_finite(prop.max_value):
		return INF
	return floorf(prop.max_value / snapping) * snapping


func _get_object() -> LDObject:
	if _bound_objects.is_empty():
		return null
	var obj: LDObject = _bound_objects.front()
	return obj if is_instance_valid(obj) else null
