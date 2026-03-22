@abstract class_name TerrainPolygon

static func ensure_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += (b.x - a.x) * (b.y + a.y)
	
	if area < 0.0:
		return points
	
	var reversed: PackedVector2Array = PackedVector2Array()
	for i: int in range(count - 1, -1, -1):
		reversed.append(points[i])
	
	return reversed


static func get_topline_segments(points: PackedVector2Array, threshold: float) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var edge: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(edge.y, -edge.x)
		
		if normal.y < -threshold:
			if current.is_empty():
				current.append(a)
			current.append(b)
		else:
			if not current.is_empty():
				segments.append(current)
				current = PackedVector2Array()
	
	if not current.is_empty():
		segments.append(current)
	
	return segments


static func subdivide_for_line2d(points: PackedVector2Array, texture: Texture2D) -> PackedVector2Array:
	if not texture or points.size() < 2:
		return points
	
	var tex_width: float = float(texture.get_width())
	var result: PackedVector2Array = PackedVector2Array()
	
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment_length: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(segment_length / tex_width)))
		
		result.append(a)
		for s: int in range(1, steps):
			result.append(a.lerp(b, float(s) / float(steps)))
	
	result.append(points[points.size() - 1])
	return result


static func get_closed_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


static func setup_line2d(line: Line2D) -> void:
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
