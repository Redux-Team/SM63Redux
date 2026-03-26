class_name LDPolygon


const BEZIER_STEPS: int = 24
const SNAP_SQ: float = 100.0
const BAKE_SNAP_SQ: float = 4.0


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
	var processed: int = 0
	while processed < n:
		var idx: int = (start_idx + processed) % n
		var next_idx: int = (idx + 1) % n
		if processed == n - 1 or sources[next_idx] != curr_source:
			runs.append({"source": curr_source, "start": run_start, "end": idx})
			run_start = next_idx
			curr_source = sources[next_idx]
		processed += 1
	for run: Dictionary in runs:
		var src: int = run["source"] as int
		var s_idx: int = run["start"] as int
		var e_idx: int = run["end"] as int
		if src == -1:
			var k: int = s_idx
			while true:
				result.segments.append(LDSegment.new(new_flat[k]))
				if k == e_idx:
					break
				k = (k + 1) % n
			continue
		var orig_seg: LDSegment = segments[src]
		var orig_next: LDSegment = segments[(src + 1) % seg_count]
		if not orig_seg.is_curve and not orig_next.is_curve:
			var k: int = s_idx
			while true:
				result.segments.append(LDSegment.new(new_flat[k]))
				if k == e_idx:
					break
				k = (k + 1) % n
			continue
		var p_start: Vector2 = new_flat[s_idx]
		var p_end: Vector2 = new_flat[(e_idx + 1) % n]
		var p0: Vector2 = orig_seg.point
		var p3: Vector2 = orig_next.point
		var p1: Vector2 = p0 + orig_seg.handle_out
		var p2: Vector2 = p3 + orig_next.handle_in
		var start_is_anchor: bool = _find_exact_segment(p_start) != null
		var end_is_anchor: bool = _find_exact_segment(p_end) != null
		if not start_is_anchor and not end_is_anchor:
			var k: int = s_idx
			while true:
				result.segments.append(LDSegment.new(new_flat[k]))
				if k == e_idx:
					break
				k = (k + 1) % n
			continue
		var t_start: float = _closest_t(p0, p1, p2, p3, p_start)
		var t_end: float = _closest_t(p0, p1, p2, p3, p_end)
		if start_is_anchor and not end_is_anchor:
			var exact: LDSegment = _find_exact_segment(p_start)
			result.segments.append(exact.duplicate())
			var k: int = (s_idx + 1) % n
			while true:
				result.segments.append(LDSegment.new(new_flat[k]))
				if k == e_idx:
					break
				k = (k + 1) % n
			continue
		if end_is_anchor and not start_is_anchor:
			var k: int = s_idx
			while true:
				result.segments.append(LDSegment.new(new_flat[k]))
				if k == e_idx:
					break
				k = (k + 1) % n
			continue
		var exact_start: LDSegment = _find_exact_segment(p_start)
		if exact_start != null:
			result.segments.append(exact_start.duplicate())
			var inner_start: int = (s_idx + 1) % n
			if inner_start != (e_idx + 1) % n:
				var k: int = inner_start
				while k != (e_idx + 1) % n:
					result.segments.append(LDSegment.new(new_flat[k]))
					k = (k + 1) % n
			continue
		var reverse: bool = t_start > t_end + 0.01
		var sub: Dictionary
		if reverse:
			sub = _extract_subcurve(p0, p1, p2, p3, t_end, t_start)
		else:
			sub = _extract_subcurve(p0, p1, p2, p3, t_start, t_end)
		var new_start: LDSegment = LDSegment.new(p_start, true)
		if reverse:
			new_start.handle_out = (sub["p2"] as Vector2) - p_start
		else:
			new_start.handle_out = (sub["p1"] as Vector2) - p_start
		result.segments.append(new_start)
		var inner_idx: int = (s_idx + 1) % n
		while inner_idx != e_idx:
			result.segments.append(LDSegment.new(new_flat[inner_idx]))
			inner_idx = (inner_idx + 1) % n
		if e_idx != s_idx:
			var end_seg: LDSegment = LDSegment.new(p_end)
			var exact_end: LDSegment = _find_exact_segment(p_end)
			if exact_end != null:
				end_seg = exact_end.duplicate()
			else:
				end_seg.is_curve = true
				if reverse:
					end_seg.handle_in = (sub["p1"] as Vector2) - p_end
				else:
					end_seg.handle_in = (sub["p2"] as Vector2) - p_end
			result.segments.append(end_seg)
	return result



func bake_with_tags() -> Array[LDBakedPoint]:
	var result: Array[LDBakedPoint] = []
	var count: int = segments.size()
	for i: int in count:
		var seg: LDSegment = segments[i]
		var next_seg: LDSegment = segments[(i + 1) % count]
		if not seg.is_curve and not next_seg.is_curve:
			result.append(LDBakedPoint.new(seg.point, i, 0.0, true))
			continue
		var p0: Vector2 = seg.point
		var p3: Vector2 = next_seg.point
		var p1: Vector2 = p0 + seg.handle_out
		var p2: Vector2 = p3 + next_seg.handle_in
		for s: int in BEZIER_STEPS:
			var t: float = float(s) / float(BEZIER_STEPS)
			result.append(LDBakedPoint.new(
				_cubic_bezier(p0, p1, p2, p3, t), i, t, s == 0
			))
	return result


