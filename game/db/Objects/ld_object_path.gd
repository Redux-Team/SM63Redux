@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObjectPath
extends LDObject

@export var subdivide_path: bool = false

var _points: PackedVector2Array = PackedVector2Array()
var _preview_valid: bool = true


func set_preview_valid(valid: bool) -> void:
	_preview_valid = valid
	_on_preview_valid_changed(valid)


func apply_points(points: PackedVector2Array) -> void:
	_points = points.duplicate()
	_property_values[&"path_points"] = _points
	_on_points_changed(_points)


func get_path_points(texture: Texture2D = null) -> PackedVector2Array:
	if subdivide_path and texture:
		return TerrainPolygon.subdivide_for_line2d(_points, texture)
	return _points.duplicate()


func get_control_points() -> PackedVector2Array:
	return _points.duplicate()


func place() -> void:
	set_property(&"path_points", _points)
	super()


func _on_preview_valid_changed(_valid: bool) -> void:
	pass


func _on_points_changed(_points: PackedVector2Array) -> void:
	pass
