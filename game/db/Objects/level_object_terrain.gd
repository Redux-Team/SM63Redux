@tool
class_name LevelObjectTerrain
extends LevelObject


@export var terrain_data: TerrainData:
	set(v):
		terrain_data = v
		_update_visuals()

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _collision: CollisionPolygon2D
@export var _outline_container: Node2D
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D


var _outer_points: PackedVector2Array = PackedVector2Array()
var _holes: Array[PackedVector2Array] = []


func _on_init() -> void:
	var raw_points: Variant = data.get("polygon_points")
	_outer_points = _array_to_packed_vec2(raw_points)
	
	if data.has("terrain_data_path"):
		terrain_data = load(data.get("terrain_data_path"))
	
	if data.has("polygon_holes"):
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(_array_to_vec2(p))
			if hole_points.size() >= 3:
				_holes.append(hole_points)
	
	_rebuild_polygon()


func _rebuild_polygon() -> void:
	if _outer_points.is_empty():
		if _polygon:
			_polygon.polygon = PackedVector2Array()
		if _collision:
			_collision.polygon = PackedVector2Array()
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
	
	_update_visuals()


func _update_visuals() -> void:
	if not is_node_ready() or not terrain_data:
		return
	
	if _polygon:
		_polygon.texture = terrain_data.base_texture
		_polygon.color = Color.WHITE if terrain_data.base_texture else Color.TRANSPARENT
	
	if _outer_points.size() < 3:
		_clear_visuals()
		return
	
	var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
	var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, terrain_data.topline_angle_threshold)
	
	for hole: PackedVector2Array in _holes:
		var hole_ccw: PackedVector2Array = TerrainPolygon.ensure_counter_clockwise(hole)
		var hole_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(hole_ccw, terrain_data.topline_angle_threshold)
		top_segments.append_array(hole_segments)
	
	if _topline_container:
		_clear_children(_topline_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.begin_cap_mode = Line2D.LINE_CAP_NONE
			line.end_cap_mode = Line2D.LINE_CAP_NONE
			line.width = terrain_data.topline_width
			line.texture = terrain_data.topline_texture
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_texture)
			_topline_container.add_child(line)
			
			var angle: float = TerrainPolygon.get_segment_angle(segment)
			
			if terrain_data.topline_left_end and segment.size() >= 2:
				var left_cap: Sprite2D = Sprite2D.new()
				left_cap.texture = terrain_data.topline_left_end
				var left_dir: Vector2 = (segment[0] - segment[1]).normalized()
				left_cap.position = segment[0] + left_dir * (terrain_data.topline_left_end.get_width() / 2.0)
				left_cap.rotation = angle
				left_cap.centered = true
				_topline_container.add_child(left_cap)
			
			if terrain_data.topline_right_end and segment.size() >= 2:
				var right_cap: Sprite2D = Sprite2D.new()
				right_cap.texture = terrain_data.topline_right_end
				var right_dir: Vector2 = (segment[segment.size() - 1] - segment[segment.size() - 2]).normalized()
				right_cap.position = segment[segment.size() - 1] + right_dir * (terrain_data.topline_right_end.get_width() / 2.0)
				right_cap.rotation = angle
				right_cap.centered = true
				_topline_container.add_child(right_cap)
	
	if _topline_shadow_container:
		_clear_children(_topline_shadow_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.begin_cap_mode = Line2D.LINE_CAP_NONE
			line.end_cap_mode = Line2D.LINE_CAP_NONE
			line.width = terrain_data.topline_width * 1.33
			line.texture = terrain_data.topline_shadow_texture
			line.default_color = Color(1.0, 1.0, 1.0, 0.6)
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_shadow_texture)
			_topline_shadow_container.add_child(line)
	
	if _outline_container:
		_clear_children(_outline_container)
		
		var outer_line: Line2D = Line2D.new()
		TerrainPolygon.setup_line2d(outer_line)
		outer_line.width = terrain_data.outline_width
		outer_line.texture = terrain_data.outline_texture
		outer_line.default_color = Color.WHITE if terrain_data.outline_texture else Color.TRANSPARENT
		outer_line.points = TerrainPolygon.subdivide_for_line2d(
			TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(_outer_points))),
			terrain_data.outline_texture)
		_outline_container.add_child(outer_line)
		
		for hole: PackedVector2Array in _holes:
			var hole_line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(hole_line)
			hole_line.width = terrain_data.outline_width
			hole_line.texture = terrain_data.outline_texture
			hole_line.default_color = Color.WHITE if terrain_data.outline_texture else Color.TRANSPARENT
			hole_line.points = TerrainPolygon.subdivide_for_line2d(
				TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(hole))),
				terrain_data.outline_texture)
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
