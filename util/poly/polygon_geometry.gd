@abstract class_name TerrainPolygon


const LINE_SHADER: Shader = preload("uid://bmil47d5swbbn")


class LineStyle:
	var width: float
	var texture: Texture2D
	var color: Color
	var scroll_speed: float
	var ripple_amplitude: float
	var ripple_frequency: float
	var ripple_speed: float
	
	
	func _init(p_width: float, p_texture: Texture2D, p_color: Color,
			p_scroll: float = 0.0, p_ripple_amp: float = 0.0,
			p_ripple_freq: float = 1.0, p_ripple_speed: float = 1.0) -> void:
		width = p_width
		texture = p_texture
		color = p_color
		scroll_speed = p_scroll
		ripple_amplitude = p_ripple_amp
		ripple_frequency = p_ripple_freq
		ripple_speed = p_ripple_speed
	
	
	func is_animated() -> bool:
		return scroll_speed != 0.0 or ripple_amplitude != 0.0


class CapStyle:
	var left_texture: Texture2D
	var right_texture: Texture2D
	var inset: float
	
	
	func _init(p_left: Texture2D, p_right: Texture2D, p_inset: float) -> void:
		left_texture = p_left
		right_texture = p_right
		inset = p_inset
	
	
	func left_offset() -> float:
		return (left_texture.get_width() / 2.0 - inset) if left_texture else 0.0
	
	
	func right_offset() -> float:
		return (right_texture.get_width() / 2.0 - inset) if right_texture else 0.0


static func signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += (b.x - a.x) * (b.y + a.y)
	return area


static func ensure_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	return points if signed_area(points) < 0.0 else reverse_points(points)


static func ensure_counter_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	return points if signed_area(points) > 0.0 else reverse_points(points)


static func reverse_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in range(points.size() - 1, -1, -1):
		result.append(points[i])
	return result


static func edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var edge: Vector2 = (b - a).normalized()
	return Vector2(edge.y, -edge.x)


static func build_seam_polygon(outer: PackedVector2Array, hole: PackedVector2Array) -> PackedVector2Array:
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
	
	for i: int in outer_idx + 1:
		result.append(cw_outer[i])
	
	for i: int in ccw_hole.size():
		result.append(ccw_hole[(hole_idx + i) % ccw_hole.size()])
	result.append(ccw_hole[hole_idx])
	
	for i: int in range(outer_idx, cw_outer.size()):
		result.append(cw_outer[i])
	
	return result


static func build_ring(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> PackedVector2Array:
	var ring: PackedVector2Array = clean_polygon(outer)
	if ring.size() < 3:
		return PackedVector2Array()
	
	for hole: PackedVector2Array in holes:
		var cleaned: PackedVector2Array = clean_polygon(hole)
		if cleaned.size() < 3:
			continue
		var built: PackedVector2Array = build_seam_polygon(ring, cleaned)
		if built.size() >= 3:
			ring = built
	
	return ring


static func edge_midpoint_key(a: Vector2, b: Vector2) -> String:
	var mid: Vector2 = (a + b) * 0.5
	return "%d,%d" % [roundi(mid.x), roundi(mid.y)]


static func is_top_edge(a: Vector2, b: Vector2, threshold: float) -> bool:
	return edge_normal(a, b).y < -threshold


static func get_topline_segments(points: PackedVector2Array, threshold: float, forced: Dictionary = {}) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var key: String = edge_midpoint_key(a, b)
		var is_top: bool = bool(forced.get(key)) if forced.has(key) else is_top_edge(a, b, threshold)
		
		if is_top:
			if current.is_empty():
				current.append(a)
			current.append(b)
		elif not current.is_empty():
			segments.append(current)
			current = PackedVector2Array()
	
	if not current.is_empty():
		segments.append(current)
	
	if segments.size() > 1:
		var first: PackedVector2Array = segments[0]
		var last: PackedVector2Array = segments[segments.size() - 1]
		if last[last.size() - 1].distance_to(first[0]) < 0.5:
			var joined: PackedVector2Array = last.duplicate()
			for i: int in range(1, first.size()):
				joined.append(first[i])
			segments[0] = joined
			segments.remove_at(segments.size() - 1)
	
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


static func offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var count: int = points.size()
	if count < 2 or is_zero_approx(distance):
		return points
	
	var normals: PackedVector2Array = PackedVector2Array()
	for i: int in count - 1:
		normals.append(edge_normal(points[i], points[i + 1]))
	
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var before: Vector2 = normals[maxi(i - 1, 0)]
		var after: Vector2 = normals[mini(i, count - 2)]
		var dir: Vector2 = (before + after).normalized()
		result.append(points[i] + (dir if dir != Vector2.ZERO else after) * distance)
	return result


static func inset_polyline(points: PackedVector2Array, start: float, end: float) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var result: PackedVector2Array = points.duplicate()
	var last: int = result.size() - 1
	if start != 0.0:
		result[0] = result[0] + (result[1] - result[0]).normalized() * start
	if end != 0.0:
		result[last] = result[last] + (result[last - 1] - result[last]).normalized() * end
	return result


static func build_line2d(style: LineStyle, points: PackedVector2Array) -> Line2D:
	var line: Line2D = Line2D.new()
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	line.antialiased = style.texture == null
	line.width = style.width
	line.texture = style.texture
	line.default_color = style.color
	line.points = subdivide_for_line2d(points, style.texture)
	
	if style.is_animated():
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = LINE_SHADER
		mat.set_shader_parameter(&"scroll_speed", style.scroll_speed)
		mat.set_shader_parameter(&"ripple_amplitude", style.ripple_amplitude)
		mat.set_shader_parameter(&"ripple_frequency", style.ripple_frequency)
		mat.set_shader_parameter(&"ripple_speed", style.ripple_speed)
		line.material = mat
	
	return line


static func add_topline_segment(container: Node2D, segment: PackedVector2Array, style: LineStyle, caps: CapStyle) -> void:
	if segment.size() < 2 or style.width <= 0.0:
		return
	
	container.add_child(build_line2d(style, inset_polyline(segment, caps.left_offset(), caps.right_offset())))
	
	if caps.left_texture:
		var dir: Vector2 = (segment[0] - segment[1]).normalized()
		var cap: Sprite2D = Sprite2D.new()
		cap.texture = caps.left_texture
		cap.position = segment[0] + dir * caps.left_offset()
		cap.rotation = dir.angle() + PI
		container.add_child(cap)
	
	if caps.right_texture:
		var last: int = segment.size() - 1
		var dir: Vector2 = (segment[last] - segment[last - 1]).normalized()
		var cap: Sprite2D = Sprite2D.new()
		cap.texture = caps.right_texture
		cap.position = segment[last] + dir * caps.right_offset()
		cap.rotation = dir.angle()
		container.add_child(cap)


static func add_topline_shadow(container: Node2D, segment: PackedVector2Array, style: LineStyle, caps: CapStyle, gap: float) -> void:
	if segment.size() < 2 or not style.texture or style.width <= 0.0:
		return
	
	var run: PackedVector2Array = inset_polyline(segment, caps.left_offset(), caps.right_offset())
	container.add_child(build_line2d(style, offset_polyline(run, -(style.width * 0.5 + gap))))


static func add_outline(container: Node2D, points: PackedVector2Array, style: LineStyle) -> void:
	if points.size() < 2 or style.width <= 0.0:
		return
	container.add_child(build_line2d(style, points))
