class_name LDPolygonBooleanDrawNode
extends Node2D


var _preview_points: PackedVector2Array = PackedVector2Array()
var _results: Array[PackedVector2Array] = []
var _is_valid: bool = false
var fill_color: Color = Color(0.2, 0.8, 0.4, 0.2)
var border_color: Color = Color(0.2, 0.9, 0.4, 0.9)
var invalid_color: Color = Color(0.5, 0.5, 0.5, 0.3)
var invalid_border_color: Color = Color(0.5, 0.5, 0.5, 0.6)
var border_width: float = 2.0
var result_fill_color: Color = Color(0.2, 0.5, 1.0, 0.25)
var result_border_color: Color = Color(0.4, 0.7, 1.0, 0.8)
var result_border_width: float = 1.5

var points: PackedVector2Array:
	set(value):
		_preview_points = value
	get:
		return _preview_points

var preview_polygons: Array[PackedVector2Array]:
	set(value):
		_results = value
	get:
		return _results

var is_valid: bool:
	set(value):
		_is_valid = value
	get:
		return _is_valid


func _draw() -> void:
	var active_fill: Color = fill_color if _is_valid else invalid_color
	var active_border: Color = border_color if _is_valid else invalid_border_color
	if _preview_points.size() >= 2:
		var closed: PackedVector2Array = _preview_points.duplicate()
		closed.append(_preview_points[0])
		draw_polyline(closed, active_border, border_width)
	if _preview_points.size() >= 3:
		draw_colored_polygon(_preview_points, active_fill)
	for poly: PackedVector2Array in _results:
		if poly.size() < 3:
			continue
		draw_colored_polygon(poly, result_fill_color)
		var closed_poly: PackedVector2Array = poly.duplicate()
		closed_poly.append(poly[0])
		draw_polyline(closed_poly, result_border_color, result_border_width)
