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
	var n: int = new_flat.size()
	if n < 3:
		return result
	
	var seg_count: int = segments.size()
	var sources: Array[int] = []
	sources.resize(n)
	for i: int in n:
		var a: Vector2 = new_flat[i]
		var b: Vector2 = new_flat[(i + 1) % n]
		sources[i] = _find_edge_source(a, b, seg_count)
	
	var runs: Array[Dictionary] = []
	var start_idx: int = 0
	for i: int in n:
		if sources[i] != sources[(i - 1 + n) % n]:
			start_idx = i
			break
	
	var curr_source: int = sources[start_idx]
	var run_start: int = start_idx
	var count: int = 0
	
	while count < n:
		var idx: int = (start_idx + count) % n
		var next_idx: int = (idx + 1) % n
		if count == n - 1 or sources[next_idx] != curr_source:
			runs.append({
				"source": curr_source,
				"start": run_start,
				"end": idx
			})
			run_start = next_idx
			curr_source = sources[next_idx]
		count += 1
	
	var new_segments: Array[LDSegment] = []
	var next_handle_ins: Array[Vector2] = []
	
	for run: Dictionary in runs:
		var src: int = run["source"] as int
		var s_idx: int = run["start"] as int
		var e_idx: int = run["end"] as int
		
		if src == -1:
			var k: int = s_idx
			while true:
				var p: Vector2 = new_flat[k]
				new_segments.append(LDSegment.new(p))
				next_handle_ins.append(Vector2.ZERO)
				if k == e_idx:
					break
				k = (k + 1) % n
		else:
			var p_start: Vector2 = new_flat[s_idx]
			var p_end: Vector2 = new_flat[(e_idx + 1) % n]
			var orig_seg: LDSegment = segments[src]
			var orig_next: LDSegment = segments[(src + 1) % seg_count]
			
			if orig_seg.is_curve or orig_next.is_curve:
				var p0: Vector2 = orig_seg.point
				var p3: Vector2 = orig_next.point
				var p1: Vector2 = p0 + orig_seg.handle_out
				var p2: Vector2 = p3 + orig_next.handle_in
				
				var t_start: float = _closest_t(p0, p1, p2, p3, p_start)
				var t_end: float = _closest_t(p0, p1, p2, p3, p_end)
				
				var reverse: bool = t_start > t_end
				var sub: Dictionary
				if reverse:
					sub = _extract_subcurve(p0, p1, p2, p3, t_end, t_start)
				else:
					sub = _extract_subcurve(p0, p1, p2, p3, t_start, t_end)
				
				var new_seg: LDSegment = LDSegment.new(p_start, true)
				if reverse:
					new_seg.handle_out = (sub["p2"] as Vector2) - p_start
					new_segments.append(new_seg)
					next_handle_ins.append((sub["p1"] as Vector2) - p_end)
				else:
					new_seg.handle_out = (sub["p1"] as Vector2) - p_start
					new_segments.append(new_seg)
					next_handle_ins.append((sub["p2"] as Vector2) - p_end)
			else:
				new_segments.append(LDSegment.new(p_start))
				next_handle_ins.append(Vector2.ZERO)
	
	var final_count: int = new_segments.size()
	for i: int in final_count:
		var seg: LDSegment = new_segments[i]
		var next_idx: int = (i + 1) % final_count
		var next_seg: LDSegment = new_segments[next_idx]
		
		var h_in: Vector2 = next_handle_ins[i]
		if h_in != Vector2.ZERO:
			next_seg.handle_in = h_in
			next_seg.is_curve = true
		
		result.segments.append(seg)
	
	return result


func _find_edge_source(a: Vector2, b: Vector2, count: int) -> int:
	for i: int in count:
		var seg: LDSegment = segments[i]
		var next_seg: LDSegment = segments[(i + 1) % count]
		var p0: Vector2 = seg.point
		var p3: Vector2 = next_seg.point
		
		if not seg.is_curve and not next_seg.is_curve:
			if _point_on_segment(a, p0, p3) and _point_on_segment(b, p0, p3):
				return i
		else:
			var p1: Vector2 = p0 + seg.handle_out
			var p2: Vector2 = p3 + next_seg.handle_in
			if _edge_lies_on_bezier(a, b, p0, p1, p2, p3):
				return i
	return -1


func _point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return p.distance_squared_to(a) < SNAP_SQ
	var ap: Vector2 = p - a
	var t: float = ap.dot(ab) / ab_len_sq
	if t < -0.05 or t > 1.05:
		return false
	var proj: Vector2 = a + ab * t
	return p.distance_squared_to(proj) < SNAP_SQ


func _edge_lies_on_bezier(a: Vector2, b: Vector2, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> bool:
	var t_a: float = _closest_t(p0, p1, p2, p3, a)
	var t_b: float = _closest_t(p0, p1, p2, p3, b)
	if a.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_a)) > SNAP_SQ:
		return false
	if b.distance_squared_to(_cubic_bezier(p0, p1, p2, p3, t_b)) > SNAP_SQ:
		return false
	return true


static func _extract_subcurve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t0: float, t1: float) -> Dictionary:
	if t0 <= 0.001 and t1 >= 0.999:
		return {"p0": p0, "p1": p1, "p2": p2, "p3": p3}
	
	var right_part: Dictionary = _decasteljau_split_at_t(p0, p1, p2, p3, t0)
	var split_p0: Vector2 = right_part["right_p0"] as Vector2
	var split_p1: Vector2 = right_part["right_p1"] as Vector2
	var split_p2: Vector2 = right_part["right_p2"] as Vector2
	var split_p3: Vector2 = right_part["right_p3"] as Vector2
	
	if t1 >= 0.999 or is_equal_approx(t0, 1.0):
		return {"p0": split_p0, "p1": split_p1, "p2": split_p2, "p3": split_p3}
	
	var u1: float = clamp((t1 - t0) / (1.0 - t0), 0.0, 1.0)
	var final_part: Dictionary = _decasteljau_split_at_t(split_p0, split_p1, split_p2, split_p3, u1)
	
	return {
		"p0": final_part["left_p0"],
		"p1": final_part["left_p1"],
		"p2": final_part["left_p2"],
		"p3": final_part["left_p3"]
	}


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
