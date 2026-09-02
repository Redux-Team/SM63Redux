class_name LDPolygonBooleanDrawNode
extends Node2D

## Screen-space overlay for the boolean polygon tools: the stroke the user is drawing plus a
## ghost of what the operation would leave behind.


const PREVIEW_BORDER_WIDTH: float = 1.0


@export var fill_color: Color = Color(0.2, 0.8, 0.4, 0.2)
@export var border_color: Color = Color(0.2, 0.9, 0.4, 0.9)

var _preview_points: PackedVector2Array
var _is_valid: bool = true
var _results: Array[PackedVector2Array] = []


func update_data(preview: PackedVector2Array, valid: bool, results: Array[PackedVector2Array]) -> void:
	_preview_points = preview
	_is_valid = valid
	_results = results


func _draw() -> void:
	if _preview_points.size() < 2:
		return
	
	var fill: Color = fill_color if _is_valid else Color(LDPalette.gizmo_disabled(), 0.1)
	var border: Color = border_color if _is_valid else Color(LDPalette.gizmo_disabled(), 0.5)
	var screen_points: PackedVector2Array = _to_screen(_preview_points)
	
	if screen_points.size() >= 3:
		draw_colored_polygon(screen_points, fill)
	_draw_outline(screen_points, border)
	
	for result: PackedVector2Array in _results:
		if result.size() < 3:
			continue
		var result_screen: PackedVector2Array = _to_screen(result)
		draw_colored_polygon(result_screen, Color(LDPalette.vertex_fill(), 0.15))
		_draw_outline(result_screen, Color(LDPalette.gizmo_edge(), 0.4))


func _draw_outline(screen_points: PackedVector2Array, color: Color) -> void:
	var closed: PackedVector2Array = screen_points.duplicate()
	closed.append(screen_points.get(0))
	draw_polyline(closed, color, PREVIEW_BORDER_WIDTH, true)


func _to_screen(points: PackedVector2Array) -> PackedVector2Array:
	var xform: Transform2D = LD.get_editor_viewport().world_transform()
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(xform * p)
	return result