func boolean_result_tagged(new_flat: PackedVector2Array, baked: Array[LDBakedPoint]) -> LDPolygon:
	var n: int = new_flat.size()
	if n < 3:
		return LDPolygon.new()
	var seg_count: int = segments.size()
	var tags: Array[LDBakedPoint] = []
	tags.resize(n)
	for i: int in n:
		tags[i] = _find_tag(new_flat[i], baked)
	var arc_intact: Array[bool] = _find_intact_arcs(tags, n, seg_count)
	var result: LDPolygon = LDPolygon.new()
	var i: int = 0
	while i < n:
		var tag: LDBakedPoint = tags[i]
		if tag != null and tag.is_anchor:
			var arc_idx: int = tag.segment_index
			if arc_intact[arc_idx]:
				result.segments.append(segments[arc_idx].duplicate())
				var steps: int = _arc_baked_count(arc_idx)
				i += steps
				continue
		result.segments.append(LDSegment.new(new_flat[i]))
		i += 1
	return result


func _find_intact_arcs(tags: Array[LDBakedPoint], n: int, seg_count: int) -> Array[bool]:
	var arc_intact: Array[bool] = []
	arc_intact.resize(seg_count)
	for a: int in seg_count:
		arc_intact[a] = false
	var arc_baked_starts: Array[int] = []
	arc_baked_starts.resize(seg_count)
	for a: int in seg_count:
		arc_baked_starts[a] = -1
	for i: int in n:
		var tag: LDBakedPoint = tags[i]
		if tag == null or not tag.is_anchor:
			continue
		arc_baked_starts[tag.segment_index] = i
	for a: int in seg_count:
		var start_flat: int = arc_baked_starts[a]
		if start_flat == -1:
			continue
		var expected_steps: int = _arc_baked_count(a)
		var end_anchor_arc: int = (a + 1) % seg_count
		var end_flat: int = (start_flat + expected_steps) % n
		var end_tag: LDBakedPoint = tags[end_flat]
		if end_tag == null:
			continue
		if not end_tag.is_anchor or end_tag.segment_index != end_anchor_arc:
			continue
		var all_match: bool = true
		for step: int in expected_steps:
			var flat_idx: int = (start_flat + step) % n
			var t: LDBakedPoint = tags[flat_idx]
			if t == null or t.segment_index != a:
				all_match = false
				break
		if all_match:
			arc_intact[a] = true
	return arc_intact


func _arc_baked_count(arc_idx: int) -> int:
	var seg: LDSegment = segments[arc_idx]
	var next_seg: LDSegment = segments[(arc_idx + 1) % segments.size()]
	if not seg.is_curve and not next_seg.is_curve:
		return 1
	return BEZIER_STEPS


func _build_runs(tags: Array[LDBakedPoint], n: int) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var search_start: int = 0
	for i: int in n:
		var cur: int = -1 if tags[i] == null else tags[i].segment_index
		var prev: int = -1 if tags[(i - 1 + n) % n] == null else tags[(i - 1 + n) % n].segment_index
		if cur != prev:
			search_start = i
			break
	var run_src: int = -1 if tags[search_start] == null else tags[search_start].segment_index
	var run_start: int = search_start
	for step: int in n:
		var idx: int = (search_start + step) % n
		var next_idx: int = (search_start + step + 1) % n
		var next_src: int = -1 if tags[next_idx] == null else tags[next_idx].segment_index
		if next_src != run_src or step == n - 1:
			runs.append({"src": run_src, "start": run_start, "end": idx})
			run_start = (idx + 1) % n
			run_src = next_src
	return runs


func _run_len(s_idx: int, e_idx: int, n: int) -> int:
	if e_idx >= s_idx:
		return e_idx - s_idx + 1
	return n - s_idx + e_idx + 1


func _assign_handle_ins(result: LDPolygon, new_flat: PackedVector2Array, baked: Array[LDBakedPoint], seg_count: int) -> void:
	var res_count: int = result.segments.size()
	var n: int = new_flat.size()
	for i: int in res_count:
		var seg: LDSegment = result.segments[i]
		if not seg.is_curve:
			continue
		var next_seg: LDSegment = result.segments[(i + 1) % res_count]
		if next_seg.handle_in != Vector2.ZERO:
			continue
		var next_flat: Vector2 = new_flat[(i + 1) % n]
		var next_tag: LDBakedPoint = _find_tag(next_flat, baked)
		if next_tag == null:
			continue
		var orig_seg: LDSegment = segments[next_tag.segment_index]
		var orig_next: LDSegment = segments[(next_tag.segment_index + 1) % seg_count]
		if not orig_seg.is_curve and not orig_next.is_curve:
			continue
		var p0: Vector2 = orig_seg.point
		var p3: Vector2 = orig_next.point
		var p1: Vector2 = p0 + orig_seg.handle_out
		var p2: Vector2 = p3 + orig_next.handle_in
		var curr_tag: LDBakedPoint = _find_tag(seg.point, baked)
		var t_start: float = curr_tag.t if curr_tag != null else 0.0
		var t_end: float = next_tag.t if next_tag != null else 1.0
		if t_end <= t_start:
			continue
		var sub: Dictionary = _extract_subcurve(p0, p1, p2, p3, t_start, t_end)
		next_seg.handle_in = (sub["p2"] as Vector2) - next_flat
		if not next_seg.is_curve:
			next_seg.is_curve = true


func _find_tag(p: Vector2, baked: Array[LDBakedPoint]) -> LDBakedPoint:
	var best: LDBakedPoint = null
	var best_d: float = INF
	for bp: LDBakedPoint in baked:
		var d: float = bp.position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = bp
	if best_d < BAKE_SNAP_SQ * 16.0:
		return best
	return null


func _find_exact_segment(p: Vector2) -> LDSegment:
	for seg: LDSegment in segments:
		if seg.point.distance_squared_to(p) < SNAP_SQ:
			return seg
	return null


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
