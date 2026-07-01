@tool
class_name LDObjectPolygon
extends LDObject


const PREVIEW_VALID_FILL: Color = Color(0.2, 0.5, 1.0, 0.25)
const PREVIEW_VALID_BORDER: Color = Color(0.0, 0.433, 1.0, 1.0)
const PREVIEW_INVALID_FILL: Color = Color(1.0, 0.2, 0.2, 0.25)
const PREVIEW_INVALID_BORDER: Color = Color(1.0, 0.0, 0.0, 0.8)
const FALLBACK_FILL: Color = Color(0.2, 0.5, 1.0, 0.25)
const FALLBACK_BORDER: Color = Color(0.4, 0.7, 1.0, 0.8)
const PREVIEW_BORDER_WIDTH: float = 1.0
const SELECTION_BORDER_WIDTH: float = 1.5
const DECORATION_EDGE_BUFFER: float = 32.0


@export var polygon_data: PolygonData

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _decoration_handler: DecorationHandler
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D
@export var _outline_container: Node2D

@export_group("Editor Props")
@export var editor_polygon: CollisionPolygon2D

@warning_ignore("unused_private_class_variable")
@export_tool_button("Create Polygon Props") var _create_polygon_props: Callable:
	get: return func() -> void:
		if not _polygon:
			_polygon = Polygon2D.new()
			_polygon.name = "Polygon"
			_polygon.color = Color.TRANSPARENT
			_polygon.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			add_child(_polygon)
			_polygon.owner = self
		
		if not _outline_container:
			_outline_container = Node2D.new()
			_outline_container.name = "OutlineContainer"
			add_child(_outline_container)
			_outline_container.owner = self
		
		if not _topline_shadow_container:
			_topline_shadow_container = Node2D.new()
			_topline_shadow_container.name = "ToplineShadowContainer"
			_polygon.add_child(_topline_shadow_container)
			_topline_shadow_container.owner = self
		
		if not _topline_container:
			_topline_container = Node2D.new()
			_topline_container.name = "ToplineContainer"
			add_child(_topline_container)
			_topline_container.owner = self
		
		if not editor_shape_area:
			editor_shape_area = Area2D.new()
			editor_shape_area.name = "EditorShapeArea"
			add_child(editor_shape_area)
			editor_shape_area.owner = self
			
			var col_poly: CollisionPolygon2D = CollisionPolygon2D.new()
			col_poly.name = "EditorPolygon"
			editor_shape_area.add_child(col_poly)
			col_poly.owner = self
			editor_polygon = col_poly
		
		if not origin_marker:
			origin_marker = Marker2D.new()
			origin_marker.name = "Origin"
			add_child(origin_marker)
			origin_marker.owner = self


var _selection_state: LDObject.SelectionState = LDObject.SelectionState.HIDDEN
var _preview_valid: bool = true
var _outer_points: PackedVector2Array = PackedVector2Array()
var _holes: Array[PackedVector2Array] = []
var _seam_indices: PackedInt32Array = PackedInt32Array()
var _decoration_placements: Array[Dictionary] = []
var _topline_forced: Dictionary = {}


static func from_game_object(game_object: GameObject = null) -> LDObject:
	if not game_object:
		return null
	
	var instance: LDObjectPolygon = preload("res://game/object_templates/polygon/ld_object_polygon.tscn").instantiate()
	instance.polygon_data = game_object.polygon_data
	
	return instance


func _ready() -> void:
	if get_property(&"rng_seed") == 0:
		set_property(&"rng_seed", randi())
	
	if Engine.is_editor_hint():
		return
	if polygon_data and not polygon_data.update_visuals.is_connected(_update_visuals):
		polygon_data.update_visuals.connect(_update_visuals)
	if polygon_data and not polygon_data.redraw.is_connected(queue_redraw):
		polygon_data.redraw.connect(queue_redraw)


func _on_preview() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.6)


func _on_place() -> void:
	modulate = Color.WHITE


func set_selection_state(state: LDObject.SelectionState) -> void:
	_selection_state = state
	var tint: Color = Color.WHITE
	match state:
		LDObject.SelectionState.HOVERED:
			tint = Color(1.0, 1.0, 1.0, 0.7)
		LDObject.SelectionState.SELECTED:
			tint = Color(1.2, 1.2, 1.2, 1.0)
	if _topline_container:
		_topline_container.modulate = tint
	if _topline_shadow_container:
		_topline_shadow_container.modulate = tint
	if _outline_container:
		_outline_container.modulate = tint
	if _polygon:
		_polygon.modulate = tint
	queue_redraw()


func set_preview_valid(valid: bool) -> void:
	_preview_valid = valid
	queue_redraw()


func get_stamp_size() -> Vector2:
	if _outer_points.is_empty():
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return _get_polygon_bounds().size


func apply_points(points: PackedVector2Array) -> void:
	_outer_points = points
	_rebuild_polygon()


func add_hole(hole: PackedVector2Array) -> void:
	_holes.append(hole)
	_rebuild_polygon()


func remove_hole(index: int) -> void:
	if index < _holes.size():
		_holes.remove_at(index)
		_rebuild_polygon()


func clear_holes() -> void:
	_holes.clear()
	_rebuild_polygon()


func set_outer_points_only(points: PackedVector2Array) -> void:
	_outer_points = points
	_rebuild_polygon()


func set_hole(index: int, points: PackedVector2Array) -> void:
	if index < _holes.size():
		_holes[index] = points
		_rebuild_polygon()


func get_outer_points() -> PackedVector2Array:
	return _outer_points


func get_holes() -> Array[PackedVector2Array]:
	return _holes


func get_hole_count() -> int:
	return _holes.size()


func get_hole(index: int) -> PackedVector2Array:
	if index < _holes.size():
		return _holes[index]
	return PackedVector2Array()


func _rebuild_polygon() -> void:
	_decoration_placements.clear()
	
	if _outer_points.is_empty():
		if _polygon:
			_polygon.polygon = PackedVector2Array()
			_polygon.color = Color.TRANSPARENT
		if editor_polygon:
			editor_polygon.polygon = PackedVector2Array()
		_seam_indices = PackedInt32Array()
		_update_visuals()
		queue_redraw()
		return
	
	var seam_polygon: PackedVector2Array = TerrainPolygon.clean_polygon(_outer_points)
	_seam_indices = PackedInt32Array()
	
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
		for idx: int in (seam_result["seam_indices"] as PackedInt32Array):
			_seam_indices.append(idx)
	
	if _polygon:
		_polygon.polygon = seam_polygon
		_polygon.color = Color.TRANSPARENT
	if editor_polygon and _preview_valid:
		editor_polygon.polygon = seam_polygon
	
	_rebuild_decorations()
	_update_visuals()
	queue_redraw()


