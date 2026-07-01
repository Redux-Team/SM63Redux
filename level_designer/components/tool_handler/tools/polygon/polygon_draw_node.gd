class_name LDPolygonBooleanDrawNode
extends Node2D


var _preview_points: PackedVector2Array
var _is_valid: bool = true
var _results: Array[PackedVector2Array] = []
var _targets: Array[LDObjectPolygon] = []
var fill_color: Color = Color(0.2, 0.8, 0.4, 0.2)
var border_color: Color = Color(0.2, 0.9, 0.4, 0.9)

const PREVIEW_BORDER_WIDTH: float = 1.0


func update_data(
	preview: PackedVector2Array,
	valid: bool,
	results: Array[PackedVector2Array],
	targets: Array[LDObjectPolygon]
) -> void:
	_preview_points = preview
	_is_valid = valid
	_results = results
	_targets = targets


func _draw() -> void:
	if _preview_points.size() < 2:
		return
	
	var invalid_fill: Color = Color(LDPalette.gizmo_disabled(), 0.1)
	var invalid_border: Color = Color(LDPalette.gizmo_disabled(), 0.5)
	var result_fill: Color = Color(LDPalette.vertex_fill(), 0.15)
	var result_border: Color = Color(LDPalette.gizmo_edge(), 0.4)
	var f: Color = fill_color if _is_valid else invalid_fill
	var b: Color = border_color if _is_valid else invalid_border
	var screen_points: PackedVector2Array = _to_screen(_preview_points)
	
	if screen_points.size() >= 3:
		draw_colored_polygon(screen_points, f)
	
	var closed: PackedVector2Array = screen_points.duplicate()
	closed.append(screen_points[0])
	draw_polyline(closed, b, PREVIEW_BORDER_WIDTH, true)
	
	for result: PackedVector2Array in _results:
		if result.size() < 3:
			continue
		var result_screen: PackedVector2Array = _to_screen(result)
		draw_colored_polygon(result_screen, result_fill)
		var result_closed: PackedVector2Array = result_screen.duplicate()
		result_closed.append(result_screen[0])
		draw_polyline(result_closed, result_border, PREVIEW_BORDER_WIDTH, true)


func _to_screen(points: PackedVector2Array) -> PackedVector2Array:
	var vp: LDViewport = LD.get_editor_viewport()
	var full_transform: Transform2D = vp.get_viewport().get_canvas_transform() * vp.get_root().get_global_transform()
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(full_transform * p)
	return result
