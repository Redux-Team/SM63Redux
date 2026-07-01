class_name LDScaleWidget
extends LDToolWidget


const SCALE_FROM_CENTER: bool = false
const HANDLE_GRAB_RADIUS: float = 12.0
const BASE_RECT_SIZE: Vector2 = Vector2(80.0, 80.0)
const DOUBLE_CLICK_THRESHOLD: float = 0.3


enum HandleIndex {
	TOP_LEFT,
	TOP,
	TOP_RIGHT,
	LEFT,
	RIGHT,
	BOTTOM_LEFT,
	BOTTOM,
	BOTTOM_RIGHT,
}


@export var scale_panel: Panel
@export var top_left_button: Button
@export var top_button: Button
@export var top_right_button: Button
@export var left_button: Button
@export var right_button: Button
@export var bottom_left_button: Button
@export var bottom_button: Button
@export var bottom_right_button: Button

@export var scale_x_label: Label
@export var scale_x_label_2: Label
@export var scale_y_label: Label
@export var scale_y_label_2: Label


var _is_dragging: bool = false
var _did_drag: bool = false
var _active_handle: HandleIndex = HandleIndex.TOP_LEFT
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_scales: Array[Vector2] = []
var _drag_start_positions: Array[Vector2] = []
var _drag_anchor_positions: Array[Vector2] = []
var _drag_start_half_size: Vector2 = Vector2.ZERO
var _last_click_time: float = 0.0
var _hovered_handle: int = -1
var _baseline_scales: Array[Vector2] = []
var _pending_object_drag: bool = false


func _on_activate() -> void:
	_attach_to_overlay()
	show()
	_capture_baseline()
	_sync_panel()


func _on_deactivate() -> void:
	hide()
	_detach_from_overlay()
	_drag_start_scales.clear()
	_drag_start_positions.clear()
	_drag_anchor_positions.clear()
	_baseline_scales.clear()


func _on_refresh(_objects: Array[LDObject]) -> void:
	_capture_baseline()
	_sync_panel()


func _capture_baseline() -> void:
	_baseline_scales.clear()
	for obj: LDObject in _bound_objects:
		var val: Variant = obj.get_property(&"scale")
		_baseline_scales.append(val if val != null else Vector2.ONE)


func _on_input(event: InputEvent) -> void:
	var center: Vector2 = _get_center_screen()
	var half: Vector2 = _get_half_size_screen()
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = get_screen_mouse_pos()
		
		if _pending_object_drag:
			_pending_object_drag = false
			_begin_move_handoff("scale", _bound_objects)
			return
		
		if _is_dragging:
			_did_drag = true
			var delta: Vector2 = mouse_pos - _drag_start_mouse
			var scale_multiplier: Vector2 = _compute_scale_multiplier(delta * (1.0 if SCALE_FROM_CENTER else 0.5))
			for i: int in _bound_objects.size():
				var obj: LDObject = _bound_objects.get(i)
				var start_scale: Vector2 = _drag_start_scales.get(i)
				var new_scale: Vector2 = start_scale * scale_multiplier
				
				var prop: Variant = obj.get_ld_property(&"scale")
				if prop != null:
					var step_val: float = prop.get_step()
					if step_val > 0.0:
						new_scale.x = round(new_scale.x / step_val) * step_val
						new_scale.y = round(new_scale.y / step_val) * step_val
					new_scale = prop.clamp_value(new_scale)
				
				obj.set_property(&"scale", new_scale)
				if not SCALE_FROM_CENTER:
					var dir: Vector2 = _get_handle_direction(_active_handle)
					var anchor: Vector2 = _drag_anchor_positions.get(i)
					obj.set_property(&"position", anchor + dir * _get_object_base_half_size(obj) * new_scale)
			_sync_panel()
		else:
			var prev: int = _hovered_handle
			_hovered_handle = _get_handle_at(mouse_pos, center, half)
			if _hovered_handle != prev:
				_update_button_states()
			_update_cursor(center, half)
	
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if get_ld_viewport().is_panning():
				return
			var hit: int = _get_handle_at(get_screen_mouse_pos(), center, half)
			if hit >= 0:
				_is_dragging = true
				_did_drag = false
				_active_handle = hit as HandleIndex
				_drag_start_mouse = get_screen_mouse_pos()
				_drag_start_half_size = _get_half_size_screen()
				_drag_start_scales.clear()
				_drag_start_positions.clear()
				_drag_anchor_positions.clear()
				var dir: Vector2 = _get_handle_direction(_active_handle)
				for obj: LDObject in _bound_objects:
					var val: Variant = obj.get_property(&"scale")
					var start_scale: Vector2 = val if val != null else Vector2.ONE
					_drag_start_scales.append(start_scale)
					var pos: Variant = obj.get_property(&"position")
					var start_pos: Vector2 = pos if pos != null else Vector2.ZERO
					_drag_start_positions.append(start_pos)
					_drag_anchor_positions.append(start_pos - dir * _get_object_base_half_size(obj) * start_scale)
				_hovered_handle = -1
				_update_button_states()
			elif _is_mouse_inside_rect(center, half):
				_pending_object_drag = true
			else:
				select_tool("select")
		else:
			if _is_dragging:
				if _did_drag:
					_commit_scale()
				else:
					var now: float = Time.get_ticks_msec() / 1000.0
					if now - _last_click_time <= DOUBLE_CLICK_THRESHOLD:
						_reset_scale()
					_last_click_time = now
				_is_dragging = false
				_did_drag = false
				_update_button_states()
			_pending_object_drag = false


