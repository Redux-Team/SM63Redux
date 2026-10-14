class_name LDScaleTool
extends LDWidgetTool

const GRIPS: Array[Vector2] = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0)]
const LABEL_SIZE: int = 24
const LABEL_GAP: float = 14.0

@export var grip_style: LDHandleStyle
@export var box_color: Color = Color(0.39, 0.59, 0.93, 0.08)
@export var border_color: Color = Color("6496ed")
@export var label_font: Font = preload("res://assets/font/pixel_redux_border.fnt")
@export var label_color: Color = Color.WHITE
@export var snap_step: float = 0.1
@export var min_scale: float = 0.1

var _before: Array[Transform2D] = []
var _before_global: Array[Transform2D] = []
var _start_rect: Rect2
var _anchor: Vector2
var _factor: Vector2 = Vector2.ONE


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return objects.filter(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.SCALABLE))


func _layout_handles() -> void:
	var frame: Transform2D = _frame()
	var rect: Rect2 = _rect()
	var center: Vector2 = editor.viewport_handler.to_screen(frame * rect.get_center())
	for i: int in GRIPS.size():
		var handle: LDHandle = place_handle(i, frame * (rect.get_center() + GRIPS.get(i) * rect.size * 0.5), grip_style)
		handle.cursor = LDViewportHandler.resize_cursor(editor.viewport_handler.to_screen(handle.world) - center)
		handle.angle = (editor.world.get_canvas_transform() * frame).get_rotation()


func _draw_guides(overlay: LDOverlay) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform() * _frame()
	var rect: Rect2 = _rect()
	var corners: PackedVector2Array = to_screen * PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	overlay.canvas.draw_colored_polygon(corners, box_color)
	overlay.canvas.draw_polyline(TerrainPolygon.get_closed_points(corners), border_color, 2.0, true)
	var shown: Vector2 = targets.front().scale if targets.size() == 1 else _factor
	var up: Vector2 = (corners.get(0) - corners.get(3)).normalized()
	var left: Vector2 = (corners.get(0) - corners.get(1)).normalized()
	_draw_label(overlay.canvas, (corners.get(0) + corners.get(1)) * 0.5 + up * LABEL_GAP, "%.1fx" % shown.x)
	_draw_label(overlay.canvas, (corners.get(0) + corners.get(3)) * 0.5 + left * LABEL_GAP * 2.0, "%.1fx" % shown.y)


func _on_empty_pressed(world_position: Vector2, _screen: Vector2) -> bool:
	if not _rect().has_point(_frame().affine_inverse() * world_position):
		return false
	
	select_tool.move_tool.begin_drag(world_position)
	_forwarding = select_tool.move_tool.is_dragging()
	return _forwarding


func _on_handle_pressed(_handle: LDHandle) -> void:
	_before = LDObjectHandler.get_transforms(targets)
	_before_global.clear()
	for object: GameObject in targets:
		_before_global.append(object.get_global_transform())
	_start_rect = _rect()
	_anchor = _start_rect.get_center()
	_factor = Vector2.ONE


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var grip: Vector2 = GRIPS.get(handle.key)
	if targets.size() == 1:
		_scale_single(targets.front(), grip, world_position)
	else:
		_scale_group(grip, world_position)


func _on_handle_released(_handle: LDHandle) -> void:
	_factor = Vector2.ONE
	editor.object_handler.transform_objects(targets, _before, LDObjectHandler.get_transforms(targets), "Scale Objects")


func _on_handle_cancelled(_handle: LDHandle) -> void:
	_factor = Vector2.ONE
	for i: int in targets.size():
		targets.get(i).transform = _before.get(i)
		targets.get(i).invalidate_bounds()


func _on_handle_reset(_handle: LDHandle) -> void:
	if targets.size() != 1:
		return
	
	var before: Array[Transform2D] = LDObjectHandler.get_transforms(targets)
	targets.front().scale = Vector2.ONE
	editor.object_handler.transform_objects(targets, before, LDObjectHandler.get_transforms(targets), "Reset Scale")


func _scale_single(object: GameObject, grip: Vector2, world_position: Vector2) -> void:
	var before: Transform2D = _before.front()
	var half: Vector2 = _start_rect.size * 0.5
	var anchor: Vector2 = _start_rect.get_center() - grip * half
	var reach: Vector2 = grip * half * 2.0
	var anchor_parent: Vector2 = before * anchor
	var offset: Vector2 = Transform2D(before.get_rotation(), Vector2.ZERO).basis_xform_inv(to_parent(object, world_position, false) - anchor_parent)
	var scale: Vector2 = before.get_scale()
	for axis: int in 2:
		if not is_zero_approx(reach[axis]):
			scale[axis] = _snap_scale(offset[axis] / reach[axis])
	
	var result: Transform2D = Transform2D(before.get_rotation(), scale, before.get_skew(), Vector2.ZERO)
	result.origin = anchor_parent - result.basis_xform(anchor)
	object.transform = result
	object.invalidate_bounds()


func _scale_group(grip: Vector2, world_position: Vector2) -> void:
	var half: Vector2 = _start_rect.size * 0.5
	var anchor: Vector2 = _start_rect.get_center() - grip * half
	var reach: Vector2 = grip * half * 2.0
	var offset: Vector2 = world_position - anchor
	_anchor = anchor
	for axis: int in 2:
		_factor[axis] = 1.0 if is_zero_approx(reach[axis]) else _snap_scale(offset[axis] / reach[axis])
	
	for i: int in targets.size():
		var object: GameObject = targets.get(i)
		var before: Transform2D = _before_global.get(i)
		object.global_position = anchor + (before.origin - anchor) * _factor
		object.scale = _before.get(i).get_scale() * _factor
		object.invalidate_bounds()


func _snap_scale(value: float) -> float:
	if not Input.is_action_pressed(&"ld_snap_bypass"):
		value = snappedf(value, snap_step)
	
	return signf(value if not is_zero_approx(value) else 1.0) * maxf(absf(value), min_scale)


func _frame() -> Transform2D:
	return targets.front().get_global_transform() if targets.size() == 1 else Transform2D.IDENTITY


func _rect() -> Rect2:
	if targets.size() == 1:
		return targets.front().get_local_bounds()
	
	if is_dragging():
		return Rect2(_anchor + (_start_rect.position - _anchor) * _factor, Vector2.ZERO).expand(_anchor + (_start_rect.end - _anchor) * _factor)
	
	return editor.object_handler.selection.get_global_bounds()


func _draw_label(canvas: CanvasItem, at: Vector2, text: String) -> void:
	var text_size: Vector2 = label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	var origin: Vector2 = (at + Vector2(-text_size.x * 0.5, label_font.get_ascent(LABEL_SIZE) - text_size.y * 0.5)).round()
	canvas.draw_string(label_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, label_color)
