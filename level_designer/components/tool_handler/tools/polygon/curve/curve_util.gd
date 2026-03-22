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


static func auto_tangent_angle(ring: PackedVector2Array, index: int, handles: Dictionary) -> float:
	var count: int = ring.size()
	var prev_i: int = (index - 1 + count) % count
	var next_i: int = (index + 1) % count
	var curr: Vector2 = ring[index]
	var prev_pt: Vector2 = ring[prev_i]
	var next_pt: Vector2 = ring[next_i]
	var tan_in: Vector2
	var h_prev: LDCurveHandle = handles.get(prev_i) as LDCurveHandle
	if h_prev:
		tan_in = derivative(prev_pt, prev_pt + h_prev.out_offset, curr, curr, 0.99).normalized()
	else:
		tan_in = (curr - prev_pt).normalized()
	var tan_out: Vector2
	var h_next: LDCurveHandle = handles.get(next_i) as LDCurveHandle
	if h_next:
		tan_out = derivative(curr, curr, next_pt + h_next.in_offset, next_pt, 0.01).normalized()
	else:
		tan_out = (next_pt - curr).normalized()
	return (tan_in + tan_out).normalized().angle() + PI * 0.5


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


static func flatten_ring(ring: PackedVector2Array, handles: Dictionary, steps: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = ring.size()
	for i: int in count:
		var ni: int = (i + 1) % count
		var h_curr: LDCurveHandle = handles.get(i) as LDCurveHandle
		var h_next: LDCurveHandle = handles.get(ni) as LDCurveHandle
		if h_curr == null and h_next == null:
			result.append(ring[i])
			continue
		var p0: Vector2 = ring[i]
		var p3: Vector2 = ring[ni]
		var p1: Vector2 = p0 + (h_curr.out_offset if h_curr else Vector2.ZERO)
		var p2: Vector2 = p3 + (h_next.in_offset if h_next else Vector2.ZERO)
		for s: int in steps:
			result.append(cubic_bezier(p0, p1, p2, p3, float(s) / float(steps)))
	return result


static func invalidate_curve_meta(poly: LDObjectPolygon) -> void:
	if poly.has_meta(&"curve_handles"):
		poly.remove_meta(&"curve_handles")



static func snapshot_meta(poly: LDObjectPolygon) -> Dictionary:
	if poly.has_meta(&"curve_handles"):
		return (poly.get_meta(&"curve_handles") as Dictionary).duplicate(true)
	return {}


static func restore_meta(poly: LDObjectPolygon, snap: Dictionary) -> void:
	if snap.is_empty():
		if poly.has_meta(&"curve_handles"):
			poly.remove_meta(&"curve_handles")
	else:
		poly.set_meta(&"curve_handles", snap)


static func get_affected_outer_segments(ctrl_outer: PackedVector2Array, old_meta: Dictionary, cut_polygon: PackedVector2Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if ctrl_outer.size() < 3:
		return result
	var count: int = ctrl_outer.size()
	for i: int in count:
		var ni: int = (i + 1) % count
		var key: String = "hk_o:" + str(i)
		var next_key: String = "hk_o:" + str(ni)
		var h_curr_arr: Variant = old_meta.get(key)
		var h_next_arr: Variant = old_meta.get(next_key)
		var is_curve: bool = h_curr_arr != null or h_next_arr != null
		if not is_curve:
			continue
		var p0: Vector2 = ctrl_outer[i]
		var p3: Vector2 = ctrl_outer[ni]
		var h_out: Vector2 = Vector2.ZERO
		var h_in: Vector2 = Vector2.ZERO
		if h_curr_arr != null:
			var arr: Array = h_curr_arr as Array
			if arr.size() == 4:
				h_out = Vector2(float(arr[2]), float(arr[3]))
		if h_next_arr != null:
			var arr: Array = h_next_arr as Array
			if arr.size() == 4:
				h_in = Vector2(float(arr[0]), float(arr[1]))
		var p1: Vector2 = p0 + h_out
		var p2: Vector2 = p3 + h_in
		var sampled: bool = false
		for s: int in range(13):
			var t: float = float(s) / 12.0
			var pt: Vector2 = cubic_bezier(p0, p1, p2, p3, t)
			if Geometry2D.is_point_in_polygon(pt, cut_polygon):
				sampled = true
				break
		if sampled:
			result.append(i)
	return result


static func selective_bake_meta(
	new_outer: PackedVector2Array,
	old_meta: Dictionary,
	old_outer: PackedVector2Array,
	affected_segments: PackedInt32Array,
	outer_changed: bool
) -> Dictionary:
	if old_meta.is_empty():
		return {"ctrl_outer": new_outer.duplicate(), "hole_count": 0}
	var new_data: Dictionary = {
		"ctrl_outer": new_outer.duplicate(),
		"hole_count": 0,
	}
	if outer_changed:
		return new_data
	var affected_set: Dictionary = {}
	for idx: int in affected_segments:
		affected_set[idx] = true
	var count: int = old_outer.size()
	for i: int in count:
		if affected_set.has(i):
			continue
		var key: String = "hk_o:" + str(i)
		if old_meta.has(key):
			new_data[key] = old_meta[key]
	return new_data