func _update_cursor(center: Vector2, half: Vector2) -> void:
	if _is_dragging:
		_tool.set_cursor_shape(_get_handle_cursor(_active_handle as int))
		return
	if _hovered_handle >= 0:
		_tool.set_cursor_shape(_get_handle_cursor(_hovered_handle))
		return
	if _is_mouse_inside_rect(center, half):
		_tool.set_cursor_shape(Control.CURSOR_MOVE)
		return
	_tool.set_cursor_shape(Control.CURSOR_ARROW)


func _get_handle_cursor(handle: int) -> Control.CursorShape:
	match handle:
		HandleIndex.TOP_LEFT, HandleIndex.BOTTOM_RIGHT:
			return Control.CURSOR_FDIAGSIZE
		HandleIndex.TOP_RIGHT, HandleIndex.BOTTOM_LEFT:
			return Control.CURSOR_BDIAGSIZE
		HandleIndex.TOP, HandleIndex.BOTTOM:
			return Control.CURSOR_VSIZE
		HandleIndex.LEFT, HandleIndex.RIGHT:
			return Control.CURSOR_HSIZE
	return Control.CURSOR_ARROW


func _is_mouse_inside_rect(center: Vector2, half: Vector2) -> bool:
	var mouse: Vector2 = get_screen_mouse_pos()
	return Rect2(center - half, half * 2.0).has_point(mouse)


func draw_overlay(_draw_node: CanvasItem) -> void:
	if _bound_objects.is_empty():
		return
	_sync_panel()


func _sync_panel() -> void:
	if _bound_objects.is_empty():
		return
	
	var half: Vector2 = _get_half_size_screen()
	var center: Vector2 = _get_center_screen()
	
	scale_panel.size = half * 2.0
	scale_panel.global_position = center - half
	
	_reposition_buttons(half)
	_update_label()


func _reposition_buttons(half: Vector2) -> void:
	var s: Vector2 = half * 2.0
	_place_button(top_left_button, Vector2(0.0, 0.0))
	_place_button(top_button, Vector2(half.x, 0.0))
	_place_button(top_right_button, Vector2(s.x, 0.0))
	_place_button(left_button, Vector2(0.0, half.y))
	_place_button(right_button, Vector2(s.x, half.y))
	_place_button(bottom_left_button, Vector2(0.0, s.y))
	_place_button(bottom_button, Vector2(half.x, s.y))
	_place_button(bottom_right_button, Vector2(s.x, s.y))


func _place_button(btn: Button, anchor: Vector2) -> void:
	btn.position = anchor - btn.size * 0.5


func _update_button_states() -> void:
	var buttons: Array[Button] = _get_buttons()
	for i: int in buttons.size():
		var btn: Button = buttons.get(i)
		btn.button_pressed = _is_dragging and i == _active_handle as int
		btn.set(&"theme_override_styles/normal", null)
		if not _is_dragging:
			btn.set_pressed_no_signal(false)
			btn.mouse_exited.emit()
			if i == _hovered_handle:
				btn.mouse_entered.emit()


