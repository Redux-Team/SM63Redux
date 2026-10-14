@abstract class_name TerrainPolygon

const LINE_SHADER: Shader = preload("res://shader/terrain_line_scroll.gdshader")


class LineStyle:
	var width: float
	var texture: Texture2D
	var color: Color
	var scroll_speed: float
	var ripple_amplitude: float
	var ripple_frequency: float
	var ripple_speed: float
	
	
	func _init(line_width: float, line_texture: Texture2D, line_color: Color, scroll: float = 0.0, amplitude: float = 0.0, frequency: float = 1.0, speed: float = 1.0) -> void:
		width = line_width
		texture = line_texture
		color = line_color
		scroll_speed = scroll
		ripple_amplitude = amplitude
		ripple_frequency = frequency
		ripple_speed = speed
	
	
	func is_animated() -> bool:
		return scroll_speed != 0.0 or ripple_amplitude != 0.0


class CapStyle:
	var left_texture: Texture2D
	var right_texture: Texture2D
	var inset: float
	
	
	func _init(left: Texture2D, right: Texture2D, cap_inset: float) -> void:
		left_texture = left
		right_texture = right
		inset = cap_inset
	
	
	func left_offset() -> float:
		return left_texture.get_width() / 2.0 - inset if left_texture else 0.0
	
	
	func right_offset() -> float:
		return right_texture.get_width() / 2.0 - inset if right_texture else 0.0


static func signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points.get(i)
		var b: Vector2 = points.get((i + 1) % count)
		area += (b.x - a.x) * (b.y + a.y)
	
	return area


static func is_clockwise(points: PackedVector2Array) -> bool:
	return signed_area(points) < 0.0


static func ensure_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	return points if is_clockwise(points) else reverse_points(points)


static func ensure_counter_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	return reverse_points(points) if is_clockwise(points) else points


static func reverse_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	result.reverse()
	return result


static func edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var edge: Vector2 = (b - a).normalized()
	return Vector2(edge.y, -edge.x)


static func get_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	
	var bounds: Rect2 = Rect2(points.get(0), Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	
	return bounds


static func split_into_pieces(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var cleaned: PackedVector2Array = clean_polygon(outer)
	if cleaned.size() < 3:
		return []
	
	var pieces: Array[PackedVector2Array] = [cleaned]
	for hole: PackedVector2Array in holes:
		var cleaned_hole: PackedVector2Array = clean_polygon(hole)
		if cleaned_hole.size() < 3:
			continue
		
		var hole_bounds: Rect2 = get_bounds(cleaned_hole)
		var cut: float = hole_bounds.get_center().x
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			var bounds: Rect2 = get_bounds(piece).grow(1.0)
			if not bounds.intersects(hole_bounds):
				next.append(piece)
				continue
			
			for half: PackedVector2Array in [
				PackedVector2Array([bounds.position, Vector2(cut, bounds.position.y), Vector2(cut, bounds.end.y), Vector2(bounds.position.x, bounds.end.y)]),
				PackedVector2Array([Vector2(cut, bounds.position.y), Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(cut, bounds.end.y)]),
			]:
				for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, half):
					next.append_array(Geometry2D.clip_polygons(part, cleaned_hole).filter(func(remaining: PackedVector2Array) -> bool: return remaining.size() >= 3))
		pieces = next
	
	return pieces


static func is_top_edge(a: Vector2, b: Vector2, threshold: float, flipped: bool) -> bool:
	return edge_normal(a, b).y * (-1.0 if flipped else 1.0) < -threshold


static func get_topline_flags(points: PackedVector2Array, solid_clockwise: bool, threshold: float, overrides: Dictionary, automatic: bool = true) -> Array[bool]:
	var flags: Array[bool] = []
	var count: int = points.size()
	var flipped: bool = is_clockwise(points) != solid_clockwise
	for i: int in count:
		flags.append(overrides.get(i, automatic and is_top_edge(points.get(i), points.get((i + 1) % count), threshold, flipped)))
	
	return flags


static func get_topline_segments(points: PackedVector2Array, flags: Array[bool], solid_clockwise: bool) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var ordered: PackedVector2Array = points
	var ordered_flags: Array[bool] = flags
	if is_clockwise(points) != solid_clockwise:
		ordered = reverse_points(points)
		ordered_flags = []
		for k: int in count:
			ordered_flags.append(flags.get(posmod(count - 2 - k, count)))
	
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		if ordered_flags.get(i):
			if current.is_empty():
				current.append(ordered.get(i))
			current.append(ordered.get((i + 1) % count))
		elif not current.is_empty():
			segments.append(current)
			current = PackedVector2Array()
	
	if not current.is_empty():
		segments.append(current)
	
	if segments.size() > 1:
		var first: PackedVector2Array = segments.front()
		var last: PackedVector2Array = segments.back()
		if last.get(last.size() - 1).distance_to(first.get(0)) < 0.5:
			last.append_array(first.slice(1))
			segments.set(0, last)
			segments.pop_back()
	
	return segments


static func subdivide_for_line2d(points: PackedVector2Array, texture: Texture2D) -> PackedVector2Array:
	if texture == null or points.size() < 2:
		return points
	
	var texture_width: float = float(texture.get_width())
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in points.size() - 1:
		var a: Vector2 = points.get(i)
		var b: Vector2 = points.get(i + 1)
		var steps: int = maxi(1, ceili(a.distance_to(b) / texture_width))
		result.append(a)
		for s: int in range(1, steps):
			result.append(a.lerp(b, float(s) / float(steps)))
	
	result.append(points.get(points.size() - 1))
	return result


static func clean_polygon(points: PackedVector2Array, epsilon: float = 0.5) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	for i: int in count:
		if points.get(i).distance_to(points.get((i - 1 + count) % count)) >= epsilon:
			result.append(points.get(i))
	
	return result


static func get_closed_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points.get(0))
	return closed


