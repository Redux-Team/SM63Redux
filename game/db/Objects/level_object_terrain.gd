@tool
class_name LevelObjectTerrain
extends LevelObject


const DECORATION_EDGE_BUFFER: float = 32.0


@export var polygon_data: PolygonData:
	set(v):
		polygon_data = v
		_update_visuals()

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _collision: CollisionPolygon2D
@export var _outline_container: Node2D
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D
@export var _decoration_container: Node2D
@export var _static_body_2d: StaticBody2D


var _outer_points: PackedVector2Array = PackedVector2Array()
var _holes: Array[PackedVector2Array] = []
var rng_seed: int = 0


func _on_init() -> void:
	var raw_points: Variant = data.get("polygon_points")
	_outer_points = Packer.array_to_packed_vec2(raw_points)

	if data.has("polygon_data_path"):
		polygon_data = load(data.get("polygon_data_path"))

	if data.has("polygon_holes"):
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(Packer.array_to_vec2(p))
			if hole_points.size() >= 3:
				_holes.append(hole_points)

	if not Engine.is_editor_hint():
		_static_body_2d.set_meta("terrain", polygon_data.terrain_type)

	_rebuild_polygon()


func _rebuild_polygon() -> void:
	if _outer_points.is_empty():
		if _polygon:
			_polygon.polygon = PackedVector2Array()
		if _collision:
			_collision.polygon = PackedVector2Array()
		_rebuild_decorations()
		_update_visuals()
		return

	var seam_polygon: PackedVector2Array = TerrainPolygon.clean_polygon(_outer_points)

	for hole: PackedVector2Array in _holes:
		if hole.size() < 3:
			continue
		var cleaned_hole: PackedVector2Array = TerrainPolygon.clean_polygon(hole)
		if cleaned_hole.size() < 3:
			continue
		var seam_result: Dictionary = TerrainPolygon.build_seam_polygon(seam_polygon, cleaned_hole)
		var built: PackedVector2Array = seam_result["polygon"]
		if built.size() < 3:
			continue
		seam_polygon = built

	if _polygon:
		_polygon.polygon = seam_polygon
	if _collision:
		_collision.polygon = seam_polygon

	_rebuild_decorations()
	_update_visuals()


func _rebuild_decorations() -> void:
	if _decoration_container:
		for child: Node in _decoration_container.get_children():
			child.queue_free()
	if not polygon_data or polygon_data.decoration_weightmap.is_empty() or _outer_points.size() < 3:
		return
	if not _decoration_container:
		return

	var eroded_outer: Array = Geometry2D.offset_polygon(_outer_points, -DECORATION_EDGE_BUFFER)
	if eroded_outer.is_empty():
		return
	var inner_polygon: PackedVector2Array = eroded_outer[0]
	if inner_polygon.size() < 3:
		return

	var eroded_holes: Array[PackedVector2Array] = []
	for hole: PackedVector2Array in _holes:
		var eroded_hole: Array = Geometry2D.offset_polygon(hole, DECORATION_EDGE_BUFFER)
		if not eroded_hole.is_empty() and (eroded_hole[0] as PackedVector2Array).size() >= 3:
			eroded_holes.append(eroded_hole[0])

	var bounds: Rect2 = Rect2(_outer_points[0], Vector2.ZERO)
	for point: Vector2 in _outer_points:
		bounds = bounds.expand(point)

	var area: float = bounds.size.x * bounds.size.y
	var candidate_count: int = int(area / 10000.0 * polygon_data.decoration_density)
	if candidate_count <= 0:
		return

	var cell_size: float = sqrt(area / float(candidate_count))
	var cols: int = maxi(1, int(ceil(bounds.size.x / cell_size)))
	var rows: int = maxi(1, int(ceil(bounds.size.y / cell_size)))
	var placed_rects: Array[Rect2] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	for row: int in rows:
		for col: int in cols:
			# 2654435761 and 2246822519 are prime numbers that we are using for hashing
			# in case this seems random. https://en.wikipedia.org/wiki/Hash_function
			rng.seed = rng_seed ^ (row * 2654435761) ^ (col * 2246822519)
			var cell_origin: Vector2 = bounds.position + Vector2(col * cell_size, row * cell_size)
			var point: Vector2 = cell_origin + Vector2(rng.randf() * cell_size, rng.randf() * cell_size)
			if not Geometry2D.is_point_in_polygon(point, inner_polygon):
				continue
			var in_hole: bool = false
			for eroded_hole: PackedVector2Array in eroded_holes:
				if Geometry2D.is_point_in_polygon(point, eroded_hole):
					in_hole = true
					break
			if in_hole:
				continue
			var tex_index: int = 0
			for tex: Texture2D in polygon_data.decoration_weightmap:
				if not tex:
					tex_index += 1
					continue
				rng.seed = rng_seed ^ (row * 2654435761) ^ (col * 2246822519) ^ (tex_index * 374761393)
				var chance: float = polygon_data.decoration_weightmap[tex]
				if rng.randf() * 100.0 > chance:
					tex_index += 1
					continue
				var tex_size: Vector2 = Vector2(tex.get_size())
				var candidate_rect: Rect2 = Rect2(point - tex_size * 0.5, tex_size)
				var overlaps: bool = false
				for placed: Rect2 in placed_rects:
					if candidate_rect.intersects(placed):
						overlaps = true
						break
				if overlaps:
					tex_index += 1
					continue
				placed_rects.append(candidate_rect)
				var sprite: Sprite2D = Sprite2D.new()
				sprite.texture = tex
				sprite.position = point
				sprite.centered = true
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_decoration_container.add_child(sprite)
				tex_index += 1