func _update_label() -> void:
	if _bound_objects.size() > 1:
		var avg_current: Vector2 = _get_average_scale()
		var avg_baseline: Vector2 = Vector2.ZERO
		for s: Vector2 in _baseline_scales:
			avg_baseline += s
		avg_baseline = avg_baseline / float(_baseline_scales.size()) if not _baseline_scales.is_empty() else Vector2.ONE
		var multiplier: Vector2 = avg_current / avg_baseline if avg_baseline.x != 0.0 and avg_baseline.y != 0.0 else Vector2.ONE
		scale_x_label.text = "%.1fx" % multiplier.x
		scale_y_label.text = "%.1fx" % multiplier.y
	elif _bound_objects.is_empty():
		scale_x_label.text = "1.0x"
		scale_y_label.text = "1.0x"
	else:
		var val: Variant = _bound_objects.get(0).get_property(&"scale")
		var s: Vector2 = val if val != null else Vector2.ONE
		scale_x_label.text = "%.1fx" % s.x
		scale_y_label.text = "%.1fx" % s.y
	
	scale_x_label_2.text = scale_x_label.text
	scale_y_label_2.text = scale_y_label.text


func _get_handle_at(mouse_pos: Vector2, center: Vector2, half: Vector2) -> int:
	for i: int in 8:
		if mouse_pos.distance_to(_get_handle_pos(i as HandleIndex, center, half)) <= HANDLE_GRAB_RADIUS:
			return i
	return -1


func _get_handle_pos(handle: HandleIndex, center: Vector2, half: Vector2) -> Vector2:
	match handle:
		HandleIndex.TOP_LEFT: return center + Vector2(-half.x, -half.y)
		HandleIndex.TOP: return center + Vector2(0.0, -half.y)
		HandleIndex.TOP_RIGHT: return center + Vector2(half.x, -half.y)
		HandleIndex.LEFT: return center + Vector2(-half.x, 0.0)
		HandleIndex.RIGHT: return center + Vector2(half.x, 0.0)
		HandleIndex.BOTTOM_LEFT: return center + Vector2(-half.x, half.y)
		HandleIndex.BOTTOM: return center + Vector2(0.0, half.y)
		HandleIndex.BOTTOM_RIGHT: return center + Vector2(half.x, half.y)
	return center


func _compute_scale_multiplier(mouse_delta: Vector2) -> Vector2:
	if _drag_start_half_size.x == 0.0 or _drag_start_half_size.y == 0.0:
		return Vector2.ONE
	var d: Vector2 = _drag_start_half_size
	match _active_handle:
		HandleIndex.TOP_LEFT: return Vector2.ONE + Vector2(-mouse_delta.x, -mouse_delta.y) / d
		HandleIndex.TOP: return Vector2.ONE + Vector2(0.0, -mouse_delta.y) / d
		HandleIndex.TOP_RIGHT: return Vector2.ONE + Vector2(mouse_delta.x, -mouse_delta.y) / d
		HandleIndex.LEFT: return Vector2.ONE + Vector2(-mouse_delta.x, 0.0) / d
		HandleIndex.RIGHT: return Vector2.ONE + Vector2(mouse_delta.x, 0.0) / d
		HandleIndex.BOTTOM_LEFT: return Vector2.ONE + Vector2(-mouse_delta.x, mouse_delta.y) / d
		HandleIndex.BOTTOM: return Vector2.ONE + Vector2(0.0, mouse_delta.y) / d
		HandleIndex.BOTTOM_RIGHT: return Vector2.ONE + Vector2(mouse_delta.x, mouse_delta.y) / d
	return Vector2.ONE


func _get_handle_direction(handle: HandleIndex) -> Vector2:
	match handle:
		HandleIndex.TOP_LEFT: return Vector2(-1.0, -1.0)
		HandleIndex.TOP: return Vector2(0.0, -1.0)
		HandleIndex.TOP_RIGHT: return Vector2(1.0, -1.0)
		HandleIndex.LEFT: return Vector2(-1.0, 0.0)
		HandleIndex.RIGHT: return Vector2(1.0, 0.0)
		HandleIndex.BOTTOM_LEFT: return Vector2(-1.0, 1.0)
		HandleIndex.BOTTOM: return Vector2(0.0, 1.0)
		HandleIndex.BOTTOM_RIGHT: return Vector2(1.0, 1.0)
	return Vector2.ZERO