func apply_points_and_holes(points: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	_outer_points = points
	_holes.clear()
	for h: PackedVector2Array in holes:
		if h.size() >= 3:
			_holes.append(h)
	_rebuild_polygon()


func _rebuild_decorations() -> void:
	if not _decoration_handler:
		return
	var seed_value: Variant = get_property(&"rng_seed")
	var rng_seed: int = int(seed_value) if seed_value != null else 0
	var enabled_value: Variant = get_property(&"decorations_enabled")
	var enabled: bool = bool(enabled_value) if enabled_value != null else true
	var deco: PolygonDecorationStyle = _resolved_decoration()
	var weightmap: Dictionary[Texture2D, float] = {}
	var density: float = -1.0
	if deco:
		weightmap = deco.weightmap
		density = deco.density
	_decoration_handler.rebuild(_outer_points, _holes, polygon_data, rng_seed, weightmap, density, enabled)


func _resolved_base() -> PolygonBaseStyle:
	var v: Variant = get_property(&"base_style")
	var style_name: String = str(v) if v != null else ""
	if style_name.is_empty():
		return null
	return PolygonStyleDB.get_base_style(style_name)


func _resolved_topline() -> PolygonToplineStyle:
	var v: Variant = get_property(&"topline_style")
	var style_name: String = str(v) if v != null else ""
	if style_name.is_empty():
		return null
	return PolygonStyleDB.get_topline_style(style_name)


func _resolved_decoration() -> PolygonDecorationStyle:
	var v: Variant = get_property(&"decoration_set")
	var style_name: String = str(v) if v != null else ""
	if style_name.is_empty():
		return null
	return PolygonStyleDB.get_decoration_style(style_name)


func get_property_options(key: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	match key:
		&"base_style":
			result.append("Default")
			for style: PolygonBaseStyle in PolygonStyleDB.get_base_styles():
				result.append(style.style_name)
		&"topline_style":
			result.append("Default")
			for style: PolygonToplineStyle in PolygonStyleDB.get_topline_styles():
				result.append(style.style_name)
		&"decoration_set":
			result.append("Default")
			for style: PolygonDecorationStyle in PolygonStyleDB.get_decoration_styles():
				result.append(style.style_name)
	return result


func _on_property_changed(key: StringName, _value: Variant) -> void:
	if key in [&"base_style", &"topline_style", &"decoration_set", &"decorations_enabled"]:
		_rebuild_polygon()


func get_topline_threshold() -> float:
	var t: PolygonToplineStyle = _resolved_topline()
	if t:
		return t.topline_angle_threshold
	return polygon_data.topline_angle_threshold if polygon_data else 0.55


func get_topline_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var outer: PackedVector2Array = get_outer_points()
	if outer.size() < 2:
		return result
	var cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(outer)
	var threshold: float = get_topline_threshold()
	var n: int = cw.size()
	for i: int in n:
		var a: Vector2 = cw[i]
		var b: Vector2 = cw[(i + 1) % n]
		var key: String = TerrainPolygon.edge_midpoint_key(a, b)
		var on: bool = bool(_topline_forced[key]) if _topline_forced.has(key) else TerrainPolygon.is_top_edge(a, b, threshold, false)
		result.append({"a": a, "b": b, "mid": (a + b) * 0.5, "key": key, "on": on})
	return result


func toggle_topline_edge(key: String, on: bool) -> void:
	_topline_forced[key] = on
	_rebuild_polygon()


func clear_topline_edge(key: String) -> void:
	_topline_forced.erase(key)
	_rebuild_polygon()


func get_topline_forced() -> Dictionary:
	return _topline_forced


func set_topline_forced_all(data: Dictionary) -> void:
	_topline_forced = data.duplicate()
	_rebuild_polygon()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	
	var textured: bool = polygon_data.textured if polygon_data else false
	var line_mode: PolygonData.LineMode = polygon_data.line_mode if polygon_data else PolygonData.LineMode.NONE
	var base_style: PolygonBaseStyle = _resolved_base()
	var topline_style: PolygonToplineStyle = _resolved_topline()
	var base_tex: Texture2D = base_style.base_texture if base_style else (polygon_data.base_texture if polygon_data else null)
	var outline_tex: Texture2D = base_style.outline_texture if base_style else (polygon_data.outline_texture if polygon_data else null)
	var outline_w: float = base_style.outline_width if base_style else (polygon_data.outline_width if polygon_data else 7.0)
	var topline_tex: Texture2D = topline_style.topline_texture if topline_style else (polygon_data.topline_texture if polygon_data else null)
	var topline_shadow: Texture2D = topline_style.topline_shadow_texture if topline_style else (polygon_data.topline_shadow_texture if polygon_data else null)
	var topline_left: Texture2D = topline_style.topline_left_end if topline_style else (polygon_data.topline_left_end if polygon_data else null)
	var topline_right: Texture2D = topline_style.topline_right_end if topline_style else (polygon_data.topline_right_end if polygon_data else null)
	var topline_w: float = topline_style.topline_width if topline_style else (polygon_data.topline_width if polygon_data else 30.0)
	var topline_threshold: float = topline_style.topline_angle_threshold if topline_style else (polygon_data.topline_angle_threshold if polygon_data else 0.55)

	if _polygon:
		if textured and base_tex:
			_polygon.texture = base_tex
			_polygon.color = Color.WHITE
		elif polygon_data:
			_polygon.texture = null
			_polygon.color = polygon_data.base_color
		else:
			_polygon.texture = null
			_polygon.color = Color.TRANSPARENT
	
	_clear_visuals()
	
	var poly_points: PackedVector2Array = _polygon.polygon if _polygon else PackedVector2Array()
	if poly_points.size() < 3 or line_mode == PolygonData.LineMode.NONE:
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


func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float, antialiased: bool) -> void:
	var count: int = points.size()
	for i: int in count:
		draw_line(points[i], points[(i + 1) % count], color, width, antialiased)


func _draw() -> void:
	var draw_points: PackedVector2Array = _outer_points if not _outer_points.is_empty() else (_polygon.polygon if _polygon else PackedVector2Array())
	
	if draw_points.is_empty():
		return
	
	if is_preview:
		var p_fill: Color = PREVIEW_VALID_FILL if _preview_valid else PREVIEW_INVALID_FILL
		var p_border: Color = PREVIEW_VALID_BORDER if _preview_valid else PREVIEW_INVALID_BORDER
		if draw_points.size() >= 3:
			if _preview_valid:
				draw_colored_polygon(draw_points, p_fill)
			else:
				draw_polyline(draw_points, p_fill)
		if draw_points.size() >= 2:
			_draw_closed_polyline(draw_points, p_border, PREVIEW_BORDER_WIDTH, true)
		for hole: PackedVector2Array in _holes:
			if hole.size() >= 3:
				draw_colored_polygon(hole, Color(0.0, 0.0, 0.0, 0.4))
				_draw_closed_polyline(hole, p_border, PREVIEW_BORDER_WIDTH, true)
		return
	
	if _selection_state == LDObject.SelectionState.HIDDEN:
		return
	
	var s_outline: Color
	var s_fill: Color
	
	match _selection_state:
		LDObject.SelectionState.HOVERED:
			s_outline = Color(1.0, 1.0, 1.0, 0.6)
			s_fill = Color(1.0, 1.0, 1.0, 0.1)
		LDObject.SelectionState.SELECTED:
			var pulse: float = sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5
			var alpha: float = lerpf(0.3, 1.0, pulse)
			s_outline = Color(1.0, 1.0, 1.0, alpha)
			s_fill = Color(1.0, 1.0, 1.0, alpha * 0.15)
	
	draw_colored_polygon(draw_points, s_fill)
	_draw_closed_polyline(draw_points, s_outline, SELECTION_BORDER_WIDTH, true)
	
	if _selection_state == LDObject.SelectionState.SELECTED:
		queue_redraw()


func _get_polygon_bounds() -> Rect2:
	if _outer_points.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(_outer_points[0], Vector2.ZERO)
	for point: Vector2 in _outer_points:
		bounds = bounds.expand(point)
	return bounds
