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

var _outer: LDPolygon = LDPolygon.new()
var _holes: Array[LDPolygon] = []


func _on_init() -> void:
	if data.has("terrain_data_path"):
		terrain_data = load(data.get("terrain_data_path"))

	if data.has("polygon_points"):
		_outer = _deserialize_ring(data["polygon_points"])
	else:
		_outer = LDPolygon.new()

	_holes.clear()
	if data.has("polygon_holes"):
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var h: LDPolygon = _deserialize_ring(hole_data)
			if h.segments.size() >= 3:
				_holes.append(h)

	_rebuild_polygon()


func _deserialize_ring(ring_data: Array) -> LDPolygon:
	var poly: LDPolygon = LDPolygon.new()
	for entry: Variant in ring_data:
		if entry is Dictionary:
			var p: Vector2 = _array_to_vec2(entry.get("p", [0.0, 0.0]))
			var is_curve: bool = entry.has("ho") and entry.has("hi")
			var h_out: Vector2 = _array_to_vec2(entry.get("ho", [0.0, 0.0])) if is_curve else Vector2.ZERO
			var h_in: Vector2 = _array_to_vec2(entry.get("hi", [0.0, 0.0])) if is_curve else Vector2.ZERO
			poly.segments.append(LDSegment.new(p, is_curve, h_out, h_in))
		elif entry is Array:
			poly.segments.append(LDSegment.new(_array_to_vec2(entry)))
	return poly


func _rebuild_polygon() -> void:
	var outer_flat: PackedVector2Array = _outer.to_flat()
	if outer_flat.is_empty():
		if _polygon:
			_polygon.polygon = PackedVector2Array()
		if _collision:
			_collision.polygon = PackedVector2Array()
		_update_visuals()
		return

	var seam_polygon: PackedVector2Array = outer_flat
	for hole: LDPolygon in _holes:
		var hf: PackedVector2Array = hole.to_flat()
		if hf.size() < 3:
			continue
		var seam_result: Dictionary = TerrainPolygon.build_seam_polygon(seam_polygon, hf)
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

	var outer_flat: PackedVector2Array = _outer.to_flat()
	if outer_flat.size() < 3:
		_clear_visuals()
		return

	var threshold: float = terrain_data.topline_angle_threshold
	var topline_tex: Texture2D = terrain_data.topline_texture
	var topline_shadow_tex: Texture2D = terrain_data.topline_shadow_texture
	var outline_tex: Texture2D = terrain_data.outline_texture

	var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(outer_flat)
	var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, threshold)

	for hole: LDPolygon in _holes:
		var hole_ccw: PackedVector2Array = TerrainPolygon.ensure_counter_clockwise(hole.to_flat())
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
		outer_line.default_color = Color.WHITE if outline_tex else Color.TRANSPARENT
		outer_line.points = TerrainPolygon.subdivide_for_line2d(
			TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(
				TerrainPolygon.ensure_counter_clockwise(outer_flat))), outline_tex)
		_outline_container.add_child(outer_line)
		for hole: LDPolygon in _holes:
			var hole_line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(hole_line)
			hole_line.width = terrain_data.outline_width
			hole_line.texture = outline_tex
			hole_line.default_color = Color.WHITE if outline_tex else Color.TRANSPARENT
			hole_line.points = TerrainPolygon.subdivide_for_line2d(
				TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(
					TerrainPolygon.ensure_clockwise(hole.to_flat()))), outline_tex)
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


func _array_to_vec2(a: Variant) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO
