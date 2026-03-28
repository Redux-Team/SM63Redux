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


static func ensure_counter_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += (b.x - a.x) * (b.y + a.y)
	if area > 0.0:
		return points
	var reversed: PackedVector2Array = PackedVector2Array()
	for i: int in range(count - 1, -1, -1):
		reversed.append(points[i])
	return reversed


static func build_seam_polygon(outer: PackedVector2Array, hole: PackedVector2Array) -> Dictionary:
	var cw_outer: PackedVector2Array = ensure_clockwise(outer)
	var ccw_hole: PackedVector2Array = ensure_counter_clockwise(hole)
	
	var best_dist: float = INF
	var outer_idx: int = 0
	var hole_idx: int = 0
	
	for i: int in cw_outer.size():
		for j: int in ccw_hole.size():
			var d: float = cw_outer[i].distance_to(ccw_hole[j])
			if d < best_dist:
				best_dist = d
				outer_idx = i
				hole_idx = j
	
	var result: PackedVector2Array = PackedVector2Array()
	var seam_indices: PackedInt32Array = PackedInt32Array()
	
	for i: int in outer_idx + 1:
		result.append(cw_outer[i])
	
	seam_indices.append(result.size() - 1)
	
	for i: int in ccw_hole.size():
		result.append(ccw_hole[(hole_idx + i) % ccw_hole.size()])
	result.append(ccw_hole[hole_idx])
	
	seam_indices.append(result.size() - 1)
	
	for i: int in range(outer_idx, cw_outer.size()):
		result.append(cw_outer[i])
	
	return {"polygon": result, "seam_indices": seam_indices}


static func get_topline_segments(points: PackedVector2Array, threshold: float, seam_indices: PackedInt32Array = PackedInt32Array(), invert_normal: bool = false) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	
	for i: int in count:
		if i in seam_indices:
			if not current.is_empty():
				segments.append(current)
				current = PackedVector2Array()
			continue
		
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var edge: Vector2 = (b - a).normalized()
		if invert_normal:
			edge = -edge
		var normal: Vector2 = Vector2(edge.y, -edge.x)
		var is_top: bool = normal.y < -threshold
		
		if is_top:
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


static func get_outline_points(points: PackedVector2Array, seam_indices: PackedInt32Array = PackedInt32Array()) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	
	for i: int in count:
		if i in seam_indices:
			if not current.is_empty():
				current.append(points[i])
				segments.append(current)
				current = PackedVector2Array()
			continue
		if current.is_empty():
			current.append(points[i])
		else:
			current.append(points[i])
	
	if not current.is_empty():
		if not seam_indices.is_empty():
			segments.append(current)
		else:
			current.append(points[0])
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


static func clean_polygon(points: PackedVector2Array, epsilon: float = 0.5) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	for i: int in count:
		var curr: Vector2 = points[i]
		var prev: Vector2 = points[(i - 1 + count) % count]
		if curr.distance_to(prev) < epsilon:
			continue
		result.append(curr)
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


static func reverse_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in range(points.size() - 1, -1, -1):
		result.append(points[i])
	return result
