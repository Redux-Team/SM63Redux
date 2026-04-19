@tool
class_name LDPropertyPathPoints
extends LDProperty


func _init() -> void:
	key = &"path_points"
	label = "Path Points"
	type = LDProperty.Type.ARRAY_VECTOR2
	default_value = PackedVector2Array()
	visible_in_editor = false


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	var points: PackedVector2Array = _parse(value)
	obj._points = points
	obj._on_points_changed(points)


func _parse(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value
	if value is Array:
		var result: PackedVector2Array = []
		for entry: Variant in value:
			if entry is Array and entry.size() >= 2:
				result.append(Vector2(float(entry[0]), float(entry[1])))
		return result
	if value is String:
		return _parse_string(value)
	return PackedVector2Array()


func _parse_string(s: String) -> PackedVector2Array:
	var result: PackedVector2Array = []
	var inner: String = s.strip_edges().trim_prefix("[").trim_suffix("]")
	var pattern: RegEx = RegEx.new()
	pattern.compile(r"\(([^)]+)\)")
	for match: RegExMatch in pattern.search_all(inner):
		var parts: PackedStringArray = match.get_string(1).split(",")
		if parts.size() >= 2:
			result.append(Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges())))
	return result
