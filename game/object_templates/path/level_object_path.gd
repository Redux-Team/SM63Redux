class_name LevelObjectPath
extends LevelObject


@export var line2d: Line2D
@export var subdivide_path: bool = false
@export var static_bodies: Array[StaticBody2D]


var path_points: PackedVector2Array = PackedVector2Array()


func _handle_property(property_name: String, property_value: Variant) -> void:
	if property_name == "path_points":
		_apply_points(property_value)
	else:
		super(property_name, property_value)


func _apply_points(points: PackedVector2Array) -> void:
	path_points = points
	
	var resolved: PackedVector2Array = _resolve_points()
	
	if line2d:
		line2d.points = resolved
	
	_on_points_changed(resolved)


func _resolve_points() -> PackedVector2Array:
	if subdivide_path and line2d and line2d.texture:
		return TerrainPolygon.subdivide_for_line2d(path_points, line2d.texture)
	return path_points.duplicate()


func get_path_points() -> PackedVector2Array:
	return _resolve_points()


func get_raw_points() -> PackedVector2Array:
	return path_points.duplicate()


func _on_points_changed(_resolved_points: PackedVector2Array) -> void:
	pass
