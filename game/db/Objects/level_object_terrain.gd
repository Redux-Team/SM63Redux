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
	
	_clear_visuals()
	
	if _outer_points.size() < 3 or line_mode == PolygonData.LineMode.NONE:
		return
	
	var outline_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
		polygon_data.outline_width,
		polygon_data.outline_texture if textured else null,
		polygon_data.outline_color,
		textured
	)
	
	if line_mode == PolygonData.LineMode.TOPLINE:
		var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
		var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, polygon_data.topline_angle_threshold)
		
		for hole: PackedVector2Array in _holes:
			top_segments.append_array(TerrainPolygon.get_topline_segments(
				TerrainPolygon.ensure_counter_clockwise(hole), polygon_data.topline_angle_threshold
			))
		
		var line_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
			polygon_data.topline_width,
			polygon_data.topline_texture if textured else null,
			polygon_data.outline_color,
			textured
		)
		var cap_style: TerrainPolygon.CapStyle = TerrainPolygon.CapStyle.new(
			polygon_data.topline_left_end if textured else null,
			polygon_data.topline_right_end if textured else null,
			polygon_data.topline_cap_inset
		)
		
		if _topline_container:
			for segment: PackedVector2Array in top_segments:
				TerrainPolygon.add_topline_segment(_topline_container, segment, line_style, cap_style)
		
		if _topline_shadow_container and textured and polygon_data.topline_shadow_texture:
			for segment: PackedVector2Array in top_segments:
				TerrainPolygon.add_topline_shadow(
					_topline_shadow_container, segment,
					polygon_data.topline_shadow_texture,
					polygon_data.topline_width * 1.33
				)
	
	if _outline_container:
		var outer_pts: PackedVector2Array = TerrainPolygon.reverse_points(
			TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(_outer_points))
		)
		TerrainPolygon.add_outline(_outline_container, outer_pts, outline_style)
		
		for hole: PackedVector2Array in _holes:
			TerrainPolygon.add_outline(_outline_container,
				TerrainPolygon.reverse_points(
					TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(hole))
				),
				outline_style
			)


func _clear_visuals() -> void:
	for container: Node2D in [_topline_container, _topline_shadow_container, _outline_container]:
		if container:
			for child: Node in container.get_children():
				child.queue_free()
