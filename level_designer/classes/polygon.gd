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
	var seg_count: int = segments.size()
	for ni: int in flat_size:
		var p: Vector2 = new_flat[ni]
		var next_p: Vector2 = new_flat[(ni + 1) % flat_size]
		var original: LDSegment = _find_exact_segment(p, seg_count)
		if original != null:
			result.segments.append(original.duplicate())
			continue
		var info: Dictionary = _find_bezier_edge_info(p, next_p, seg_count)
		if not info.is_empty():
			var split: Dictionary = _decasteljau_split_at_t(
				info["p0"] as Vector2,
				info["p1"] as Vector2,
				info["p2"] as Vector2,
				info["p3"] as Vector2,
				info["t_start"] as float
			)
			var new_seg: LDSegment = LDSegment.new(p, true)
			new_seg.handle_in = (split["left_p2"] as Vector2) - p
			new_seg.handle_out = (split["right_p1"] as Vector2) - p
			result.segments.append(new_seg)
		else:
			result.segments.append(LDSegment.new(p))
	_fix_next_handles(result, new_flat, seg_count)
	return result


func boolean_result_world(new_flat_world: PackedVector2Array, local_offset: Vector2) -> LDPolygon:
	var shifted: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in new_flat_world:
		shifted.append(p - local_offset)
	return boolean_result(shifted)


func _find_exact_segment(p: Vector2, _count: int) -> LDSegment:
	for seg: LDSegment in segments:
		if seg.point.distance_squared_to(p) < SNAP_SQ:
			return seg
	return null


func _find_bezier_edge_info(edge_start: Vector2, edge_end: Vector2, count: int) -> Dictionary:
	for i: int in count:
		var seg: LDSegment = segments[i]
		var next_seg: LDSegment = segments[(i + 1) % count]
		if not seg.is_curve and not next_seg.is_curve:
			continue
		var p0: Vector2 = seg.point
		var p3: Vector2 = next_seg.point
		var p1: Vector2 = p0 + seg.handle_out
		var p2: Vector2 = p3 + next_seg.handle_in
		var t_a: float = _closest_t(p0, p1, p2, p3, edge_start)
		var t_b: float = _closest_t(p0, p1, p2, p3, edge_end)
		if edge_start.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_a)) > SNAP_SQ:
			continue
		if edge_end.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_b)) > SNAP_SQ:
			continue
		var wraps: bool = t_a > 0.85 and t_b < 0.15
		if t_b <= t_a and not wraps:
			continue
		return {"t_start": t_a, "t_end": t_b, "p0": p0, "p1": p1, "p2": p2, "p3": p3}
	return {}


func _fix_next_handles(result: LDPolygon, new_flat: PackedVector2Array, seg_count: int) -> void:
	var res_count: int = result.segments.size()
	for ni: int in res_count:
		var curr_seg: LDSegment = result.segments[ni]
		var next_seg: LDSegment = result.segments[(ni + 1) % res_count]
		if not curr_seg.is_curve:
			continue
		if next_seg.is_curve:
			continue
		var next_p: Vector2 = new_flat[(ni + 1) % new_flat.size()]
		var info: Dictionary = _find_bezier_edge_info(curr_seg.point, next_p, seg_count)
		if info.is_empty():
			continue
		var split: Dictionary = _decasteljau_split_at_t(
			info["p0"] as Vector2,
			info["p1"] as Vector2,
			info["p2"] as Vector2,
			info["p3"] as Vector2,
			info["t_end"] as float
		)
		next_seg.is_curve = true
		next_seg.handle_in = (split["left_p2"] as Vector2) - next_p
		if next_seg.handle_out == Vector2.ZERO:
			next_seg.handle_out = (split["right_p1"] as Vector2) - next_p


static func _decasteljau_split_at_t(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Dictionary:
	var q0: Vector2 = p0.lerp(p1, t)
	var q1: Vector2 = p1.lerp(p2, t)
	var q2: Vector2 = p2.lerp(p3, t)
	var r0: Vector2 = q0.lerp(q1, t)
	var r1: Vector2 = q1.lerp(q2, t)
	var s: Vector2 = r0.lerp(r1, t)
	return {
		"left_p0": p0,
		"left_p1": q0,
		"left_p2": r0,
		"left_p3": s,
		"right_p0": s,
		"right_p1": r1,
		"right_p2": q2,
		"right_p3": p3,
	}


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
