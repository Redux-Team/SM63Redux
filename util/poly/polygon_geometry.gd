@abstract class_name TerrainPolygon


class LineStyle:
	var width: float
	var texture: Texture2D
	var color: Color
	var textured: bool
	var scroll_speed: float
	var ripple_amplitude: float
	var ripple_frequency: float
	var ripple_speed: float
	
	func _init(p_width: float, p_texture: Texture2D, p_color: Color, p_textured: bool,
			p_scroll: float = 0.0, p_ripple_amp: float = 0.0,
			p_ripple_freq: float = 1.0, p_ripple_speed: float = 1.0) -> void:
		width = p_width
		texture = p_texture
		color = p_color
		textured = p_textured
		scroll_speed = p_scroll
		ripple_amplitude = p_ripple_amp
		ripple_frequency = p_ripple_freq
		ripple_speed = p_ripple_speed


class CapStyle:
	var left_tex: Texture2D
	var right_tex: Texture2D
	var inset: float
	
	func _init(p_left: Texture2D, p_right: Texture2D, p_inset: float) -> void:
		left_tex = p_left
		right_tex = p_right
		inset = p_inset


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


static func edge_midpoint_key(a: Vector2, b: Vector2) -> String:
	var mid: Vector2 = (a + b) * 0.5
	return "%d,%d" % [roundi(mid.x), roundi(mid.y)]


static func is_top_edge(a: Vector2, b: Vector2, threshold: float, invert_normal: bool = false) -> bool:
	var edge: Vector2 = (b - a).normalized()
	if invert_normal:
		edge = -edge
	var normal: Vector2 = Vector2(edge.y, -edge.x)
	return normal.y < -threshold


static func get_topline_segments(points: PackedVector2Array, threshold: float, seam_indices: PackedInt32Array = PackedInt32Array(), invert_normal: bool = false, forced: Dictionary = {}) -> Array[PackedVector2Array]:
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
		var is_top: bool = is_top_edge(a, b, threshold, invert_normal)
		var key: String = edge_midpoint_key(a, b)
		if forced.has(key):
			is_top = bool(forced[key])

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
	
	if segments.size() > 1 and seam_indices.is_empty():
		var first: PackedVector2Array = segments[0]
		var last: PackedVector2Array = segments[segments.size() - 1]
		if last[last.size() - 1].distance_to(first[0]) < 0.5:
			var joined: PackedVector2Array = last.duplicate()
			for i: int in range(1, first.size()):
				joined.append(first[i])
			segments[0] = joined
			segments.remove_at(segments.size() - 1)
	
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


static func get_segment_angle(segment: PackedVector2Array) -> float:
	if segment.size() < 2:
		return 0.0
	return (segment[segment.size() - 1] - segment[0]).angle()


static func setup_line2d(line: Line2D, rounded: bool = true) -> void:
	if rounded:
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


static func _needs_line_material(style: LineStyle) -> bool:
	return style.scroll_speed != 0.0 or style.ripple_amplitude != 0.0


static func _apply_line_material(line: Line2D, style: LineStyle) -> void:
	if not _needs_line_material(style):
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("uid://bmil47d5swbbn")
	mat.set_shader_parameter(&"scroll_speed", style.scroll_speed)
	mat.set_shader_parameter(&"ripple_amplitude", style.ripple_amplitude)
	mat.set_shader_parameter(&"ripple_frequency", style.ripple_frequency)
	mat.set_shader_parameter(&"ripple_speed", style.ripple_speed)
	line.material = mat


static func _inset_segment(segment: PackedVector2Array, left_inset: float, right_inset: float) -> PackedVector2Array:
	if segment.size() < 2:
		return segment
	var result: PackedVector2Array = segment.duplicate()
	if left_inset != 0.0:
		var dir: Vector2 = (result[1] - result[0]).normalized()
		result[0] = result[0] + dir * left_inset
	var last: int = result.size() - 1
	if right_inset != 0.0:
		var dir: Vector2 = (result[last - 1] - result[last]).normalized()
		result[last] = result[last] + dir * right_inset
	return result


static func add_topline_segment(container: Node2D, segment: PackedVector2Array, style: LineStyle, caps: CapStyle) -> void:
	if segment.size() < 2:
		return
	
	var left_inset: float = (caps.left_tex.get_width() / 2.0 - caps.inset) if caps.left_tex else 0.0
	var right_inset: float = (caps.right_tex.get_width() / 2.0 - caps.inset) if caps.right_tex else 0.0
	var line_segment: PackedVector2Array = _inset_segment(segment, left_inset, right_inset)
	
	var line: Line2D = Line2D.new()
	setup_line2d(line)
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.width = style.width
	line.texture = style.texture
	line.default_color = Color.WHITE if style.texture else style.color
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not style.textured else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	line.antialiased = not style.textured
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.points = subdivide_for_line2d(line_segment, style.texture)
	_apply_line_material(line, style)
	container.add_child(line)
	
	if not style.textured:
		return
	
	if caps.left_tex:
		var left_dir: Vector2 = (segment[0] - segment[1]).normalized()
		var cap: Sprite2D = Sprite2D.new()
		cap.texture = caps.left_tex
		cap.position = segment[0] + left_dir * (caps.left_tex.get_width() / 2.0 - caps.inset)
		cap.rotation = left_dir.angle() + PI
		cap.centered = true
		container.add_child(cap)
	
	if caps.right_tex:
		var last: int = segment.size() - 1
		var right_dir: Vector2 = (segment[last] - segment[last - 1]).normalized()
		var cap: Sprite2D = Sprite2D.new()
		cap.texture = caps.right_tex
		cap.position = segment[last] + right_dir * (caps.right_tex.get_width() / 2.0 - caps.inset)
		cap.rotation = right_dir.angle()
		cap.centered = true
		container.add_child(cap)


static func add_topline_shadow(container: Node2D, segment: PackedVector2Array, texture: Texture2D, width: float) -> void:
	var line: Line2D = Line2D.new()
	setup_line2d(line)
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.width = width
	line.texture = texture
	line.default_color = Color(1.0, 1.0, 1.0, 0.6)
	line.points = subdivide_for_line2d(segment, texture)
	container.add_child(line)


static func add_outline(container: Node2D, points: PackedVector2Array, style: LineStyle) -> void:
	var line: Line2D = Line2D.new()
	setup_line2d(line, false)
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.width = style.width
	line.texture = style.texture
	line.default_color = Color.WHITE if style.texture else style.color
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not style.textured else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	line.antialiased = not style.textured
	line.points = subdivide_for_line2d(points, style.texture)
	_apply_line_material(line, style)
	container.add_child(line)
