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


@export var polygon_data: PolygonData

@export_group("Internal")
@export var _polygon: Polygon2D
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


func _ready() -> void:
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
	
	_update_visuals()
	queue_redraw()


func apply_points_and_holes(points: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	_outer_points = points
	_holes.clear()
	for h: PackedVector2Array in holes:
		if h.size() >= 3:
			_holes.append(h)
	_rebuild_polygon()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	
	var textured: bool = polygon_data.textured if polygon_data else false
	var line_mode: PolygonData.LineMode = polygon_data.line_mode if polygon_data else PolygonData.LineMode.NONE
	
	if _polygon:
		if textured and polygon_data and polygon_data.base_texture:
			_polygon.texture = polygon_data.base_texture
			_polygon.color = Color.WHITE
		elif polygon_data:
			_polygon.texture = null
			_polygon.color = polygon_data.base_color
		else:
			_polygon.texture = null
			_polygon.color = Color.TRANSPARENT
	
	var poly_points: PackedVector2Array = _polygon.polygon if _polygon else PackedVector2Array()
	
	if poly_points.size() < 3:
		if _topline_container:
			for child: Node in _topline_container.get_children():
				child.queue_free()
		if _topline_shadow_container:
			for child: Node in _topline_shadow_container.get_children():
				child.queue_free()
		if _outline_container:
			for child: Node in _outline_container.get_children():
				child.queue_free()
		return
	
	if _topline_container:
		for child: Node in _topline_container.get_children():
			child.queue_free()
	if _topline_shadow_container:
		for child: Node in _topline_shadow_container.get_children():
			child.queue_free()
	if _outline_container:
		for child: Node in _outline_container.get_children():
			child.queue_free()
	
	if line_mode == PolygonData.LineMode.NONE:
		return
	
	var threshold: float = polygon_data.topline_angle_threshold if polygon_data else 0.55
	var topline_w: float = polygon_data.topline_width if polygon_data else 30.0
	var outline_w: float = polygon_data.outline_width if polygon_data else 7.0
	var topline_tex: Texture2D = polygon_data.topline_texture if (polygon_data and textured) else null
	var topline_shadow_tex: Texture2D = polygon_data.topline_shadow_texture if (polygon_data and textured) else null
	var outline_tex: Texture2D = polygon_data.outline_texture if (polygon_data and textured) else null
	var outline_color: Color = polygon_data.outline_color if polygon_data else Color.WHITE
	
	if line_mode == PolygonData.LineMode.TOPLINE:
		var outer_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(_outer_points)
		var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(outer_cw, threshold)
		
		for hole: PackedVector2Array in _holes:
			var hole_ccw: PackedVector2Array = TerrainPolygon.ensure_counter_clockwise(hole)
			top_segments.append_array(TerrainPolygon.get_topline_segments(hole_ccw, threshold))
		
		if _topline_container:
			for segment: PackedVector2Array in top_segments:
				var line: Line2D = Line2D.new()
				TerrainPolygon.setup_line2d(line)
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
				line.width = topline_w + (topline_w / 3.0)
				line.texture = topline_shadow_tex
				line.default_color = Color(1.0, 1.0, 1.0, 0.6)
				line.points = TerrainPolygon.subdivide_for_line2d(segment, topline_shadow_tex)
				_topline_shadow_container.add_child(line)
	
	if _outline_container:
		var outer_line: Line2D = Line2D.new()
		TerrainPolygon.setup_line2d(outer_line)
		outer_line.width = outline_w
		outer_line.texture = outline_tex
		outer_line.default_color = Color.WHITE if outline_tex else outline_color
		outer_line.points = TerrainPolygon.subdivide_for_line2d(
			TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(_outer_points))), outline_tex)
		_outline_container.add_child(outer_line)
		
		for hole: PackedVector2Array in _holes:
			var hole_cw: PackedVector2Array = TerrainPolygon.ensure_clockwise(hole)
			var hole_line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(hole_line)
			hole_line.width = outline_w
			hole_line.texture = outline_tex
			hole_line.default_color = Color.WHITE if outline_tex else outline_color
			hole_line.points = TerrainPolygon.subdivide_for_line2d(
				TerrainPolygon.reverse_points(TerrainPolygon.get_closed_points(hole_cw)), outline_tex)
			_outline_container.add_child(hole_line)


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
			draw_polyline(TerrainPolygon.get_closed_points(draw_points) if draw_points.size() >= 3 else draw_points, p_border, PREVIEW_BORDER_WIDTH, true)
		for hole: PackedVector2Array in _holes:
			if hole.size() >= 3:
				draw_colored_polygon(hole, Color(0.0, 0.0, 0.0, 0.4))
				draw_polyline(TerrainPolygon.get_closed_points(hole), p_border, PREVIEW_BORDER_WIDTH, true)
		return
	
	var has_texture: bool = polygon_data != null and polygon_data.textured and polygon_data.base_texture != null
	if not has_texture:
		var fill: Color = polygon_data.base_color if polygon_data else FALLBACK_FILL
		var border: Color = polygon_data.outline_color if polygon_data else FALLBACK_BORDER
		var border_w: float = polygon_data.border_width if polygon_data else 3.0
		draw_colored_polygon(draw_points, fill)
		draw_polyline(TerrainPolygon.get_closed_points(draw_points), border, border_w, true)
		for hole: PackedVector2Array in _holes:
			if hole.size() >= 3:
				draw_colored_polygon(hole, Color(0.0, 0.0, 0.0, 0.5))
				draw_polyline(TerrainPolygon.get_closed_points(hole), border, border_w, true)
	
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
	draw_polyline(TerrainPolygon.get_closed_points(draw_points), s_outline, SELECTION_BORDER_WIDTH, true)
	
	if _selection_state == LDObject.SelectionState.SELECTED:
		queue_redraw()


func _get_polygon_bounds() -> Rect2:
	if _outer_points.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(_outer_points[0], Vector2.ZERO)
	for point: Vector2 in _outer_points:
		bounds = bounds.expand(point)
	return bounds