func _update_visuals() -> void:
	if not is_node_ready() or not polygon_data:
		return

	var textured: bool = polygon_data.textured
	var line_mode: PolygonData.LineMode = polygon_data.line_mode

	if _polygon:
		if textured and polygon_data.base_texture:
			_polygon.texture = polygon_data.base_texture
			_polygon.color = Color.WHITE
		else:
			_polygon.texture = null
			_polygon.color = polygon_data.base_color

	if _outer_points.size() < 3:
		_clear_visuals()
		return

	_clear_visuals()

	if line_mode == PolygonData.LineMode.NONE:
		return

	var outline_color: Color = polygon_data.outline_color
	var outline_tex: Texture2D = polygon_data.outline_texture if textured else null
	var outline_w: float = polygon_data.outline_width

	if line_mode == PolygonData.LineMode.TOPLINE:
		var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
		var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, polygon_data.topline_angle_threshold)

		for hole: PackedVector2Array in _holes:
			var hole_ccw: PackedVector2Array = TerrainPolygon.ensure_counter_clockwise(hole)
			top_segments.append_array(TerrainPolygon.get_topline_segments(hole_ccw, polygon_data.topline_angle_threshold))

		var topline_tex: Texture2D = polygon_data.topline_texture if textured else null
		var topline_shadow_tex: Texture2D = polygon_data.topline_shadow_texture if textured else null
		var topline_w: float = polygon_data.topline_width

		if _topline_container:
			for segment: PackedVector2Array in top_segments:
				var line: Line2D = Line2D.new()
				TerrainPolygon.setup_line2d(line)
				line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not textured else CanvasItem.TEXTURE_FILTER_PARENT_NODE
				line.antialiased = not textured
				line.begin_cap_mode = Line2D.LINE_CAP_NONE
				line.end_cap_mode = Line2D.LINE_CAP_NONE
				line.width = topline_w
				line.texture = topline_tex
				line.default_color = Color.WHITE if topline_tex else outline_color
				line.points = TerrainPolygon.subdivide_for_line2d(segment, topline_tex)
				_topline_container.add_child(line)

				var angle: float = TerrainPolygon.get_segment_angle(segment)

				if textured and polygon_data.topline_left_end and segment.size() >= 2:
					var left_cap: Sprite2D = Sprite2D.new()
					left_cap.texture = polygon_data.topline_left_end
					var left_dir: Vector2 = (segment[0] - segment[1]).normalized()
					left_cap.position = segment[0] + left_dir * (polygon_data.topline_left_end.get_width() / 2.0)
					left_cap.rotation = angle
					left_cap.centered = true
					_topline_container.add_child(left_cap)

				if textured and polygon_data.topline_right_end and segment.size() >= 2:
					var right_cap: Sprite2D = Sprite2D.new()
					right_cap.texture = polygon_data.topline_right_end
					var right_dir: Vector2 = (segment[segment.size() - 1] - segment[segment.size() - 2]).normalized()
					right_cap.position = segment[segment.size() - 1] + right_dir * (polygon_data.topline_right_end.get_width() / 2.0)
					right_cap.rotation = angle
					right_cap.centered = true
					_topline_container.add_child(right_cap)

		if _topline_shadow_container and textured:
			for segment: PackedVector2Array in top_segments:
				var line: Line2D = Line2D.new()
				TerrainPolygon.setup_line2d(line)
				line.begin_cap_mode = Line2D.LINE_CAP_NONE
				line.end_cap_mode = Line2D.LINE_CAP_NONE
				line.width = topline_w * 1.33
				line.texture = topline_shadow_tex
				line.default_color = Color(1.0, 1.0, 1.0, 0.6)
				line.points = TerrainPolygon.subdivide_for_line2d(segment, topline_shadow_tex)
				_topline_shadow_container.add_child(line)

	if _outline_container:
		var outer_line: Line2D = Line2D.new()
		TerrainPolygon.setup_line2d(outer_line)
		outer_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not textured else CanvasItem.TEXTURE_FILTER_PARENT_NODE
		outer_line.antialiased = not textured
		outer_line.width = outline_w
		outer_line.texture = outline_tex
		outer_line.default_color = Color.WHITE if outline_tex else outline_color
		outer_line.points = TerrainPolygon.subdivide_for_line2d(
			TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(_outer_points))),
			outline_tex)
		_outline_container.add_child(outer_line)

		for hole: PackedVector2Array in _holes:
			var hole_line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(hole_line)
			hole_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not textured else CanvasItem.TEXTURE_FILTER_PARENT_NODE
			hole_line.antialiased = not textured
			hole_line.width = outline_w
			hole_line.texture = outline_tex
			hole_line.default_color = Color.WHITE if outline_tex else outline_color
			hole_line.points = TerrainPolygon.subdivide_for_line2d(
				TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(hole))),
				outline_tex)
			_outline_container.add_child(hole_line)


func _clear_visuals() -> void:
	if _topline_container:
		_clear_children(_topline_container)
	if _topline_shadow_container:
		_clear_children(_topline_shadow_container)
	if _outline_container:
		_clear_children(_outline_container)


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
