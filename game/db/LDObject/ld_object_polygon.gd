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

@export var terrain_data: TerrainData

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D
@export var _outline: Line2D

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
		
		if not _topline_container:
			_topline_container = Node2D.new()
			_topline_container.name = "ToplineContainer"
			add_child(_topline_container)
			_topline_container.owner = self
		
		if not _topline_shadow_container:
			_topline_shadow_container = Node2D.new()
			_topline_shadow_container.name = "ToplineShadowContainer"
			_polygon.add_child(_topline_shadow_container)
			_topline_shadow_container.owner = self
		
		if not _outline:
			_outline = Line2D.new()
			_outline.name = "Outline"
			_outline.width = terrain_data.outline_width
			add_child(_outline)
			_outline.owner = self
			TerrainPolygon.setup_line2d(_outline)
		
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


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not terrain_data.update_visuals.is_connected(_update_visuals):
		terrain_data.update_visuals.connect(_update_visuals)
	if not terrain_data.redraw.is_connected(queue_redraw):
		terrain_data.redraw.connect(queue_redraw)


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
	if _outline:
		_outline.modulate = tint
	if _polygon:
		_polygon.modulate = tint
	queue_redraw()


func set_preview_valid(valid: bool) -> void:
	_preview_valid = valid
	queue_redraw()


func get_stamp_size() -> Vector2:
	if not _polygon or _polygon.polygon.is_empty():
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return _get_polygon_bounds().size


func apply_points(points: PackedVector2Array) -> void:
	if _polygon:
		_polygon.polygon = points
		_polygon.color = Color.TRANSPARENT
	if editor_polygon and _preview_valid:
		editor_polygon.polygon = points
	_update_visuals()
	queue_redraw()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	
	if _polygon:
		_polygon.texture = terrain_data.base_texture
		_polygon.color = Color.WHITE if terrain_data.base_texture else Color.TRANSPARENT
	
	if not _polygon or _polygon.polygon.size() < 3:
		if _topline_container:
			for child: Node in _topline_container.get_children():
				child.queue_free()
		if _topline_shadow_container:
			for child: Node in _topline_shadow_container.get_children():
				child.queue_free()
		if _outline:
			_outline.points = PackedVector2Array()
		return
	
	var points: PackedVector2Array = TerrainPolygon.ensure_clockwise(_polygon.polygon)
	var closed_points: PackedVector2Array = TerrainPolygon.get_closed_points(points)
	var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(points, terrain_data.topline_angle_threshold)
	
	if _topline_container:
		for child: Node in _topline_container.get_children():
			child.queue_free()
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width
			line.texture = terrain_data.topline_texture
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_texture)
			_topline_container.add_child(line)
	
	if _topline_shadow_container:
		for child: Node in _topline_shadow_container.get_children():
			child.queue_free()
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width + (terrain_data.topline_width / 3.0)
			line.texture = terrain_data.topline_shadow_texture
			line.default_color = Color(1.0, 1.0, 1.0, 0.6)
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_shadow_texture)
			_topline_shadow_container.add_child(line)
	
	if _outline:
		TerrainPolygon.setup_line2d(_outline)
		_outline.width = terrain_data.outline_width
		_outline.texture = terrain_data.outline_texture
		_outline.points = TerrainPolygon.subdivide_for_line2d(closed_points, terrain_data.outline_texture)


func _draw() -> void:
	if not _polygon or _polygon.polygon.is_empty():
		return
	
	var points: PackedVector2Array = _polygon.polygon
	
	if is_preview:
		var p_fill: Color = PREVIEW_VALID_FILL if _preview_valid else PREVIEW_INVALID_FILL
		var p_border: Color = PREVIEW_VALID_BORDER if _preview_valid else PREVIEW_INVALID_BORDER
		if points.size() >= 3:
			if _preview_valid:
				draw_colored_polygon(points, p_fill)
			else:
				draw_polyline(points, p_fill)
		if points.size() >= 2:
			draw_polyline(TerrainPolygon.get_closed_points(points) if points.size() >= 3 else points, p_border, PREVIEW_BORDER_WIDTH, true)
		return
	
	if not terrain_data.base_texture:
		draw_colored_polygon(points, FALLBACK_FILL)
		draw_polyline(TerrainPolygon.get_closed_points(points), FALLBACK_BORDER, terrain_data.border_width, true)
	
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
	
	draw_colored_polygon(points, s_fill)
	draw_polyline(TerrainPolygon.get_closed_points(points), s_outline, SELECTION_BORDER_WIDTH, true)
	
	if _selection_state == LDObject.SelectionState.SELECTED:
		queue_redraw()


func _get_polygon_bounds() -> Rect2:
	if not _polygon or _polygon.polygon.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(_polygon.polygon[0], Vector2.ZERO)
	for point: Vector2 in _polygon.polygon:
		bounds = bounds.expand(point)
	return bounds
