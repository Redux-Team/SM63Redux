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
var base_style: String = ""
var topline_style: String = ""
var decoration_set: String = ""
var decorations_enabled: bool = true
var _topline_forced: Dictionary = {}


static func from_game_object(game_object: GameObject = null) -> LevelObjectTerrain:
	if not game_object:
		return null
	
	var instance: LevelObjectTerrain = preload("res://game/object_templates/polygon/level_object_terrain.tscn").instantiate()
	instance.polygon_data = game_object.polygon_data
	
	return instance


func _on_init() -> void:
	var raw_points: Variant = data.get("polygon_points")
	_outer_points = Packer.array_to_packed_vec2(raw_points)
	
	if not polygon_data and not source_object_id.is_empty():
		var game_object: GameObject = GameDB.get_db().find_game_object(source_object_id)
		if game_object:
			polygon_data = game_object.polygon_data
	
	if data.has("polygon_holes"):
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(Packer.array_to_vec2(p))
			if hole_points.size() >= 3:
				_holes.append(hole_points)
	
	if data.has("topline_forced") and data.get("topline_forced") is Dictionary:
		_topline_forced = data.get("topline_forced")
	if not Engine.is_editor_hint() and polygon_data:
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
	if not _decoration_handler:
		return
	var deco: PolygonDecorationStyle = _resolved_decoration()
	var weightmap: Dictionary[Texture2D, float] = {}
	var density: float = -1.0
	if deco:
		weightmap = deco.weightmap
		density = deco.density
	_decoration_handler.rebuild(_outer_points, _holes, polygon_data, rng_seed, weightmap, density, decorations_enabled)


func _resolved_base() -> PolygonBaseStyle:
	if base_style.is_empty():
		return null
	return PolygonStyleDB.get_base_style(base_style)


func _resolved_topline() -> PolygonToplineStyle:
	if topline_style.is_empty():
		return null
	return PolygonStyleDB.get_topline_style(topline_style)


func _resolved_decoration() -> PolygonDecorationStyle:
	if decoration_set.is_empty():
		return null
	return PolygonStyleDB.get_decoration_style(decoration_set)


func _update_visuals() -> void:
	if not is_node_ready() or not polygon_data:
		return
	
	var textured: bool = polygon_data.textured
	var line_mode: PolygonData.LineMode = polygon_data.line_mode
	var base_style_res: PolygonBaseStyle = _resolved_base()
	var topline_style_res: PolygonToplineStyle = _resolved_topline()
	var base_tex: Texture2D = base_style_res.base_texture if base_style_res else polygon_data.base_texture
	var outline_tex: Texture2D = base_style_res.outline_texture if base_style_res else polygon_data.outline_texture
	var outline_w: float = base_style_res.outline_width if base_style_res else polygon_data.outline_width
	var topline_tex: Texture2D = topline_style_res.topline_texture if topline_style_res else polygon_data.topline_texture
	var topline_shadow: Texture2D = topline_style_res.topline_shadow_texture if topline_style_res else polygon_data.topline_shadow_texture
	var topline_left: Texture2D = topline_style_res.topline_left_end if topline_style_res else polygon_data.topline_left_end
	var topline_right: Texture2D = topline_style_res.topline_right_end if topline_style_res else polygon_data.topline_right_end
	var topline_w: float = topline_style_res.topline_width if topline_style_res else polygon_data.topline_width
	var topline_threshold: float = topline_style_res.topline_angle_threshold if topline_style_res else polygon_data.topline_angle_threshold
	
	if _polygon:
		if textured and base_tex:
			_polygon.texture = base_tex
			_polygon.color = Color.WHITE
		else:
			_polygon.texture = null
			_polygon.color = polygon_data.base_color
	
	_clear_visuals()
	
	if _outer_points.size() < 3 or line_mode == PolygonData.LineMode.NONE:
		return
	
	var outline_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
		outline_w,
		outline_tex if textured else null,
		polygon_data.outline_color,
		textured,
		polygon_data.outline_scroll_speed,
		polygon_data.outline_ripple_amplitude,
		polygon_data.outline_ripple_frequency,
		polygon_data.outline_ripple_speed
	)
	
	if line_mode == PolygonData.LineMode.TOPLINE:
		var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
		var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, topline_threshold, PackedInt32Array(), false, _topline_forced)
		
		for hole: PackedVector2Array in _holes:
			top_segments.append_array(TerrainPolygon.get_topline_segments(
				TerrainPolygon.ensure_counter_clockwise(hole), topline_threshold, PackedInt32Array(), false, _topline_forced
			))
		
		#top_segments = TerrainPolygon.merge_adjacent_segments(top_segments)
		
		var line_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
			topline_w,
			topline_tex if textured else null,
			polygon_data.outline_color,
			textured,
			polygon_data.topline_scroll_speed,
			polygon_data.topline_ripple_amplitude,
			polygon_data.topline_ripple_frequency,
			polygon_data.topline_ripple_speed
		)
		var cap_style: TerrainPolygon.CapStyle = TerrainPolygon.CapStyle.new(
			topline_left if textured else null,
			topline_right if textured else null,
			polygon_data.topline_cap_inset
		)
		
		if _topline_container:
			for segment: PackedVector2Array in top_segments:
				TerrainPolygon.add_topline_segment(_topline_container, segment, line_style, cap_style)
		
		if _topline_shadow_container and textured and topline_shadow:
			for segment: PackedVector2Array in top_segments:
				TerrainPolygon.add_topline_shadow(
					_topline_shadow_container, segment,
					topline_shadow,
					topline_w * 1.33
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
