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
@export var _static_body_2d: StaticBody2D
@export var _decoration_handler: DecorationHandler


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
	if _decoration_handler:
		_decoration_handler.rebuild(_outer_points, _holes, polygon_data, rng_seed)


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
		textured,
		polygon_data.outline_scroll_speed,
		polygon_data.outline_ripple_amplitude,
		polygon_data.outline_ripple_frequency,
		polygon_data.outline_ripple_speed
	)
	
	if line_mode == PolygonData.LineMode.TOPLINE:
		var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
		var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, polygon_data.topline_angle_threshold)
		
		for hole: PackedVector2Array in _holes:
			top_segments.append_array(TerrainPolygon.get_topline_segments(
				TerrainPolygon.ensure_counter_clockwise(hole), polygon_data.topline_angle_threshold
			))
		
		#top_segments = TerrainPolygon.merge_adjacent_segments(top_segments)
		
		var line_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
			polygon_data.topline_width,
			polygon_data.topline_texture if textured else null,
			polygon_data.outline_color,
			textured,
			polygon_data.topline_scroll_speed,
			polygon_data.topline_ripple_amplitude,
			polygon_data.topline_ripple_frequency,
			polygon_data.topline_ripple_speed
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
