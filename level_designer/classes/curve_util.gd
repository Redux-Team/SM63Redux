class_name LDCurveUtil


static func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return mt * mt * mt * p0 + 3.0 * mt * mt * t * p1 + 3.0 * mt * t * t * p2 + t * t * t * p3


static func derivative(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 3.0 * mt * mt * (p1 - p0) + 6.0 * mt * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)


static func second_derivative(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 6.0 * mt * (p2 - 2.0 * p1 + p0) + 6.0 * t * (p3 - 2.0 * p2 + p1)


static func closest_t_on_segment(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, mouse: Vector2) -> float:
	var best_t: float = 0.0
	var best_d: float = INF
	for i: int in range(11):
		var t: float = float(i) / 10.0
		var d: float = cubic_bezier(p0, p1, p2, p3, t).distance_squared_to(mouse)
		if d < best_d:
			best_d = d
			best_t = t
	for _i: int in range(4):
		var p: Vector2 = cubic_bezier(p0, p1, p2, p3, best_t)
		var d1: Vector2 = derivative(p0, p1, p2, p3, best_t)
		var d2: Vector2 = second_derivative(p0, p1, p2, p3, best_t)
		var f: float = (p - mouse).dot(d1)
		var df: float = d1.dot(d1) + (p - mouse).dot(d2)
		if df != 0.0:
			best_t -= clamp(f / df, -0.25, 0.25)
		best_t = clamp(best_t, 0.0, 1.0)
	return best_t


static func auto_tangent_angle(segments: Array[LDSegment], index: int) -> float:
	var count: int = segments.size()
	var prev_i: int = (index - 1 + count) % count
	var next_i: int = (index + 1) % count
	var curr: Vector2 = segments[index].point
	var prev_pt: Vector2 = segments[prev_i].point
	var next_pt: Vector2 = segments[next_i].point
	var tan_in: Vector2
	var prev_seg: LDSegment = segments[prev_i]
	if prev_seg.is_curve:
		var p0: Vector2 = prev_pt
		var p3: Vector2 = curr
		var p1: Vector2 = p0 + prev_seg.handle_out
		var p2: Vector2 = p3 + segments[index].handle_in
		tan_in = derivative(p0, p1, p2, p3, 0.99).normalized()
	else:
		tan_in = (curr - prev_pt).normalized()
	var tan_out: Vector2
	var curr_seg: LDSegment = segments[index]
	if curr_seg.is_curve:
		var p0: Vector2 = curr
		var p3: Vector2 = next_pt
		var p1: Vector2 = p0 + curr_seg.handle_out
		var p2: Vector2 = p3 + segments[next_i].handle_in
		tan_out = derivative(p0, p1, p2, p3, 0.01).normalized()
	else:
		tan_out = (next_pt - curr).normalized()
	return (tan_in + tan_out).normalized().angle() + PI * 0.5


static func flatten_ring(segments: Array[LDSegment]) -> PackedVector2Array:
	var poly: LDPolygon = LDPolygon.new()
	poly.segments = segments
	return poly.to_flat()
