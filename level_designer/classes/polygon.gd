class_name LDPolygon


const BEZIER_STEPS: int = 24
const SNAP_SQ: float = 100.0
var segments: Array[LDSegment] = []


static func from_flat(points: PackedVector2Array) -> LDPolygon:
	var poly: LDPolygon = LDPolygon.new()
	for p: Vector2 in points:
		poly.segments.append(LDSegment.new(p))
	return poly


func duplicate() -> LDPolygon:
	var copy: LDPolygon = LDPolygon.new()
	for seg: LDSegment in segments:
		copy.segments.append(seg.duplicate())
	return copy


func to_flat() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = segments.size()
	for i: int in count:
		var seg: LDSegment = segments[i]
		var next_seg: LDSegment = segments[(i + 1) % count]
		if not seg.is_curve and not next_seg.is_curve:
			result.append(seg.point)
			continue
		var p0: Vector2 = seg.point
		var p3: Vector2 = next_seg.point
		var p1: Vector2 = p0 + seg.handle_out
		var p2: Vector2 = p3 + next_seg.handle_in
		for s: int in BEZIER_STEPS:
			var t: float = float(s) / float(BEZIER_STEPS)
			result.append(_cubic_bezier(p0, p1, p2, p3, t))
	return result


func boolean_result(new_flat: PackedVector2Array) -> LDPolygon:
	var result: LDPolygon = LDPolygon.new()
	var flat_size: int = new_flat.size()
	var count: int = segments.size()
	for ni: int in flat_size:
		var p: Vector2 = new_flat[ni]
		var next_p: Vector2 = new_flat[(ni + 1) % flat_size]
		var src: LDSegment = _find_segment_owning_edge(p, next_p, count)
		if src != null and src.is_curve:
			result.segments.append(LDSegment.new(p, true, src.handle_out, src.handle_in))
		else:
			result.segments.append(LDSegment.new(p))
	return result


func _find_segment_owning_edge(edge_start: Vector2, edge_end: Vector2, count: int) -> LDSegment:
	for i: int in count:
		var seg: LDSegment = segments[i]
		var next_seg: LDSegment = segments[(i + 1) % count]
		if not seg.is_curve and not next_seg.is_curve:
			continue
		var p0: Vector2 = seg.point
		var p3: Vector2 = next_seg.point
		var p1: Vector2 = p0 + seg.handle_out
		var p2: Vector2 = p3 + next_seg.handle_in
		if _edge_lies_on_bezier(edge_start, edge_end, p0, p1, p2, p3):
			return seg
	return null


func _edge_lies_on_bezier(a: Vector2, b: Vector2, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> bool:
	var t_a: float = _closest_t(p0, p1, p2, p3, a)
	var t_b: float = _closest_t(p0, p1, p2, p3, b)
	if a.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_a)) > SNAP_SQ:
		return false
	if b.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_b)) > SNAP_SQ:
		return false
	var wraps: bool = t_a > 0.85 and t_b < 0.15
	if t_b <= t_a and not wraps:
		return false
	return true


func _closest_t(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, target: Vector2) -> float:
	var best_t: float = 0.0
	var best_d: float = INF
	for s: int in BEZIER_STEPS + 1:
		var t: float = float(s) / float(BEZIER_STEPS)
		var d: float = target.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t))
		if d < best_d:
			best_d = d
			best_t = t
	for _i: int in 8:
		var p: Vector2 = _cubic_bezier(p0, p1, p2, p3, best_t)
		var d1: Vector2 = _bezier_d1(p0, p1, p2, p3, best_t)
		var d2: Vector2 = _bezier_d2(p0, p1, p2, p3, best_t)
		var f: float = (p - target).dot(d1)
		var df: float = d1.dot(d1) + (p - target).dot(d2)
		if df != 0.0:
			best_t = clamp(best_t - f / df, 0.0, 1.0)
	return best_t


static func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return mt * mt * mt * p0 + 3.0 * mt * mt * t * p1 + 3.0 * mt * t * t * p2 + t * t * t * p3


static func _bezier_d1(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 3.0 * mt * mt * (p1 - p0) + 6.0 * mt * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)


static func _bezier_d2(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 6.0 * mt * (p2 - 2.0 * p1 + p0) + 6.0 * t * (p3 - 2.0 * p2 + p1)