static func offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var count: int = points.size()
	if count < 2 or is_zero_approx(distance):
		return points
	
	var normals: PackedVector2Array = PackedVector2Array()
	for i: int in count - 1:
		normals.append(edge_normal(points.get(i), points.get(i + 1)))
	
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var after: Vector2 = normals.get(mini(i, count - 2))
		var direction: Vector2 = (normals.get(maxi(i - 1, 0)) + after).normalized()
		result.append(points.get(i) + (direction if direction != Vector2.ZERO else after) * distance)
	
	return result


static func inset_polyline(points: PackedVector2Array, start: float, end: float) -> PackedVector2Array:
	if points.size() < 2:
		return points
	
	var result: PackedVector2Array = points.duplicate()
	var last: int = result.size() - 1
	result.set(0, result.get(0) + (result.get(1) - result.get(0)).normalized() * start)
	result.set(last, result.get(last) + (result.get(last - 1) - result.get(last)).normalized() * end)
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
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = LINE_SHADER
		material.set_shader_parameter(&"scroll_speed", style.scroll_speed)
		material.set_shader_parameter(&"ripple_amplitude", style.ripple_amplitude)
		material.set_shader_parameter(&"ripple_frequency", style.ripple_frequency)
		material.set_shader_parameter(&"ripple_speed", style.ripple_speed)
		line.material = material
	
	return line


static func add_topline_segment(container: Node2D, segment: PackedVector2Array, style: LineStyle, caps: CapStyle) -> void:
	if segment.size() < 2 or style.width <= 0.0:
		return
	
	container.add_child(build_line2d(style, inset_polyline(segment, caps.left_offset(), caps.right_offset())))
	if caps.left_texture:
		var direction: Vector2 = (segment.get(0) - segment.get(1)).normalized()
		container.add_child(_build_cap(caps.left_texture, segment.get(0) + direction * caps.left_offset(), direction.angle() + PI))
	
	if caps.right_texture:
		var last: int = segment.size() - 1
		var direction: Vector2 = (segment.get(last) - segment.get(last - 1)).normalized()
		container.add_child(_build_cap(caps.right_texture, segment.get(last) + direction * caps.right_offset(), direction.angle()))


static func add_topline_shadow(container: Node2D, segment: PackedVector2Array, style: LineStyle, caps: CapStyle, gap: float) -> void:
	if segment.size() < 2 or style.texture == null or style.width <= 0.0:
		return
	
	var run: PackedVector2Array = inset_polyline(segment, caps.left_offset(), caps.right_offset())
	container.add_child(build_line2d(style, offset_polyline(run, -(style.width * 0.5 + gap))))


static func add_outline(container: Node2D, points: PackedVector2Array, style: LineStyle) -> void:
	if points.size() >= 2 and style.width > 0.0:
		container.add_child(build_line2d(style, points))


static func _build_cap(texture: Texture2D, cap_position: Vector2, cap_rotation: float) -> Sprite2D:
	var cap: Sprite2D = Sprite2D.new()
	cap.texture = texture
	cap.position = cap_position
	cap.rotation = cap_rotation
	return cap