func _get_half_size_screen() -> Vector2:
	if _bound_objects.is_empty():
		return Vector2.ZERO
	var center_world: Vector2 = _get_center_world()
	if _bound_objects.size() > 1:
		var corner_world: Vector2 = center_world + (BASE_RECT_SIZE * 0.5)
		return world_to_screen(corner_world) - world_to_screen(center_world)
	var obj: LDObject = _bound_objects.get(0)
	var avg_scale: Vector2 = _get_average_scale()
	var corner_world: Vector2 = center_world + _get_object_base_half_size(obj) * avg_scale
	return world_to_screen(corner_world) - world_to_screen(center_world)


func _get_average_scale() -> Vector2:
	if _bound_objects.is_empty():
		return Vector2.ONE
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in _bound_objects:
		var val: Variant = obj.get_property(&"scale")
		sum += val if val != null else Vector2.ONE
	return sum / float(_bound_objects.size())


func _get_center_world() -> Vector2:
	if _bound_objects.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in _bound_objects:
		sum += obj.global_position + obj.get_origin_offset()
	return sum / float(_bound_objects.size())


func _get_center_screen() -> Vector2:
	return world_to_screen(_get_center_world())


func _get_buttons() -> Array[Button]:
	return [
		top_left_button, top_button, top_right_button,
		left_button, right_button,
		bottom_left_button, bottom_button, bottom_right_button,
	]


func _get_object_base_half_size(obj: LDObject) -> Vector2:
	if _bound_objects.size() > 1:
		return BASE_RECT_SIZE * 0.5
	if is_instance_valid(obj):
		var shape_node: CollisionShape2D = obj.get(&"editor_placement_rect") as CollisionShape2D
		if is_instance_valid(shape_node) and shape_node.shape is RectangleShape2D:
			return (shape_node.shape as RectangleShape2D).size * 0.5
	return BASE_RECT_SIZE * 0.5


func _reset_scale() -> void:
	var old_scales: Array[Vector2] = _drag_start_scales.duplicate()
	var old_positions: Array[Vector2] = _drag_start_positions.duplicate()
	var is_single: bool = _bound_objects.size() == 1
	
	var history: LDHistoryHandler = get_history()
	history.begin_action("Reset Scale")
	history.add_do(func() -> void:
		for i: int in _bound_objects.size():
			var obj: LDObject = _bound_objects.get(i)
			if is_instance_valid(obj):
				obj.set_property(&"scale", Vector2.ONE if is_single else old_scales.get(i))
				if not SCALE_FROM_CENTER:
					obj.set_property(&"position", old_positions.get(i))
	)
	history.add_undo(func() -> void:
		for i: int in _bound_objects.size():
			var obj: LDObject = _bound_objects.get(i)
			if is_instance_valid(obj):
				obj.set_property(&"scale", old_scales.get(i))
				if not SCALE_FROM_CENTER:
					obj.set_property(&"position", old_positions.get(i))
	)
	history.commit_action()
	
	for i: int in _bound_objects.size():
		var obj: LDObject = _bound_objects.get(i)
		obj.set_property(&"scale", Vector2.ONE if is_single else old_scales.get(i))
		if not SCALE_FROM_CENTER:
			obj.set_property(&"position", old_positions.get(i))
	_sync_panel()


func _commit_scale() -> void:
	var old_scales: Array[Vector2] = _drag_start_scales.duplicate()
	var old_positions: Array[Vector2] = _drag_start_positions.duplicate()
	var new_scales: Array[Vector2] = []
	var new_positions: Array[Vector2] = []
	for obj: LDObject in _bound_objects:
		var val: Variant = obj.get_property(&"scale")
		new_scales.append(val if val != null else Vector2.ONE)
		var pos: Variant = obj.get_property(&"position")
		new_positions.append(pos if pos != null else Vector2.ZERO)
	
	var history: LDHistoryHandler = get_history()
	history.begin_action("Scale Objects")
	history.add_do(func() -> void:
		for i: int in _bound_objects.size():
			var obj: LDObject = _bound_objects.get(i)
			if is_instance_valid(obj):
				obj.set_property(&"scale", new_scales.get(i))
				if not SCALE_FROM_CENTER:
					obj.set_property(&"position", new_positions.get(i))
	)
	history.add_undo(func() -> void:
		for i: int in _bound_objects.size():
			var obj: LDObject = _bound_objects.get(i)
			if is_instance_valid(obj):
				obj.set_property(&"scale", old_scales.get(i))
				if not SCALE_FROM_CENTER:
					obj.set_property(&"position", old_positions.get(i))
	)
	history.commit_action()
