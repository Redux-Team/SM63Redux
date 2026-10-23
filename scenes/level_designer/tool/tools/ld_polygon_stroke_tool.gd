@abstract class_name LDPolygonStrokeTool
extends LDTool

const MIN_POINT_DISTANCE: float = 8.0
const CLOSE_RADIUS: float = 10.0
const POINT_RADIUS: float = 4.0

@export var stroke_color: Color = Color("6496ed")
@export var fill_color: Color = Color(0.39, 0.59, 0.93, 0.25)
@export var draw_fill: bool = true

var _points: PackedVector2Array = PackedVector2Array()
var _cursor: Vector2


static func is_simple(points: PackedVector2Array) -> bool:
	var count: int = points.size()
	for i: int in count:
		for j: int in range(i + 2, count):
			if i == 0 and j == count - 1:
				continue
			
			if Geometry2D.segment_intersects_segment(
					points[i],
					points[(i + 1) % count],
					points[j],
					points[(j + 1) % count],
			) != null:
				return false
	
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or _points.is_empty():
		return
	
	if editor.is_shortcut(event, &"ld_confirm"):
		_complete(_completion_points())
	elif editor.is_shortcut(event, &"ld_delete"):
		_points.remove_at(_points.size() - 1)
		_stroke_changed()
	else:
		return
	
	get_viewport().set_input_as_handled()


func _activate() -> void:
	reset()


func _deactivate() -> void:
	reset()


func _cancel() -> void:
	reset()


func _tool_input(event: InputEvent, world_position: Vector2) -> bool:
	if event is InputEventMouseMotion:
		_cursor = snapped_mouse()
		_stroke_changed()
		return false
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return false
	
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if _points.is_empty():
			return false
		
		_complete(_completion_points())
		return true
	
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not _can_begin(world_position):
		return false
	
	var point: Vector2 = snapped_mouse()
	if (
			_points.size() >= PolygonShape.MIN_POINTS
			and (to_screen(point).distance_to(to_screen(_points[0])) <= CLOSE_RADIUS)
	):
		_complete(_points)
		return true
	
	var candidate: PackedVector2Array = _points.duplicate()
	candidate.append(point)
	if is_simple(candidate) and not Array(_points).any(
			func(existing: Vector2) -> bool:
				return existing.distance_to(point) < MIN_POINT_DISTANCE
	):
		_points = candidate
		_stroke_changed()
	return true


func _draw_overlay(overlay: LDOverlay) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or _points.is_empty():
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	var preview: PackedVector2Array = get_preview_points()
	if draw_fill and preview.size() >= PolygonShape.MIN_POINTS and is_simple(preview):
		overlay.draw_world_polygon(to_world * preview, fill_color)
	
	for i: int in _points.size():
		overlay.draw_world_circle(
				to_world * _points[i],
				(
						CLOSE_RADIUS
						if i == 0 and _points.size() >= PolygonShape.MIN_POINTS
						else POINT_RADIUS
				),
				stroke_color,
		)
	overlay.draw_world_polyline(to_world * preview, stroke_color)


func get_preview_points() -> PackedVector2Array:
	var points: PackedVector2Array = _points.duplicate()
	if not points.is_empty():
		points.append(_cursor)
	
	return points


func snapped_mouse() -> Vector2:
	return editor.viewport_handler.snap(
			editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer)
	)


func to_screen(layer_point: Vector2) -> Vector2:
	var layer: LevelLayer = editor.level_handler.active_layer
	return editor.viewport_handler.to_screen(
			layer.get_objects_root().get_global_transform() * layer_point
	)


func reset() -> void:
	_points = PackedVector2Array()
	_stroke_changed()


@abstract func _finish(points: PackedVector2Array) -> void


func _can_begin(_world_position: Vector2) -> bool:
	return true


func _stroke_changed() -> void:
	pass


func _completion_points() -> PackedVector2Array:
	var points: PackedVector2Array = _points.duplicate()
	if points.is_empty() or points[points.size() - 1] != _cursor:
		var candidate: PackedVector2Array = points.duplicate()
		candidate.append(_cursor)
		if candidate.size() >= PolygonShape.MIN_POINTS and is_simple(candidate):
			return candidate
	
	return points


func _complete(points: PackedVector2Array) -> void:
	var finished: PackedVector2Array = points.duplicate()
	reset()
	if finished.size() >= PolygonShape.MIN_POINTS and is_simple(finished):
		_finish(finished)
