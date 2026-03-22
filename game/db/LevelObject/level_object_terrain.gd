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
	if data.has("terrain_data_path"):
		terrain_data = load(data.get("terrain_data_path"))
	
	var raw_points: Variant = data.get("polygon_points")
	var ctrl_outer: PackedVector2Array = _array_to_packed_vec2(raw_points)
	var ctrl_holes: Array[PackedVector2Array] = []
	
	if data.has("polygon_holes"):
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(_array_to_vec2(p))
			if hole_points.size() >= 3:
				ctrl_holes.append(hole_points)
	
	if data.has("curve_handles"):
		var curve_data: Dictionary = data["curve_handles"] as Dictionary
		_outer_points = _flatten_ring(ctrl_outer, curve_data, -1)
		_holes.clear()
		for hi: int in ctrl_holes.size():
			_holes.append(_flatten_ring(ctrl_holes[hi], curve_data, hi))
	else:
		_outer_points = ctrl_outer
		_holes = ctrl_holes
	
	_rebuild_polygon()


func _flatten_ring(ring: PackedVector2Array, curve_data: Dictionary, hole_idx: int) -> PackedVector2Array:
	var ring_handles: Dictionary = {}
	var prefix: String = "hk_o:" if hole_idx < 0 else "hk_h:" + str(hole_idx) + ":"
	for key: String in curve_data.keys():
		if not key.begins_with(prefix):
			continue
		var idx: int = int(key.substr(prefix.length()))
		var arr: Array = curve_data[key] as Array
		if arr.size() == 4:
			ring_handles[idx] = LDCurveHandle.new(
				Vector2(float(arr[0]), float(arr[1])),
				Vector2(float(arr[2]), float(arr[3]))
			)
	if ring_handles.is_empty():
		return ring
	return LDCurveUtil.flatten_ring(ring, ring_handles, 12)


func _rebuild_polygon() -> void:
	if _outer_points.is_empty():
		if _polygon:
			_polygon.polygon = PackedVector2Array()
		if _collision:
			_collision.polygon = PackedVector2Array()
		_update_visuals()
		return
	
	var seam_polygon: PackedVector2Array = _outer_points.duplicate()
	for hole: PackedVector2Array in _holes:
		if hole.size() < 3:
			continue
		var seam_result: Dictionary = TerrainPolygon.build_seam_polygon(seam_polygon, hole)
		var built: PackedVector2Array = seam_result["polygon"]
		if built.size() >= 3:
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
	
	var threshold: float = terrain_data.topline_angle_threshold
	var topline_tex: Texture2D = terrain_data.topline_texture
	var topline_shadow_tex: Texture2D = terrain_data.topline_shadow_texture
	var outline_tex: Texture2D = terrain_data.outline_texture
	
	var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
	var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, threshold)
	
	for hole: PackedVector2Array in _holes:
		var hole_ccw: PackedVector2Array = TerrainPolygon.ensure_counter_clockwise(hole)
		top_segments.append_array(TerrainPolygon.get_topline_segments(hole_ccw, threshold))
	
	if _topline_container:
		_clear_children(_topline_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width
			line.texture = topline_tex
			line.points = TerrainPolygon.subdivide_for_line2d(segment, topline_tex)
			_topline_container.add_child(line)
	
	if _topline_shadow_container:
		_clear_children(_topline_shadow_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width * 1.33
			line.texture = topline_shadow_tex
			line.default_color = Color(1.0, 1.0, 1.0, 0.6)
			line.points = TerrainPolygon.subdivide_for_line2d(segment, topline_shadow_tex)
			_topline_shadow_container.add_child(line)
	
	if _outline_container:
		_clear_children(_outline_container)
		var outer_line: Line2D = Line2D.new()
		TerrainPolygon.setup_line2d(outer_line)
		outer_line.width = terrain_data.outline_width
		outer_line.texture = outline_tex
		outer_line.points = TerrainPolygon.subdivide_for_line2d(
			TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(
				TerrainPolygon.ensure_counter_clockwise(_outer_points))), outline_tex)
		_outline_container.add_child(outer_line)
		for hole: PackedVector2Array in _holes:
			var hole_line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(hole_line)
			hole_line.width = terrain_data.outline_width
			hole_line.texture = outline_tex
			hole_line.points = TerrainPolygon.subdivide_for_line2d(
				TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(
					TerrainPolygon.ensure_clockwise(hole))), outline_tex)
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
