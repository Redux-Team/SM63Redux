class_name LDPathTool
extends LDTool

@export var preview_root: Node2D
@export var preview_modulate: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var invalid_modulate: Color = Color(1.0, 0.35, 0.35, 0.6)
@export var point_color: Color = Color("6496ed")

var _points: PackedVector2Array = PackedVector2Array()
var _preview: GameObject


func _setup() -> void:
	editor.tool_handler.armed_changed.connect(_on_armed_changed.unbind(1))


func _activate() -> void:
	_reset()


func _deactivate() -> void:
	_reset()
	_clear_preview()


func _cancel() -> void:
	_reset()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or _points.is_empty():
		return
	
	if editor.is_shortcut(event, &"ld_confirm"):
		_finish(_with_cursor())
	elif editor.is_shortcut(event, &"ld_delete"):
		_points.remove_at(_points.size() - 1)
	else:
		return
	
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or editor.tool_handler.armed == null or not is_active():
		return
	
	if _preview == null:
		_preview = editor.object_handler.spawn(editor.tool_handler.armed.id, Vector2.ZERO)
		preview_root.add_child(_preview)
	
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	var points: PackedVector2Array = _with_cursor()
	var shape: PathShape = _preview.shape as PathShape
	if points.size() >= PathShape.MIN_POINTS:
		_preview.position = points.get(0)
		shape.set_points(LDPolygonTool.localize(points, points.get(0)))
		_preview.modulate = preview_modulate
	else:
		_preview.position = _snapped_mouse()
		shape.set_points(shape.default_points)
		_preview.modulate = invalid_modulate if not _points.is_empty() else preview_modulate


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed or editor.tool_handler.armed == null:
		return false
	
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if _points.is_empty():
			return false
		
		_finish(_points if _points.size() >= PathShape.MIN_POINTS else _with_cursor())
		return true
	
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	
	var point: Vector2 = _snapped_mouse()
	if _points.is_empty() or _points.get(_points.size() - 1).distance_to(point) >= LDPolygonStrokeTool.MIN_POINT_DISTANCE:
		_points.append(point)
	return true


func _draw_overlay(overlay: LDOverlay) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null:
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	for point: Vector2 in _points:
		overlay.draw_world_circle(to_world * point, LDPolygonStrokeTool.POINT_RADIUS, point_color)
	overlay.draw_world_polyline(to_world * _with_cursor(), point_color)


func _finish(points: PackedVector2Array) -> void:
	_reset()
	if points.size() < PathShape.MIN_POINTS:
		return
	
	var object: GameObject = editor.object_handler.spawn(editor.tool_handler.armed.id, points.get(0))
	(object.shape as PathShape).set_points(LDPolygonTool.localize(points, points.get(0)))
	for property: ObjectProperty in object.properties:
		if editor.tool_handler.should_randomize(property):
			object.set_value(property.key, property.random_value())
	editor.object_handler.add_objects([object], editor.level_handler.active_layer, "Place %s" % editor.tool_handler.armed.display_name, false)


func _with_cursor() -> PackedVector2Array:
	var points: PackedVector2Array = _points.duplicate()
	var cursor_point: Vector2 = _snapped_mouse()
	if not points.is_empty() and points.get(points.size() - 1).distance_to(cursor_point) >= LDPolygonStrokeTool.MIN_POINT_DISTANCE:
		points.append(cursor_point)
	
	return points


func _snapped_mouse() -> Vector2:
	return editor.viewport_handler.snap(editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer))


func _reset() -> void:
	_points = PackedVector2Array()


func _clear_preview() -> void:
	if _preview:
		_preview.free()
		_preview = null


func _on_armed_changed() -> void:
	_clear_preview()
	_reset()
